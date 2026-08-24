import '../../../domain/entities/import_error_row.dart';

/// Một dòng trong file không đọc được, đi về từ isolate phân tích **dưới dạng dữ
/// liệu** chứ không phải exception.
///
/// Đây là điều kiện để một dòng hỏng không làm dừng các dòng còn lại (UC-02):
/// exception ném qua ranh giới isolate thì mất stack trace và giết cả tác vụ,
/// còn một giá trị thì đi về bình thường theo từng lô. Sau này nó trở thành một
/// [ImportErrorRow] ở giai đoạn ghi, khi đã có `recordId` để trỏ về.
///
/// Giữ sẵn [rawExcerpt] thay vì cả dòng gốc: file hỏng có thể chứa dòng rất dài,
/// mà mỗi lần đi qua ranh giới là một lần sao chép — chỉ cần đủ để người dùng
/// nhận ra dòng đó trên file gốc là được (UC-11).
final class ParseError {
  ParseError({
    required this.sourceLineNumber,
    required String rawLine,
    required this.reason,
  }) : rawExcerpt = rawLine.length <= ImportErrorRow.maxExcerptLength
           ? rawLine
           : '${rawLine.substring(0, ImportErrorRow.maxExcerptLength)}…';

  /// Số thứ tự dòng trong file gốc — thiếu nó thì người dùng không biết đường
  /// tìm dòng để sửa.
  final int sourceLineNumber;

  /// Trích đoạn dòng gốc, đã cắt ngắn.
  final String rawExcerpt;

  /// Lý do bị bỏ qua, ví dụ số tiền không đọc được hay thiếu ngày.
  final String reason;

  @override
  String toString() => 'ParseError(line $sourceLineNumber: $reason)';
}
