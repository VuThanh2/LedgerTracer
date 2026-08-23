import '../errors/import_errors.dart';
import '../value_objects/import_file_status.dart';
import '../value_objects/statement_format.dart';

/// Kết quả nhập của **một file** — đơn vị nhỏ nhất có thể hoàn tác (UC-03).
///
/// Một lượt nhập có thể gán mỗi file một tài khoản khác nhau, nên hoàn tác hay
/// xoá dây chuyền đều làm việc trên bản ghi này chứ không trên cả lượt (UC-01).
final class ImportFileRecord {
  const ImportFileRecord({
    this.recordId,
    required this.sessionId,
    required this.accountId,
    required this.fileName,
    required this.detectedFormat,
    required this.orderIndex,
    required this.status,
    this.importedCount = 0,
    this.duplicateSkippedCount = 0,
    this.errorRowCount = 0,
    this.revertedAt,
  }) : assert(orderIndex >= 0, 'orderIndex mirrors the pick order'),
       assert(importedCount >= 0 && duplicateSkippedCount >= 0, 'counters'),
       assert(errorRowCount >= 0, 'counters');

  /// Mở bản ghi **trước khi** xử lý file, để các giao dịch ghi ra có nguồn gốc
  /// mà trỏ về.
  ///
  /// Cố ý bắt đầu ở [ImportFileStatus.cancelled]: nếu ứng dụng chết giữa chừng,
  /// lịch sử phản ánh trung thực một lượt nhập dở dang thay vì báo là đã hoàn
  /// tất. [finished] sẽ chốt lại trạng thái thật sau đó.
  factory ImportFileRecord.started({
    required int sessionId,
    required int accountId,
    required String fileName,
    required StatementFormat detectedFormat,
    required int orderIndex,
  }) => ImportFileRecord(
    sessionId: sessionId,
    accountId: accountId,
    fileName: fileName,
    detectedFormat: detectedFormat,
    orderIndex: orderIndex,
    status: ImportFileStatus.cancelled,
  );

  final int? recordId;

  final int sessionId;

  /// Tài khoản đích được gán cho riêng file này (UC-02 bước 3).
  final int accountId;

  final String fileName;

  final StatementFormat detectedFormat;

  /// Vị trí trong thứ tự người dùng chọn, cũng chính là thứ tự ghi — hai lần
  /// nhập cùng một tập file phải cho cùng một kết quả
  /// (Rule – Write Order Is Deterministic).
  final int orderIndex;

  final ImportFileStatus status;

  final int importedCount;

  /// Số dòng bị bỏ vì đã có, đếm theo số lượng chứ không kiểm tồn tại (UC-02).
  final int duplicateSkippedCount;

  final int errorRowCount;

  /// Dấu đã hoàn tác. Đây **không** phải tombstone: bản ghi vẫn hiện trong lịch
  /// sử và dòng lỗi của nó vẫn xuất lại được
  /// (Rule – Deletion Is Physical, Not a Tombstone).
  final DateTime? revertedAt;

  bool get isPersisted => recordId != null;

  bool get isReverted => revertedAt != null;

  /// File bị bỏ qua hoặc không ghi được dòng nào thì không có gì để hoàn tác.
  bool get canRevert => !isReverted && importedCount > 0;

  ImportFileRecord withIdentity(int id) => _copyWith(recordId: id);

  /// Chốt bản ghi bằng các bộ đếm mà giai đoạn ghi tạo ra.
  ///
  /// Trạng thái được suy ra từ kết quả chứ không do người gọi chọn, để mọi
  /// đường nhập phân loại một file theo cùng một cách.
  ImportFileRecord finished({
    required int importedCount,
    required int duplicateSkippedCount,
    required int errorRowCount,
    bool wasCancelled = false,
  }) => _copyWith(
    importedCount: importedCount,
    duplicateSkippedCount: duplicateSkippedCount,
    errorRowCount: errorRowCount,
    status: wasCancelled
        ? ImportFileStatus.cancelled
        : errorRowCount > 0
        ? ImportFileStatus.partiallyFailed
        : ImportFileStatus.completed,
  );

  /// Người dùng trả lời "bỏ qua file này" ở cảnh báo số tài khoản (UC-02 bước
  /// 4) — ghi nhận như một quyết định, không phải lỗi đọc file.
  ImportFileRecord skipped() => _copyWith(status: ImportFileStatus.skipped);

  /// Ném [ImportAlreadyRevertedError] nếu đã hoàn tác rồi, và
  /// [NothingToRevertError] nếu nó chưa từng ghi gì (UC-03).
  ImportFileRecord revert(DateTime at) {
    assert(isPersisted, 'Only a persisted record can be reverted.');
    final id = recordId!;
    if (isReverted) throw ImportAlreadyRevertedError(id);
    if (importedCount == 0) throw NothingToRevertError(id);
    return _copyWith(revertedAt: at);
  }

  ImportFileRecord _copyWith({
    int? recordId,
    ImportFileStatus? status,
    int? importedCount,
    int? duplicateSkippedCount,
    int? errorRowCount,
    DateTime? revertedAt,
  }) => ImportFileRecord(
    recordId: recordId ?? this.recordId,
    sessionId: sessionId,
    accountId: accountId,
    fileName: fileName,
    detectedFormat: detectedFormat,
    orderIndex: orderIndex,
    status: status ?? this.status,
    importedCount: importedCount ?? this.importedCount,
    duplicateSkippedCount: duplicateSkippedCount ?? this.duplicateSkippedCount,
    errorRowCount: errorRowCount ?? this.errorRowCount,
    revertedAt: revertedAt ?? this.revertedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportFileRecord &&
          other.recordId != null &&
          other.recordId == recordId);

  @override
  int get hashCode => recordId?.hashCode ?? identityHashCode(this);

  @override
  String toString() =>
      'ImportFileRecord($recordId, $fileName, $status, +$importedCount)';
}
