import '../../../application/transactions/edit_transaction/edit_transaction_dto.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/errors/transaction_errors.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/money.dart';
import '../../shared/formatting/money_formatter.dart';
import '../../shared/formatting/number_formatter.dart';

/// Chiều tiền, tách khỏi trị tuyệt đối của số tiền.
///
/// `Money` mang chiều bằng **dấu**, và đó là hình dạng đúng cho dữ liệu
/// (Rule – The Sign Carries the Direction). Nhưng nó không phải hình dạng đúng
/// cho một biểu mẫu: bắt người dùng gõ dấu trừ nghĩa là một dấu trừ bị quên sẽ
/// biến một khoản chi thành một khoản thu mà không có gì cản lại, và bàn phím số
/// trên Android thì không phải lúc nào cũng có dấu trừ ngay tầm tay.
///
/// Vì vậy biểu mẫu tách đôi: một điều khiển hai trạng thái cho chiều, một ô cho
/// trị tuyệt đối. Hai thứ được ghép lại thành một `Money` có dấu ở [validate].
enum MoneyDirection {
  incoming,
  outgoing;

  static MoneyDirection of(Money amount) =>
      amount.isOutgoing ? MoneyDirection.outgoing : MoneyDirection.incoming;

  bool get isOutgoing => this == MoneyDirection.outgoing;
}

/// Nội dung biểu mẫu sửa giao dịch **đang được gõ** (UC-05).
///
/// Cùng lý do tồn tại với `TransactionFilterDraft`: `EditTransactionRequest` đòi
/// một `Money` đã hợp lệ và một `DateTime` đã có, trong khi một biểu mẫu đang gõ
/// dở thì chưa có gì bảo đảm cả. Bản nháp giữ nguyên thứ người dùng gõ; ranh
/// giới giữa hai thế giới là [validate].
///
/// Tài khoản **không** có mặt ở đây: nó nằm trong fingerprint và trong chuỗi
/// nguồn gốc của giao dịch, nên Domain không cho sửa. Một ô nhập không đổi được
/// gì là một ô nhập nói dối.
final class TransactionEditDraft {
  const TransactionEditDraft({
    required this.transactionId,
    required this.bookingDate,
    required this.amountText,
    required this.direction,
    required this.currency,
    required this.counterpartyName,
    required this.description,
  });

  /// Đổ từ giao dịch hiện có sang biểu mẫu.
  factory TransactionEditDraft.of(Transaction tx) => TransactionEditDraft(
    transactionId: tx.transactionId!,
    bookingDate: tx.bookingDate,
    amountText: MoneyFormatter.plain(tx.amount),
    direction: MoneyDirection.of(tx.amount),
    currency: tx.amount.currency,
    counterpartyName: tx.counterpartyName ?? '',
    description: tx.description,
  );

  final int transactionId;
  final DateTime bookingDate;

  /// Trị tuyệt đối, đúng như người dùng gõ.
  final String amountText;

  final MoneyDirection direction;
  final Currency currency;
  final String counterpartyName;
  final String description;

  TransactionEditDraft copyWith({
    DateTime? bookingDate,
    String? amountText,
    MoneyDirection? direction,
    Currency? currency,
    String? counterpartyName,
    String? description,
  }) => TransactionEditDraft(
    transactionId: transactionId,
    bookingDate: bookingDate ?? this.bookingDate,
    amountText: amountText ?? this.amountText,
    direction: direction ?? this.direction,
    currency: currency ?? this.currency,
    counterpartyName: counterpartyName ?? this.counterpartyName,
    description: description ?? this.description,
  );

  /// Bản nháp có khác giao dịch gốc không.
  ///
  /// Dùng để khoá nút lưu và để hỏi trước khi rời biểu mẫu. Quan trọng hơn thế:
  /// một lần lưu **luôn** đánh dấu `isManuallyEdited` và tính lại fingerprint,
  /// nên lưu một bản không đổi gì vẫn để lại dấu vết vĩnh viễn trên dòng đó.
  bool isDirtyAgainst(Transaction original) {
    final validated = validate();
    final amount = validated.amount;
    if (amount == null) return true;
    return original.bookingDate != validated.bookingDate ||
        original.amount != amount ||
        (original.counterpartyName ?? '') != counterpartyName.trim() ||
        original.description != description;
  }

  /// Đổi bản nháp thành yêu cầu sửa, hoặc nói rõ ô nào sai.
  TransactionEditValidation validate() {
    final parsed = _parseAmount();
    return TransactionEditValidation(
      request: parsed.value == null
          ? null
          : EditTransactionRequest(
              transactionId: transactionId,
              bookingDate: bookingDate,
              amount: parsed.value!,
              // Chuỗi rỗng là **xoá trắng** đối tác, không phải "giữ nguyên":
              // biểu mẫu luôn gửi lên trọn bộ giá trị hiện tại.
              counterpartyName: counterpartyName.trim().isEmpty
                  ? null
                  : counterpartyName.trim(),
              description: description,
            ),
      bookingDate: bookingDate,
      amount: parsed.value,
      amountError: parsed.error,
    );
  }

  _ParsedAmount _parseAmount() {
    final decimal = NumberFormatter.toDecimalInput(amountText);
    if (decimal == null) {
      return const _ParsedAmount(null, 'Nhập một số tiền.');
    }
    try {
      final magnitude = Money.fromDecimalString(decimal, currency).absolute;
      return _ParsedAmount(
        direction.isOutgoing ? -magnitude : magnitude,
        null,
      );
    } on AmountPrecisionError {
      return _ParsedAmount(
        null,
        '${currency.code} không có tới từng ấy chữ số thập phân.',
      );
    } on MalformedAmountError {
      return const _ParsedAmount(null, 'Nhập một số tiền.');
    }
  }
}

/// Kết quả kiểm một bản nháp sửa.
final class TransactionEditValidation {
  const TransactionEditValidation({
    required this.request,
    required this.bookingDate,
    required this.amount,
    this.amountError,
  });

  /// `null` khi còn ô sai.
  final EditTransactionRequest? request;

  final DateTime bookingDate;
  final Money? amount;
  final String? amountError;

  bool get isValid => request != null;
}

final class _ParsedAmount {
  const _ParsedAmount(this.value, this.error);

  final Money? value;
  final String? error;
}
