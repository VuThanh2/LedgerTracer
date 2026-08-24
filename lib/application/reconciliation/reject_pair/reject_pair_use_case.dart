import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/errors/reconciliation_errors.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../shared/domain_failures.dart';

/// Từ chối một cặp ghép sai, hoặc gỡ một phán quyết bấm nhầm (UC-09 bước 3, 5).
///
/// Từ chối là **hành động duy nhất** để loại một cặp — dùng chung cho cặp gợi ý
/// lẫn cặp đã xác nhận — nên nó vừa xoá cặp vừa ghi một [RejectedMatch]. Phán
/// quyết đó tồn tại **độc lập** với cặp vừa bị xoá và sống sót qua các lần chạy
/// lại đối soát, nếu không mỗi lần chạy lại sẽ đề xuất y nguyên cặp vừa bị từ chối
/// (Rule – Suggested Is Not Confirmed). Vì hai giao dịch có thể bị từ chối với
/// nhiều đối tác khác nhau, phán quyết không thể là một trạng thái của cặp.
final class RejectPairUseCase {
  RejectPairUseCase({
    required this._reconciliation,
    required this._unitOfWork,
    required this._now,
  });

  final ReconciliationRepository _reconciliation;
  final UnitOfWork _unitOfWork;
  final DateTime Function() _now;

  /// Từ chối cặp: ghi phán quyết rồi xoá cặp, trong một [UnitOfWork]. Hai giao
  /// dịch trở về trạng thái chưa ghép.
  Future<Result<RejectedMatch>> execute(int pairId) =>
      Result.guardAsync(() async {
        final pair = await _reconciliation.findPairById(pairId);
        if (pair == null) throw PairNotFoundError(pairId);
        return _unitOfWork.transaction(() async {
          final rejection = await _reconciliation.addRejection(
            RejectedMatch.forPair(pair, _now()),
          );
          await _reconciliation.deletePairById(pairId);
          return rejection;
        });
      }, onError: failureFromError);

  /// Gỡ một phán quyết từ chối bấm nhầm; cặp đó trở lại làm ứng viên ở lần chạy
  /// đối soát kế tiếp (UC-09 bước 5).
  Future<Result<void>> undo(int rejectedMatchId) => Result.guardAsync(
    () => _reconciliation.deleteRejectionById(rejectedMatchId),
    onError: failureFromError,
  );
}
