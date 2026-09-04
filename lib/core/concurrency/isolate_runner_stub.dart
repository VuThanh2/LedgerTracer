import 'isolate_runner.dart';
import 'platform_capabilities.dart';

/// Binding dự phòng cho nền tảng không có cả `dart:isolate` lẫn thư viện trình
/// duyệt.
///
/// Nó tồn tại để conditional import trong `isolate_runner.dart` luôn phân giải
/// được; không nền tảng đích nào của dự án chạy vào đây. Hành xử như binding của
/// Web — chạy thẳng trên luồng hiện tại là thứ ở đâu cũng làm được — thay vì ném
/// lỗi, để một nền tảng bất ngờ thì suy biến chứ không sập.
IsolateRunner createPlatformRunner() =>
    const MainThreadRunner(PlatformCapabilities.web());
