import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/domain_failures.dart';

/// Xoá một giao dịch đơn lẻ (UC-05).
///
/// Xoá là **vật lý**, không tombstone: không có bản sao nào ở nơi khác cần biết
/// về thao tác xoá (Rule – Deletion Is Physical, Not a Tombstone). Việc xoá kéo
/// theo bất biến về cặp đối soát (UC-09): huỷ cặp mà giao dịch đang thuộc về, và
/// xoá luôn mọi phán quyết từ chối dính tới nó — phán quyết chỉ có nghĩa khi cả
/// hai vế còn tồn tại. Cả ba bước nằm trong một [UnitOfWork].
final class DeleteTransactionUseCase {
  DeleteTransactionUseCase({
    required this._transactions,
    required this._reconciliation,
    required this._unitOfWork,
  });

  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final UnitOfWork _unitOfWork;

  /// Giao dịch có đang thuộc một cặp không, để hộp thoại xác nhận báo trước rằng
  /// xoá sẽ huỷ cặp đó (UC-05).
  Future<Result<bool>> isInPair(int transactionId) => Result.guardAsync(() async {
    final pair = await _reconciliation.findPairInvolving(transactionId);
    return pair != null;
  }, onError: failureFromError);

  /// Xoá giao dịch. Trả về `true` nếu một cặp đối soát đã bị huỷ theo, để giao
  /// diện thông báo.
  Future<Result<bool>> execute(int transactionId) =>
      Result.guardAsync(() => _unitOfWork.transaction(() async {
        final cancelled = await _reconciliation.deletePairsInvolving(
          <int>[transactionId],
        );
        await _reconciliation.deleteRejectionsInvolving(<int>[transactionId]);
        await _transactions.deleteById(transactionId);
        return cancelled > 0;
      }), onError: failureFromError);
}
