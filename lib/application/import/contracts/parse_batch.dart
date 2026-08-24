import 'parse_error.dart';
import 'parsed_row.dart';

/// Một lô kết quả phân tích đi từ isolate về luồng ghi: các dòng đọc được, các
/// dòng lỗi của cùng khoảng đó, số thứ tự lô và cờ lô cuối.
///
/// Truyền theo **lô** chứ không theo từng dòng là điều kiện để việc dùng isolate
/// không làm mọi thứ chậm đi: mỗi thông điệp qua ranh giới là một lần sao chép,
/// gửi từng dòng còn tốn hơn cả việc phân tích. Ranh giới giữa các lô cũng là nơi
/// **duy nhất** tiến trình được báo và yêu cầu huỷ được kiểm (UC-02, UC-14).
///
/// [errors] đi chung lô với [rows] một cách có chủ đích: cả hai được sinh ra
/// trong cùng một khoảng dòng và được ghi cùng nhau ở giai đoạn ghi, nên gộp vào
/// một thông điệp giữ cho mỗi lô là một đơn vị ghi trọn vẹn thay vì hai luồng
/// thông điệp phải ghép lại.
final class ParseBatch {
  const ParseBatch({
    required this.index,
    required this.rows,
    required this.errors,
    required this.isLast,
  });

  /// Số thứ tự lô trong phạm vi một file, bắt đầu từ 0.
  final int index;

  final List<ParsedRow> rows;

  final List<ParseError> errors;

  /// Lô cuối của file. Là thông tin tham khảo cho phía ghi; kết cục thật của một
  /// file (chạy hết hay bị huỷ) do tín hiệu huỷ quyết định, không do cờ này.
  final bool isLast;

  /// Số dòng lô này đã xử lý — dùng để cộng dồn tiến trình.
  int get processedCount => rows.length + errors.length;

  @override
  String toString() =>
      'ParseBatch(#$index, ${rows.length} row(s), '
      '${errors.length} error(s)${isLast ? ', last' : ''})';
}
