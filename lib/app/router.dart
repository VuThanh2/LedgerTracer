import 'package:flutter/material.dart';

import '../presentation/accounts/accounts_page.dart';
import '../presentation/diagnostics/diagnostics_page.dart';
import '../presentation/settings/backup_restore_page.dart';
import '../presentation/settings/settings_page.dart';
import '../presentation/shell/app_shell.dart';

/// Tên của những route đứng ngoài khung điều hướng chính.
///
/// Bốn màn hằng ngày **không** có tên ở đây: chúng là bốn tab của cùng một khung
/// và chuyển giữa chúng là đổi trạng thái của `AppShellBloc`, không phải đẩy một
/// route. Đặt tên route cho chúng sẽ dựng lại trang mỗi lần chuyển tab, và một
/// lượt nhập đang chạy sẽ chết theo.
abstract final class LedgerRoutes {
  static const String settings = '/settings';
  static const String accounts = '/settings/accounts';
  static const String backup = '/settings/backup';
  static const String diagnostics = '/settings/diagnostics';
}

/// Bảng route của ứng dụng.
///
/// Chỉ chứa những màn **không cần tham số**. Các màn có tham số — chi tiết giao
/// dịch, form sửa — được đẩy bằng hàm `route()` tĩnh của chính chúng, vì chúng
/// còn phải mang theo BLoC của khung ứng dụng xuống route con; một tên chuỗi
/// không chở được thứ đó, và ép nó qua `settings.arguments` sẽ đánh mất kiểu.
///
/// Route gốc `/` cố ý **không** có mặt: nó là cổng khoá ứng dụng, do
/// `MaterialApp.home` cung cấp. Đặt thêm một lối vào [AppShell] theo tên là mở
/// một đường đi vòng qua lớp khoá.
///
/// Bốn màn ở đây được đẩy bằng `pushNamed` chứ không bằng `push` với một
/// `MaterialPageRoute` dựng tại chỗ. Trên bản Web, tên route trở thành đường dẫn
/// trên thanh địa chỉ, nên nút Back của trình duyệt và việc tải lại trang hoạt
/// động đúng — thứ mà một route dựng tại chỗ không có.
abstract final class LedgerRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) =>
      switch (settings.name) {
        LedgerRoutes.settings => SettingsPage.route(),
        LedgerRoutes.accounts => AccountsPage.route(),
        LedgerRoutes.backup => BackupRestorePage.route(),
        LedgerRoutes.diagnostics => DiagnosticsPage.route(),
        _ => null,
      };
}
