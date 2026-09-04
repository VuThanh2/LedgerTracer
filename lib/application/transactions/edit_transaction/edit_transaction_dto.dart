import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/money.dart';

/// Một lần sửa tay trọn bộ trường sửa được của giao dịch (UC-05).
///
/// Mọi trường đều bắt buộc vì biểu mẫu sửa luôn gửi lên toàn bộ giá trị hiện tại;
/// truyền `null` cho [counterpartyName] là xoá trắng nó. Tài khoản không sửa được
/// — nó nằm trong fingerprint và trong chuỗi nguồn gốc.
final class EditTransactionRequest {
  const EditTransactionRequest({
    required this.transactionId,
    required this.bookingDate,
    required this.amount,
    required this.counterpartyName,
    required this.description,
  });

  final int transactionId;
  final DateTime bookingDate;
  final Money amount;
  final String? counterpartyName;
  final String description;
}

/// Kết quả một lần sửa: bản đã cập nhật, và liệu có cặp đối soát nào bị huỷ theo
/// để giao diện thông báo (UC-05).
final class EditTransactionResult {
  const EditTransactionResult({
    required this.transaction,
    required this.cancelledReconciliation,
  });

  final Transaction transaction;

  /// Sửa một giao dịch đang thuộc cặp — dù gợi ý hay đã xác nhận — sẽ huỷ cặp đó,
  /// vì gợi ý sinh ra từ chính số tiền và thời điểm vừa bị thay đổi. Việc huỷ này
  /// **không** ghi thành phán quyết từ chối (UC-05).
  final bool cancelledReconciliation;
}
