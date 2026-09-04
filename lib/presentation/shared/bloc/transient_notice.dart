import '../failures/feedback_message.dart';

/// Một thông báo chỉ hiện **một lần**: snackbar, hộp thoại báo kết quả.
///
/// BLoC không có kênh nào ngoài state, nên một thông báo dùng một lần vẫn phải
/// đi qua state — và ở đó nó gặp một vấn đề mà mọi ứng dụng BLoC đều gặp: state
/// được vẽ lại vì bất kỳ lý do gì, nên một `FeedbackMessage` nằm trong state sẽ
/// hiện lại mỗi lần đổi bộ lọc, mỗi lần cuộn thêm một trang.
///
/// [sequence] giải quyết đúng chỗ đó. Nó tăng ở mỗi lần phát, nên hai thông báo
/// **giống hệt nhau về chữ** vẫn là hai giá trị khác nhau, và bên nghe chỉ cần
/// so sánh với lần trước là biết có thứ mới hay không. Không có nó thì hai lần
/// từ chối liên tiếp chỉ hiện được một snackbar, vì lần thứ hai bằng lần thứ
/// nhất (UC-09 bước 3).
final class TransientNotice {
  const TransientNotice(this.message, this.sequence);

  final FeedbackMessage message;

  /// Số thứ tự tăng dần trong vòng đời một BLoC.
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is TransientNotice &&
      other.message == message &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(message, sequence);

  @override
  String toString() => '#$sequence $message';
}

/// Bộ phát [TransientNotice] của một BLoC.
///
/// Là một object nhỏ thay vì một biến đếm rời: biến đếm rời phải được nhớ tăng ở
/// mọi chỗ phát thông báo, và chỗ quên tăng chính là chỗ thông báo lặng lẽ không
/// hiện.
final class NoticeSink {
  int _sequence = 0;

  TransientNotice of(FeedbackMessage message) =>
      TransientNotice(message, ++_sequence);

  TransientNotice info(String text) => of(FeedbackMessage.info(text));

  TransientNotice success(String text) => of(FeedbackMessage.success(text));

  TransientNotice warning(String text) => of(FeedbackMessage.warning(text));

  TransientNotice danger(String text) => of(FeedbackMessage.danger(text));
}
