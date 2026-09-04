import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/import_file_record.dart';
import '../../../domain/errors/import_errors.dart';
import '../../../domain/repositories/import_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/domain_failures.dart';
import 'revert_import_dto.dart';

/// Xem lịch sử nhập và hoàn tác một lượt hoặc một file (UC-03).
///
/// Hoàn tác được định nghĩa là "xoá đúng những gì bản ghi đó đã thêm", và điều
/// làm nó chính xác được là liên kết nguồn gốc: mỗi giao dịch trỏ về đúng một
/// [ImportFileRecord] (Rule – Provenance Is What Makes Undo Possible). Không có
/// liên kết đó thì phải suy đoán bằng thời gian hay fingerprint, và cả hai đều
/// xoá nhầm khi hai lượt cùng tài khoản có phần thời gian giao nhau.
///
/// Bản ghi đã hoàn tác **không** biến mất: nó ở lại lịch sử với dấu đã hoàn tác,
/// và dòng lỗi của nó vẫn xuất lại được — `revertedAt` không phải tombstone
/// (Rule – Deletion Is Physical, Not a Tombstone). Lượt nhập chỉ biến mất khi
/// không còn bản ghi con nào, việc đó thuộc luồng xoá tài khoản (UC-01).
final class RevertImportUseCase {
  RevertImportUseCase({
    required this._imports,
    required this._transactions,
    required this._reconciliation,
    required this._unitOfWork,
    required this._now,
  });

  final ImportRepository _imports;
  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final UnitOfWork _unitOfWork;
  final DateTime Function() _now;

  Future<Result<ImportHistoryPage>> history({
    required int limit,
    required int offset,
  }) => Result.guardAsync(() async {
    final sessions = await _imports.findSessions(limit: limit, offset: offset);
    final total = await _imports.countSessions();
    return ImportHistoryPage(
      sessions: sessions,
      totalCount: total,
      offset: offset,
    );
  }, onError: failureFromError);

  /// Số liệu cho hộp thoại xác nhận hoàn tác một file (UC-03 bước 4).
  Future<Result<RevertImpact>> previewFileRevert(int recordId) =>
      Result.guardAsync(() async {
        final record = await _requireRecord(recordId);
        return _impactOf(record);
      }, onError: failureFromError);

  /// Số liệu gộp cho hộp thoại xác nhận hoàn tác cả một lượt nhiều file.
  Future<Result<RevertImpact>> previewSessionRevert(int sessionId) =>
      Result.guardAsync(() async {
        final session = await _imports.findSessionById(sessionId);
        if (session == null) throw ImportSessionNotFoundError(sessionId);
        var impact = RevertImpact.none;
        for (final record in session.fileRecords) {
          if (record.canRevert) {
            impact = impact.mergedWith(await _impactOf(record));
          }
        }
        return impact;
      }, onError: failureFromError);

  /// Hoàn tác một bản ghi file: xoá đúng những gì nó đã ghi, huỷ các cặp và phán
  /// quyết từ chối treo trên các dòng ấy, rồi đánh dấu đã hoàn tác.
  Future<Result<RevertImpact>> revertFile(int recordId) =>
      Result.guardAsync(() async {
        final record = await _requireRecord(recordId);
        return _unitOfWork.transaction(() => _revert(record));
      }, onError: failureFromError);

  /// Hoàn tác cả một lượt: lần lượt hoàn tác từng bản ghi con còn hoàn tác được,
  /// theo đúng quy tắc của [revertFile] — không phải một cơ chế xoá riêng
  /// (UC-03).
  Future<Result<RevertImpact>> revertSession(int sessionId) =>
      Result.guardAsync(() async {
        final session = await _imports.findSessionById(sessionId);
        if (session == null) throw ImportSessionNotFoundError(sessionId);
        return _unitOfWork.transaction(() async {
          var impact = RevertImpact.none;
          for (final record in session.fileRecords) {
            if (record.canRevert) {
              impact = impact.mergedWith(await _revert(record));
            }
          }
          return impact;
        });
      }, onError: failureFromError);

  Future<RevertImpact> _revert(ImportFileRecord record) async {
    // Dựng bản ghi đã hoàn tác **trước tiên**: `revert` là nơi giữ điều kiện
    // "chưa hoàn tác và đã từng ghi được dòng nào", nên gọi nó đầu tiên biến một
    // yêu cầu không hợp lệ thành lỗi trước khi có bất cứ thứ gì bị xoá — thay vì
    // trông chờ transaction quay lui sau khi đã xoá xong.
    final reverted = record.revert(_now());
    final recordId = record.recordId!;
    final impact = await _impactOf(record);
    // Bất biến về cặp đối soát: xoá một giao dịch thì huỷ cặp dính tới nó và xoá
    // luôn phán quyết từ chối liên quan (UC-09, được UC-03 tham chiếu).
    await _reconciliation.deletePairsByImportFileRecordId(recordId);
    await _reconciliation.deleteRejectionsByImportFileRecordId(recordId);
    await _transactions.deleteByImportFileRecordId(recordId);
    // Bản ghi ở lại lịch sử với dấu đã hoàn tác thay vì bị xoá: `revertedAt`
    // không phải tombstone, và dòng lỗi của nó vẫn phải xuất lại được (UC-11).
    await _imports.updateFileRecord(reverted);
    return impact;
  }

  /// Đếm bằng truy vấn có phạm vi, không nạp danh sách định danh: một bản ghi
  /// nhập có thể mang hàng trăm nghìn dòng, và một danh sách dài như thế vừa
  /// tốn bộ nhớ luồng chính vừa không lọt qua trần tham số của SQLite.
  Future<RevertImpact> _impactOf(ImportFileRecord record) async {
    final recordId = record.recordId!;
    final transactionCount = await _transactions.countByImportFileRecordId(
      recordId,
    );
    final cancelledPairs = await _reconciliation
        .countPairsByImportFileRecordId(recordId);
    final manualEdits = await _transactions
        .countManuallyEditedByImportFileRecordId(recordId);
    return RevertImpact(
      deletedTransactionCount: transactionCount,
      cancelledPairCount: cancelledPairs,
      hasManualEdits: manualEdits > 0,
    );
  }

  Future<ImportFileRecord> _requireRecord(int recordId) async {
    final record = await _imports.findFileRecordById(recordId);
    if (record == null) throw ImportFileRecordNotFoundError(recordId);
    return record;
  }
}
