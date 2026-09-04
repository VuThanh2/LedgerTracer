import 'package:sqflite_common/sqlite_api.dart';

// Platform binding: SQLite của hệ điều hành ở nơi có `dart:io`, SQLite biên dịch
// sang WebAssembly ở trình duyệt.
import 'database_factory_provider_stub.dart'
    if (dart.library.io) 'database_factory_provider_io.dart'
    if (dart.library.js_interop) 'database_factory_provider_web.dart'
    as platform;

/// Nơi nền tảng được hỏi **một lần** xem SQLite ở đây đến từ đâu.
///
/// Tách khỏi `AppDatabase` cùng lý do `PlatformCapabilities` tách khỏi
/// `IsolateRunner`: phần còn lại của tầng Infrastructure chỉ làm việc với
/// [DatabaseFactory], nên không file nào khác cần conditional import — và test
/// dựng được một factory trong bộ nhớ mà không phải giả lập nền tảng.
abstract final class PlatformDatabase {
  /// Binding SQLite của nền tảng đang chạy.
  static DatabaseFactory get factory => platform.createPlatformDatabaseFactory();

  /// Nơi đặt cơ sở dữ liệu mang tên [fileName] trên nền tảng đang chạy: một
  /// đường dẫn file trên native, một khoá lưu trữ trên Web.
  static Future<String> pathFor(String fileName) =>
      platform.resolvePlatformDatabasePath(fileName);
}
