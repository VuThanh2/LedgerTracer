import '../../../domain/entities/import_error_row.dart';

/// Một dòng không đọc được, trên đường từ isolate phân tích về luồng chính.
///
/// Chưa phải [ImportErrorRow]: nó chưa biết mình thuộc bản ghi nhập nào — đó là
/// thứ chỉ luồng chính mới có. Trích đoạn được cắt **ngay tại đây** bằng chính
/// hàm cắt của Domain, để nó không bị cắt thêm lần nữa ở phía bên kia.
final class ParseError {
  ParseError({
    required this.sourceLineNumber,
    required String rawLine,
    required this.reason,
  }) : rawExcerpt = ImportErrorRow.excerptOf(rawLine);

  /// Số thứ tự dòng trong file gốc — thứ để người dùng sửa trên file rồi nhập
  /// lại (UC-11).
  final int sourceLineNumber;

  final String rawExcerpt;

  final String reason;

  @override
  String toString() => 'ParseError(line $sourceLineNumber: $reason)';
}
