/// Phép đổi qua lại giữa kiểu của Domain và ba kiểu vô hướng mà SQLite có
/// (`INTEGER`, `REAL`, `TEXT`).
///
/// Gom về một chỗ vì đây đúng là loại quy ước mà hai bản chép tay sẽ lệch nhau
/// trong im lặng: một mapper ghi ngày theo giờ địa phương còn một mapper đọc nó
/// như UTC thì dữ liệu vẫn "đọc được", chỉ là sai một ngày — và sai một ngày thì
/// hỏng cả gom nhóm thống kê lẫn cửa sổ ghép cặp.
abstract final class SqlCodec {
  /// Ngày ghi nhận thành `YYYY-MM-DD`.
  ///
  /// `bookingDate` đã được `DateRange.dateOnly` ghim về UTC nên ở đây không còn
  /// múi giờ nào để mất; định dạng cố định độ dài để so sánh theo từ điển trùng
  /// khít với so sánh theo thời gian, và chỉ mục dùng được cho cả `ORDER BY` lẫn
  /// `BETWEEN` (Rule – File Time and Device Time Are Different Things).
  static String bookingDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Đọc lại một ngày ghi nhận, luôn ở UTC.
  static DateTime parseBookingDate(String value) => DateTime.utc(
    int.parse(value.substring(0, 4)),
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8, 10)),
  );

  /// Mốc thời gian thiết bị thành epoch milliseconds UTC.
  static int timestamp(DateTime moment) => moment.toUtc().millisecondsSinceEpoch;

  static int? nullableTimestamp(DateTime? moment) =>
      moment == null ? null : timestamp(moment);

  /// Đọc lại một mốc thời gian, luôn ở UTC — chỉ tầng Presentation mới đổi sang
  /// giờ địa phương để hiển thị.
  static DateTime parseTimestamp(int value) =>
      DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);

  static DateTime? parseNullableTimestamp(Object? value) =>
      value == null ? null : parseTimestamp(value as int);

  static int boolean(bool value) => value ? 1 : 0;

  static bool parseBoolean(Object? value) => value == 1;

  /// Đọc một giá trị enum đã lưu dưới dạng tên của nó.
  ///
  /// Lưu bằng **tên** chứ không bằng chỉ số: chỉ số phụ thuộc vào thứ tự khai
  /// báo trong Dart, nên chỉ cần chèn một giá trị mới vào giữa là toàn bộ dữ
  /// liệu cũ đổi nghĩa mà không có lỗi nào báo. Tên không có tính chất đó.
  static T parseEnum<T extends Enum>(List<T> values, Object? stored) =>
      values.firstWhere((value) => value.name == stored);
}
