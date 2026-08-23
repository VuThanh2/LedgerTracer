import 'domain_error.dart';

/// Vi phạm của aggregate ReconciliationPair và RejectedMatch (UC-08, UC-09).
sealed class ReconciliationError extends DomainError {
  const ReconciliationError(super.message);
}

final class PairNotFoundError extends ReconciliationError {
  const PairNotFoundError(this.pairId)
    : super('No reconciliation pair with id $pairId.');

  final int pairId;
}

/// Xác nhận là chuyển trạng thái một chiều: đường lùi là **từ chối**, vốn là một
/// bản ghi khác mang ý nghĩa khác (UC-09).
final class PairAlreadyConfirmedError extends ReconciliationError {
  const PairAlreadyConfirmedError(this.pairId)
    : super('Reconciliation pair $pairId is already confirmed.');

  final int pairId;
}

/// Một cặp — hay một phán quyết từ chối — mà hai vế là cùng một giao dịch thì
/// không mang thông tin gì.
final class SelfPairError extends ReconciliationError {
  const SelfPairError(this.transactionId)
    : super('Transaction $transactionId cannot be paired with itself.');

  final int transactionId;
}

/// Cửa sổ ghép cặp là tham số dò tìm chứ không phải phán quyết: 0 hay số âm sẽ
/// khiến mọi lần quét không tìm được gì.
final class InvalidMatchWindowError extends ReconciliationError {
  const InvalidMatchWindowError(this.days)
    : super('Match window must be at least one day, got $days.');

  final int days;
}

final class RejectedMatchNotFoundError extends ReconciliationError {
  const RejectedMatchNotFoundError(this.rejectedMatchId)
    : super('No rejected match with id $rejectedMatchId.');

  final int rejectedMatchId;
}
