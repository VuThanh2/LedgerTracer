import '../../../application/transactions/query_transactions/query_transactions_dto.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/money.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/money_formatter.dart';

/// Một dòng của danh sách giao dịch, đã thành chữ (UC-04).
///
/// Định dạng xảy ra **một lần khi dựng dòng**, không phải mỗi lần vẽ lại. Đây là
/// màn hình chính của ứng dụng và nó cuộn qua hàng trăm nghìn dòng; ghép chuỗi
/// trong `build()` nghĩa là làm lại đúng từng ấy việc ở mỗi khung hình, trên
/// chính luồng mà cả kiến trúc concurrency của dự án tồn tại để giữ cho rảnh.
final class TransactionRowViewModel {
  const TransactionRowViewModel({
    required this.transactionId,
    required this.dateText,
    required this.accountName,
    required this.amountText,
    required this.currencyCode,
    required this.isIncoming,
    required this.counterpartyText,
    required this.descriptionText,
    required this.isReconciled,
    required this.isManuallyEdited,
  });

  factory TransactionRowViewModel.of(TransactionListItem item) {
    final tx = item.transaction;
    return TransactionRowViewModel(
      // Chỉ giao dịch đã lưu mới lên tới danh sách, nên định danh luôn có.
      transactionId: tx.transactionId!,
      dateText: DateFormatter.day(tx.bookingDate),
      accountName: item.accountDisplayName,
      amountText: MoneyFormatter.signed(tx.amount),
      currencyCode: tx.amount.currency.code,
      isIncoming: tx.amount.isIncoming,
      counterpartyText: tx.counterpartyName ?? '',
      descriptionText: tx.description,
      isReconciled: item.isReconciled,
      isManuallyEdited: tx.isManuallyEdited,
    );
  }

  final int transactionId;

  final String dateText;

  /// Danh sách gộp mọi tài khoản, nên thiếu tên tài khoản là người dùng không
  /// đọc hiểu được dữ liệu (UC-04).
  final String accountName;

  /// Đã có dấu `+`/`−`; mã loại tiền đứng ở cột riêng.
  final String amountText;

  final String currencyCode;

  /// Chiều tiền, để giao diện chọn màu chữ. Dấu đã có sẵn trong [amountText] —
  /// màu là kênh phụ trợ, không phải kênh duy nhất.
  final bool isIncoming;

  final String counterpartyText;

  final String descriptionText;

  /// Thuộc một cặp **đã xác nhận**. Chỉ báo này là liên kết mở màn hình đối soát
  /// tới đúng cặp đó (UC-04, UC-09).
  final bool isReconciled;

  final bool isManuallyEdited;
}

/// Toàn bộ nội dung màn hình chi tiết một giao dịch (UC-04 bước 3–4).
///
/// Tách khỏi [TransactionRowViewModel] chứ không thêm trường vào đó: dòng danh
/// sách được dựng hàng trăm nghìn lần và chỉ hiện năm cột, còn chi tiết được
/// dựng một lần và hiện mọi thứ. Gộp lại là trả giá dựng chuỗi của cái thứ hai
/// ở quy mô của cái thứ nhất.
final class TransactionDetailViewModel {
  const TransactionDetailViewModel({
    required this.transactionId,
    required this.accountId,
    required this.dateText,
    required this.accountName,
    required this.amountText,
    required this.amount,
    required this.counterpartyText,
    required this.descriptionText,
    required this.confirmedPairId,
    required this.isManuallyEdited,
    required this.sourceLineText,
    required this.importedAtText,
  });

  factory TransactionDetailViewModel.of(
    Transaction tx, {
    required String accountName,
    required int? confirmedPairId,
  }) => TransactionDetailViewModel(
    transactionId: tx.transactionId!,
    accountId: tx.accountId,
    dateText: DateFormatter.day(tx.bookingDate),
    accountName: accountName,
    amountText: MoneyFormatter.signedWithCurrency(tx.amount),
    amount: tx.amount,
    counterpartyText: tx.counterpartyName ?? '',
    descriptionText: tx.description,
    confirmedPairId: confirmedPairId,
    isManuallyEdited: tx.isManuallyEdited,
    // Số thứ tự dòng trong file gốc là thứ làm cho luồng "mở file gốc ra đối
    // chiếu" khả thi, nên nó có mặt ở màn hình chi tiết (UC-04 bước 4).
    sourceLineText: tx.sourceLineNumber?.toString() ?? '—',
    importedAtText: DateFormatter.dayTime(tx.importedAt),
  );

  final int transactionId;
  final int accountId;
  final String dateText;
  final String accountName;
  final String amountText;

  /// Giá trị gốc, để biểu mẫu sửa đổ vào ô nhập mà không phải đọc ngược chuỗi.
  final Money amount;

  final String counterpartyText;
  final String descriptionText;

  /// Cặp đối soát **đã xác nhận** chứa giao dịch này, `null` khi không có.
  ///
  /// Một trường thay vì một cờ boolean: chỉ báo "đã đối soát" và liên kết mở
  /// thẳng tới đúng cặp là cùng một sự thật, và tách làm hai là mở đường cho một
  /// chỉ báo sáng lên mà liên kết không biết dẫn đi đâu.
  final int? confirmedPairId;

  final bool isManuallyEdited;
  final String sourceLineText;
  final String importedAtText;

  bool get isReconciled => confirmedPairId != null;
}
