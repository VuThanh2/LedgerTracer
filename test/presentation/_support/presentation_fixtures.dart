/// Dựng lại đúng bộ đồ nghề mà test tầng Application đã có, cho test tầng
/// Presentation.
///
/// Re-export thay vì chép sang một bản riêng, và đó là chủ đích: BLoC được test
/// **qua use case thật** chạy trên cơ sở dữ liệu giả, không qua một bộ mock của
/// chính use case. Mock use case chỉ chứng minh BLoC gọi đúng phương thức; thứ
/// đáng kiểm ở đây là trạng thái màn hình sau khi dữ liệu thật đã đổi — mà điều
/// đó chỉ kiểm được khi cả chuỗi use case → repository cùng chạy.
///
/// Hai bản fake song song sẽ lệch nhau ngay lần đầu ai đó sửa một bất biến ở
/// một bên.
library;

export '../../application/_support/fake_repositories.dart';
export '../../application/_support/fake_gateways.dart';
export '../../application/_support/seed.dart';
