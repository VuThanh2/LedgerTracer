/// Chuyện gì đã hỏng, diễn đạt bằng thứ ngôn ngữ mà tầng Presentation xử lý
/// được.
///
/// [Failure] cố ý **không phải** `DomainError`. Domain error nói "luật nghiệp vụ
/// này bị vi phạm"; failure nói "thao tác không cho ra kết quả, và đây là loại
/// vấn đề". Tầng Application dịch cái này sang cái kia — đó là lý do cả gói
/// `core` không cần biết gì về tài khoản, giao dịch hay lượt nhập.
///
/// Các nhánh là một tập đóng, nên `switch` trên chúng là vét cạn và giao diện
/// không thể bỏ sót trường hợp nào.
sealed class Failure {
  const Failure(this.message, {this.cause, this.stackTrace});

  /// Mô tả cho lập trình viên. Chữ hiển thị cho người dùng do Presentation chọn
  /// theo **nhánh** failure, không phải theo chuỗi này.
  final String message;

  /// Lỗi gốc, khi failure này bọc một lỗi khác.
  final Object? cause;

  final StackTrace? stackTrace;

  @override
  String toString() =>
      '$runtimeType: $message${cause == null ? '' : ' (cause: $cause)'}';
}

/// Dữ liệu vào phạm luật trước khi có gì bị đụng tới — tên tài khoản rỗng, khoảng
/// ngày ngược, số tiền loại tiền không biểu diễn được.
final class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {super.cause, super.stackTrace});
}

/// Bản ghi mà thao tác nhắm tới không còn tồn tại. Tách khỏi [ValidationFailure]
/// vì cách xử lý khác hẳn: làm mới màn hình chứ không phải sửa một ô nhập.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.cause, super.stackTrace});
}

/// Cơ sở dữ liệu cục bộ từ chối một phép đọc hoặc ghi. Mọi thứ nằm trên thiết bị
/// nên không có lỗi mạng nào để phải phân biệt.
final class StorageFailure extends Failure {
  const StorageFailure(super.message, {super.cause, super.stackTrace});
}

/// Không chọn/đọc/ghi được file — không đủ quyền, file biến mất, trình duyệt
/// chặn tải xuống.
final class FileAccessFailure extends Failure {
  const FileAccessFailure(super.message, {super.cause, super.stackTrace});
}

/// Bản thân file không dùng được: sai định dạng, hoặc hỏng tới mức không còn
/// tách được ra từng dòng để báo lỗi.
///
/// Một dòng lẻ không đọc được thì **không** thuộc nhánh này — nó đi về như dữ
/// liệu và trở thành dòng lỗi, để một dòng hỏng không bao giờ chặn các dòng tốt.
final class ParsingFailure extends Failure {
  const ParsingFailure(super.message, {super.cause, super.stackTrace});
}

/// Sai PIN, sai mật khẩu sao lưu, hoặc file sao lưu không qua được kiểm tra toàn
/// vẹn. Không bao giờ mang theo chính bí mật mà nó nói tới.
final class SecurityFailure extends Failure {
  const SecurityFailure(super.message, {super.cause, super.stackTrace});
}

/// Người dùng dừng thao tác. Không phải lỗi: phần đã ghi vẫn ở nguyên đó, và
/// giao diện báo là đã huỷ chứ không báo là có vấn đề.
final class CancelledFailure extends Failure {
  const CancelledFailure([super.message = 'The operation was cancelled.']);
}

/// Nền tảng không làm được — mở khoá sinh trắc học trên Web, chọn đường dẫn lưu
/// trong trình duyệt. Tách riêng để giao diện ẩn hẳn tuỳ chọn thay vì báo lỗi
/// sau khi người dùng đã bấm.
final class UnsupportedOnPlatformFailure extends Failure {
  const UnsupportedOnPlatformFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Những gì không lường trước. Luôn mang theo [cause] và [stackTrace], vì thứ
/// duy nhất làm được với nó là báo cáo lại.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(
    super.message, {
    required Object super.cause,
    required StackTrace super.stackTrace,
  });
}
