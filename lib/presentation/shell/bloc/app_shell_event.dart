import '../view_models/navigation_intent.dart';

/// Những gì xảy ra ở khung điều hướng bao ngoài toàn bộ ứng dụng.
sealed class AppShellEvent {
  const AppShellEvent();
}

/// Khởi động ứng dụng.
///
/// Đây là chỗ lượt quét dọn các lượt nhập bị gián đoạn chạy — đúng một lần, và
/// **trước** khi lịch sử nhập được đọc lần đầu. Không có nơi nào khác làm được:
/// một tiến trình bị hệ điều hành kết liễu hay một tab trình duyệt bị đóng thì
/// không có mã lệnh nào chạy để ghi lại trạng thái, nên cách duy nhất nhận ra
/// chuyện đó là ở lần sống dậy kế tiếp (UC-03).
final class AppShellStarted extends AppShellEvent {
  const AppShellStarted();
}

/// Chạm vào một ô trên thanh điều hướng.
final class AppShellDestinationSelected extends AppShellEvent {
  const AppShellDestinationSelected(this.destination);

  final NavDestination destination;
}

/// Một màn hình yêu cầu mở màn hình khác kèm ngữ cảnh.
final class AppShellNavigationRequested extends AppShellEvent {
  const AppShellNavigationRequested(this.intent);

  final NavigationIntent intent;
}

/// Màn hình đích đã nhận và áp dụng xong ngữ cảnh.
///
/// Cần một sự kiện riêng thay vì để yêu cầu tự hết hạn: chừng nào nó còn nằm
/// trong state thì một lần vẽ lại bất kỳ cũng có thể khiến màn hình đích áp dụng
/// lại nó, và ghi đè lên đúng những gì người dùng vừa sửa bằng tay.
final class AppShellNavigationConsumed extends AppShellEvent {
  const AppShellNavigationConsumed();
}

/// Đóng thông báo về các lượt nhập bị gián đoạn.
final class AppShellRecoveryNoticeDismissed extends AppShellEvent {
  const AppShellRecoveryNoticeDismissed();
}
