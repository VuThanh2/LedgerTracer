import '../errors/reconciliation_errors.dart';
import 'date_range.dart';

/// Độ lệch thời gian tối đa cho phép giữa hai vế của một giao dịch chuyển tiền
/// nội bộ (UC-08).
///
/// Mặc định ±3 ngày vì ngân hàng xử lý có độ trễ, và chỉnh được ngay trên màn
/// hình đối soát — chỉ sau khi nhìn kết quả một lần chạy mới biết cần nới hay
/// thu. Đổi ngưỡng chỉ ảnh hưởng lần quét sau và **không** đụng tới cặp đã xác
/// nhận: cặp đã xác nhận mang phán quyết của người dùng, còn cửa sổ chỉ là tham
/// số dò tìm (Rule – Suggested Is Not Confirmed).
final class MatchWindow {
  const MatchWindow._(this.days);

  /// Ném [InvalidMatchWindowError] nếu [days] nhỏ hơn 1.
  factory MatchWindow(int days) {
    if (days < 1) throw InvalidMatchWindowError(days);
    return MatchWindow._(days);
  }

  static const MatchWindow standard = MatchWindow._(3);

  final int days;

  /// Số ngày nguyên giữa hai ngày ghi nhận, bỏ dấu.
  int driftBetween(DateTime a, DateTime b) => DateRange.daysBetween(a, b).abs();

  bool covers(DateTime a, DateTime b) => driftBetween(a, b) <= days;

  @override
  bool operator ==(Object other) => other is MatchWindow && other.days == days;

  @override
  int get hashCode => days.hashCode;

  @override
  String toString() => '±$days day(s)';
}
