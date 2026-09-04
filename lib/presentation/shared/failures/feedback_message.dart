/// Mức độ của một phản hồi hệ thống, ánh xạ thẳng sang bốn kiểu banner của hệ
/// thiết kế (warning / danger / info / success).
///
/// Là một kênh ngữ nghĩa riêng: banner luôn full-width, luôn có icon, viền trái
/// 3px — khác hẳn pill trạng thái (có nền, không icon) và khác hẳn màu chữ chỉ
/// chiều tiền. Ba kênh tách nhau bằng **hình dạng**, không bằng hue, nên chỗ
/// duy nhất được chọn giữa chúng là kiểu dữ liệu, không phải màu.
enum FeedbackSeverity {
  /// Thông tin thuần: giới hạn nền tảng, ghi chú về dữ liệu.
  info,

  /// Thao tác đã xong và có kết quả đáng nói.
  success,

  /// Có thứ cần người dùng để mắt tới nhưng không chặn: dữ liệu vào chưa hợp lệ,
  /// lượt nhập bị gián đoạn, số tài khoản lệch.
  warning,

  /// Thao tác không đi tới đâu, hoặc chạm tới lớp bảo vệ.
  danger,
}

/// Một câu để hiển thị, kèm mức độ và phần chi tiết dành cho lập trình viên.
///
/// [detail] cố ý tách khỏi [text]: chuỗi trong `Failure.message` là mô tả kỹ
/// thuật bằng tiếng Anh do tầng dưới viết cho lập trình viên, và ném nguyên nó
/// lên màn hình là cách nhanh nhất để người dùng đọc được `No transaction with
/// id 41`. Nó vẫn được giữ lại vì màn hình chẩn đoán và log cần tới.
final class FeedbackMessage {
  const FeedbackMessage(this.text, this.severity, {this.detail});

  const FeedbackMessage.info(String text, {String? detail})
    : this(text, FeedbackSeverity.info, detail: detail);

  const FeedbackMessage.success(String text, {String? detail})
    : this(text, FeedbackSeverity.success, detail: detail);

  const FeedbackMessage.warning(String text, {String? detail})
    : this(text, FeedbackSeverity.warning, detail: detail);

  const FeedbackMessage.danger(String text, {String? detail})
    : this(text, FeedbackSeverity.danger, detail: detail);

  final String text;

  final FeedbackSeverity severity;

  /// Mô tả kỹ thuật gốc, không bao giờ hiển thị trong luồng bình thường.
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is FeedbackMessage &&
      other.text == text &&
      other.severity == severity &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(text, severity, detail);

  @override
  String toString() => '[${severity.name}] $text';
}
