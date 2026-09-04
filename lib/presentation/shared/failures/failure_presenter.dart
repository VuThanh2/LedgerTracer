import '../../../core/result/failure.dart';
import 'feedback_message.dart';

/// Đổi một [Failure] thành câu hiển thị cho người dùng.
///
/// Đây là nơi **duy nhất** làm việc đó, đối xứng với `failureFromError` ở tầng
/// Application — một bên dịch lỗi Domain thành failure, bên này dịch failure
/// thành chữ. Rải phép dịch vào từng BLoC nghĩa là mỗi màn hình sẽ tự nghĩ ra
/// một cách nói khác nhau cho cùng một sự cố.
///
/// Chữ được chọn theo **nhánh** của failure chứ không lấy `failure.message`:
/// chuỗi đó do tầng dưới viết cho lập trình viên, bằng tiếng Anh, và thường có
/// cả định danh bản ghi trong đó. Nó đi theo [FeedbackMessage.detail] để màn
/// hình chẩn đoán còn dùng được.
///
/// Một số nhánh cần câu chữ sát ngữ cảnh hơn mặc định — "không tìm thấy" trên
/// màn hình đối soát nên nói về cặp, không nói chung chung — nên [of] nhận
/// [context], một mảnh danh từ ngắn do màn hình gọi truyền vào.
abstract final class FailurePresenter {
  static FeedbackMessage of(Failure failure, {String? context}) {
    final subject = context ?? 'this item';
    return switch (failure) {
      // Dữ liệu vào phạm luật: người dùng sửa được ngay tại ô nhập, nên đây là
      // cảnh báo chứ không phải sự cố.
      ValidationFailure() => FeedbackMessage.warning(
        'Something you entered is not valid. Check the fields you just filled '
        'in.',
        detail: failure.message,
      ),

      // Bản ghi đã biến mất: cách xử lý là làm mới màn hình, không phải sửa ô
      // nhập — nên nó là một nhánh riêng và câu chữ phải nói ra điều đó.
      NotFoundFailure() => FeedbackMessage.warning(
        'That $subject is no longer there. The list may have changed — reload '
        'it.',
        detail: failure.message,
      ),

      StorageFailure() => FeedbackMessage.danger(
        'Could not read or write data on this device. Try again.',
        detail: failure.message,
      ),

      FileAccessFailure() => FeedbackMessage.danger(
        'Could not reach the file. Check the access permission, or pick the '
        'file again.',
        detail: failure.message,
      ),

      // Cả file không đọc được — khác hẳn một dòng lỗi, thứ đi về như dữ liệu và
      // không bao giờ tới đây (UC-02).
      ParsingFailure() => FeedbackMessage.danger(
        'The file is not in a supported format, or it is damaged, so it cannot '
        'be read.',
        detail: failure.message,
      ),

      // Chạm tới lớp bảo vệ. Câu chữ không bao giờ nói bí mật sai ở chỗ nào.
      SecurityFailure() => FeedbackMessage.danger(
        'Wrong PIN or wrong password.',
        detail: failure.message,
      ),

      // Huỷ là một kết cục, không phải một lỗi: phần đã ghi vẫn ở đó, nên giao
      // diện báo là đã dừng chứ không báo là có vấn đề (UC-02 bước 7).
      CancelledFailure() => FeedbackMessage.info(
        'Stopped as you asked. Everything already processed is kept.',
        detail: failure.message,
      ),

      // Nền tảng không làm được. Giao diện lẽ ra đã ẩn hẳn tuỳ chọn, nên tới đây
      // nghĩa là lưới an toàn đã đỡ (UC-12, UC-14).
      UnsupportedOnPlatformFailure() => FeedbackMessage.info(
        'The platform this build runs on does not support that.',
        detail: failure.message,
      ),

      UnexpectedFailure() => FeedbackMessage.danger(
        'Something unexpected went wrong.',
        detail: failure.message,
      ),
    };
  }

  /// Huỷ có kết cục riêng ở gần như mọi màn hình có tác vụ nền, nên nó được hỏi
  /// đủ nhiều để đáng có một vị từ thay vì một phép `is` lặp lại.
  static bool isCancellation(Failure failure) => failure is CancelledFailure;
}
