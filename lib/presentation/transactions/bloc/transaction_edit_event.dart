import '../../../domain/value_objects/currency.dart';
import '../view_models/transaction_edit_draft.dart';

/// Những gì xảy ra trên biểu mẫu sửa một giao dịch (UC-05).
sealed class TransactionEditEvent {
  const TransactionEditEvent();
}

/// Mở biểu mẫu cho một giao dịch: nạp giá trị hiện tại và kiểm xem nó có đang
/// thuộc một cặp đối soát không, để cảnh báo hiện **trước** khi người dùng gõ
/// chứ không phải sau khi họ bấm lưu (UC-05).
final class TransactionEditStarted extends TransactionEditEvent {
  const TransactionEditStarted(this.transactionId);

  final int transactionId;
}

final class TransactionEditDateChanged extends TransactionEditEvent {
  const TransactionEditDateChanged(this.bookingDate);

  final DateTime bookingDate;
}

/// Đổi phần trị tuyệt đối của số tiền. Chiều tiền là một điều khiển riêng
/// ([TransactionEditDirectionChanged]).
final class TransactionEditAmountChanged extends TransactionEditEvent {
  const TransactionEditAmountChanged(this.amountText);

  final String amountText;
}

/// Đổi chiều tiền vào / tiền ra.
final class TransactionEditDirectionChanged extends TransactionEditEvent {
  const TransactionEditDirectionChanged(this.direction);

  final MoneyDirection direction;
}

/// Đổi loại tiền.
///
/// Có mặt vì lý do rất cụ thể: UC-05 tồn tại để sửa **dữ liệu sai do phân tích
/// file**, và đọc nhầm cột loại tiền là một trong những cái sai đó. Không có
/// đường sửa nó thì dòng ấy vĩnh viễn nằm nhầm tab loại tiền ở màn hình thống
/// kê, và cách duy nhất còn lại là xoá rồi nhập lại cả file.
final class TransactionEditCurrencyChanged extends TransactionEditEvent {
  const TransactionEditCurrencyChanged(this.currency);

  final Currency currency;
}

final class TransactionEditCounterpartyChanged extends TransactionEditEvent {
  const TransactionEditCounterpartyChanged(this.counterpartyName);

  final String counterpartyName;
}

final class TransactionEditDescriptionChanged extends TransactionEditEvent {
  const TransactionEditDescriptionChanged(this.description);

  final String description;
}

/// Bấm lưu.
final class TransactionEditSubmitted extends TransactionEditEvent {
  const TransactionEditSubmitted();
}
