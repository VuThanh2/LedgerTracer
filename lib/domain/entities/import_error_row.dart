/// Một dòng trong file sao kê không đọc được, giữ lại để người dùng sửa trên
/// file gốc rồi nhập lại (UC-02 bước 8, UC-11).
///
/// Lỗi phân tích đi về dưới dạng **dữ liệu**, không phải exception: một dòng
/// hỏng không được làm dừng các dòng còn lại, và exception thì không vượt qua
/// được ranh giới isolate mà không giết cả tác vụ.
final class ImportErrorRow {
  const ImportErrorRow({
    this.errorRowId,
    required this.recordId,
    required this.sourceLineNumber,
    required this.rawExcerpt,
    required this.reason,
  });

  /// Dựng bản ghi từ dòng gốc, có cắt ngắn phần trích đoạn — file hỏng có thể
  /// chứa dòng rất dài, mà chỉ cần đủ để nhận ra dòng đó là được.
  factory ImportErrorRow.from({
    required int recordId,
    required int sourceLineNumber,
    required String rawLine,
    required String reason,
  }) => ImportErrorRow(
    recordId: recordId,
    sourceLineNumber: sourceLineNumber,
    rawExcerpt: excerptOf(rawLine),
    reason: reason,
  );

  static const int maxExcerptLength = 200;

  /// Cắt một dòng gốc về độ dài lưu được. Là **nơi duy nhất** làm việc cắt này:
  /// phía isolate cũng dùng nó khi dựng `ParseError`, nên một trích đoạn không
  /// bao giờ bị cắt hai lần rồi mất thêm ký tự.
  static String excerptOf(String rawLine) => rawLine.length <= maxExcerptLength
      ? rawLine
      : '${rawLine.substring(0, maxExcerptLength)}…';

  final int? errorRowId;

  /// Lượt nhập của file chứa dòng này.
  final int recordId;

  /// Số thứ tự dòng trong file gốc — thiếu nó thì người dùng không biết đường
  /// tìm dòng để sửa (UC-11).
  final int sourceLineNumber;

  final String rawExcerpt;

  /// Lý do bị bỏ qua, ví dụ số tiền không đọc được hay thiếu ngày.
  final String reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportErrorRow &&
          other.errorRowId != null &&
          other.errorRowId == errorRowId);

  @override
  int get hashCode => errorRowId?.hashCode ?? identityHashCode(this);

  @override
  String toString() => 'ImportErrorRow(line $sourceLineNumber: $reason)';
}
