/// Lớp gốc của mọi vi phạm luật nghiệp vụ do tầng Domain phát ra.
///
/// Domain báo vi phạm bằng cách **ném**: một value object từ chối được dựng từ
/// dữ liệu sai, một entity từ chối một chuyển trạng thái mà nó không được phép.
/// Việc đổi chúng thành `Result`/`Failure` là việc của tầng Application, nhờ vậy
/// Domain không dính gì tới chuyện truyền tải hay hiển thị.
///
/// Lỗi lập trình (bộ đếm âm, truyền entity chưa có định danh vào chỗ đòi định
/// danh) thì dùng `assert` — đó là bug, không phải kết quả nghiệp vụ.
abstract class DomainError implements Exception {
  const DomainError(this.message);

  /// Mô tả dành cho lập trình viên. Chữ hiển thị cho người dùng do tầng
  /// Presentation sinh ra từ **loại** lỗi, không phải từ chuỗi này.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}
