import 'isolate_runner.dart';
import 'platform_capabilities.dart';

/// Binding cho Web.
///
/// Trình duyệt không có `dart:isolate`, nên việc đẩy tác vụ ra nền suy biến
/// thành chạy thẳng trên luồng đang vẽ giao diện. Hệ quả được nói ra trên giao
/// diện chứ không giấu đi (UC-14):
///
/// * mất isolate ⇒ giảm **độ mượt giao diện**, lô dài hiện ra thành giật;
/// * mất song song ⇒ tăng **tổng thời gian**, các file phân tích nối tiếp nhau;
/// * backpressure trở nên vô nghĩa — sản xuất và tiêu thụ chung một luồng nên
///   không bên nào chạy nhanh hơn bên kia.
IsolateRunner createPlatformRunner() =>
    const MainThreadRunner(PlatformCapabilities.web());
