import '../errors/transaction_errors.dart';

/// Khoảng ngày ghi nhận, hai đầu đều tính vào; dùng làm tiêu chí lọc (UC-07) và
/// làm cửa sổ của truy vấn thống kê (UC-10).
///
/// Hai cận đều được chuẩn hoá về ngày không có giờ: `bookingDate` đến từ file
/// sao kê và chỉ mang ngày (Rule – File Time and Device Time Are Different
/// Things).
final class DateRange {
  const DateRange._(this.from, this.to);

  /// Ném [InvalidDateRangeError] nếu hai cận ngược thứ tự.
  factory DateRange({required DateTime from, required DateTime to}) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (start.isAfter(end)) {
      throw InvalidDateRangeError(start, end);
    }
    return DateRange._(start, end);
  }

  factory DateRange.singleDay(DateTime date) => DateRange(from: date, to: date);

  final DateTime from;
  final DateTime to;

  bool contains(DateTime date) {
    final day = dateOnly(date);
    return !day.isBefore(from) && !day.isAfter(to);
  }

  int get lengthInDays => daysBetween(from, to) + 1;

  /// Bỏ phần giờ và ghim về UTC, để phép tính trên ngày ghi nhận không bị lệch
  /// bởi mốc đổi giờ mùa.
  static DateTime dateOnly(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);

  /// Khoảng cách nguyên ngày có dấu; là **nơi duy nhất** định nghĩa "cách nhau
  /// bao nhiêu ngày" (cửa sổ ghép cặp ở UC-08 dùng lại).
  static int daysBetween(DateTime from, DateTime to) =>
      dateOnly(to).difference(dateOnly(from)).inDays;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => '${from.toIso8601String()}..${to.toIso8601String()}';
}
