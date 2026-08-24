import '../../../core/result/result.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/errors/reconciliation_errors.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../shared/domain_failures.dart';

/// Xác nhận một cặp ghép đúng (UC-09 bước 3).
///
/// Chỉ cặp **đã xác nhận** mới có hiệu lực nghiệp vụ: chỉ nó bị loại khỏi dòng
/// tiền với bên ngoài (UC-10) và chỉ nó sống sót qua một lần chạy lại đối soát
/// (Rule – Suggested Is Not Confirmed). Xác nhận là chuyển trạng thái một chiều —
/// không có thao tác "bỏ xác nhận", đường lùi là **từ chối** (một bản ghi khác
/// mang ý nghĩa khác).
final class ConfirmPairUseCase {
  ConfirmPairUseCase({
    required this._reconciliation,
    required this._now,
  });

  final ReconciliationRepository _reconciliation;
  final DateTime Function() _now;

  Future<Result<ReconciliationPair>> execute(int pairId) =>
      Result.guardAsync(() async {
        final pair = await _reconciliation.findPairById(pairId);
        if (pair == null) throw PairNotFoundError(pairId);
        // Ném [PairAlreadyConfirmedError] nếu cặp đã được xác nhận.
        final confirmed = pair.confirm(_now());
        await _reconciliation.updatePair(confirmed);
        return confirmed;
      }, onError: failureFromError);
}
