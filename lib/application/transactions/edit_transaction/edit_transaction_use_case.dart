import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/errors/transaction_errors.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/domain_failures.dart';
import 'edit_transaction_dto.dart';

/// Sửa một giao dịch đơn lẻ bị nhập sai (UC-05).
///
/// Đây là cơ chế **duy nhất** để chỉnh dữ liệu sai do phân tích file hoặc do
/// trùng lặp mà chống trùng không tự phát hiện được (hai giao dịch thật trùng
/// ngày, trùng số tiền, khác đối tác). `searchText` và `fingerprint` được
/// [Transaction.editedWith] tính lại — bản đã sửa mà giữ cột dẫn xuất cũ sẽ vừa
/// tìm không ra vừa bị coi là giao dịch mới ở lần nhập sau
/// (Rule – Normalization Happens Once, at Import).
///
/// Sửa và huỷ cặp phải cùng thành công hoặc cùng không, nên cả hai nằm trong một
/// [UnitOfWork].
final class EditTransactionUseCase {
  EditTransactionUseCase({
    required this._transactions,
    required this._reconciliation,
    required this._unitOfWork,
  });

  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final UnitOfWork _unitOfWork;

  Future<Result<EditTransactionResult>> execute(
    EditTransactionRequest request,
  ) => Result.guardAsync(() async {
    final existing = await _transactions.findById(request.transactionId);
    if (existing == null) {
      throw TransactionNotFoundError(request.transactionId);
    }

    final edited = existing.editedWith(
      bookingDate: request.bookingDate,
      amount: request.amount,
      counterpartyName: request.counterpartyName,
      description: request.description,
    );

    return _unitOfWork.transaction(() async {
      // Huỷ cặp mà giao dịch đang thuộc về — cả gợi ý lẫn đã xác nhận — vì đặc
      // trưng ghép cặp vừa bị thay đổi. Không ghi phán quyết từ chối: người dùng
      // đang sửa dữ liệu, không phủ nhận rằng hai giao dịch là một cặp (UC-05).
      final cancelled = await _reconciliation.deletePairsInvolvingTransaction(
        request.transactionId,
      );
      await _transactions.update(edited);
      return EditTransactionResult(
        transaction: edited,
        cancelledReconciliation: cancelled > 0,
      );
    });
  }, onError: failureFromError);
}
