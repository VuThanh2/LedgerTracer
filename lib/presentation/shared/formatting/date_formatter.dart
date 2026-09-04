import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/date_range.dart';

/// Đưa [DateTime] về chuỗi hiển thị theo quy ước Việt Nam (`dd/MM/yyyy`).
///
/// Cũng tự viết thay vì dùng `intl`, và cũng vì một lý do cụ thể chứ không phải
/// để tiết kiệm một dependency: mọi ngày trong ứng dụng đều là **ngày ghi nhận
/// đã cắt về 0 giờ** (`DateRange.dateOnly`), nên không có múi giờ, không có
/// lịch địa phương và không có dạng thức nào khác để phải chọn. Toàn bộ nhu cầu
/// gói gọn trong ba mẫu dưới đây.
abstract final class DateFormatter {
  /// `04/09/2026`. Dạng của mọi ô ngày trong bảng và ở màn hình chi tiết.
  static String day(DateTime date) =>
      '${_pad(date.day)}/${_pad(date.month)}/${date.year}';

  /// `04/09/2026 14:07`. Chỉ dùng cho dấu thời gian của lượt nhập và lượt sao
  /// lưu — ở đó giờ phút là thứ phân biệt hai lượt trong cùng một ngày (UC-03).
  static String dayTime(DateTime time) {
    final local = time.isUtc ? time.toLocal() : time;
    return '${day(local)} ${_pad(local.hour)}:${_pad(local.minute)}';
  }

  /// Nhãn một cột của biểu đồ dòng tiền, theo đúng độ mịn đang chọn (UC-10).
  ///
  /// Nhãn phải nói đúng độ mịn: in `04/09/2026` cho một cột gom cả tháng khiến
  /// người đọc tưởng đó là số liệu của riêng ngày mùng 4.
  static String period(DateTime periodStart, CashFlowPeriod period) =>
      switch (period) {
        CashFlowPeriod.day => day(periodStart),
        CashFlowPeriod.month =>
          '${_pad(periodStart.month)}/${periodStart.year}',
        CashFlowPeriod.year => '${periodStart.year}',
      };

  /// `04/09/2026 – 30/09/2026`, hoặc chỉ một ngày khi khoảng chỉ dài một ngày.
  static String range(DateRange range) => range.lengthInDays == 1
      ? day(range.from)
      : '${day(range.from)} \u2013 ${day(range.to)}';

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
