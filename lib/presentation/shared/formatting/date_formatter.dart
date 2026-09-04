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

  /// Đọc ngược [day]: `dd/mm/yyyy` thành một [DateTime] theo UTC, hoặc `null`
  /// nếu chuỗi không phải một ngày.
  ///
  /// Ô ngày của Filter Panel là ô chữ chứ không phải lịch bật lên, nên phép đọc
  /// ngược này là bắt buộc. Nó nhận cả `-` và `.` làm dấu phân cách vì người
  /// dùng gõ tay, nhưng **không** đoán thứ tự: `03/04/2026` luôn là ngày 3 tháng
  /// 4 — đoán theo giá trị sẽ khiến cùng một chuỗi mang hai nghĩa tuỳ tháng.
  static DateTime? tryParseDay(String raw) {
    final parts = raw.trim().split(RegExp(r'[/\-.]'));
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    if (parts[2].length != 4) return null;

    final parsed = DateTime.utc(year, month, day);
    // Chặn ngày tràn tháng: `31/02/2026` sẽ được `DateTime` cuộn sang tháng 3.
    if (parsed.day != day || parsed.month != month) return null;
    return parsed;
  }

  static String _pad(int value) => value.toString().padLeft(2, '0');
}
