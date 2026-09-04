import 'package:sqflite_common/sqlite_api.dart';

/// Binding dự phòng cho nền tảng không có cả `dart:io` lẫn thư viện trình duyệt.
///
/// Nó tồn tại để conditional import trong `database_factory_provider.dart` luôn
/// phân giải được; không nền tảng đích nào của dự án chạy vào đây. Khác với
/// binding của concurrency — nơi suy biến về luồng chính vẫn chạy được — ở đây
/// không có lựa chọn suy biến nào: không có SQLite thì không có nơi lưu dữ liệu,
/// và im lặng chạy tiếp với một kho rỗng còn tệ hơn dừng lại.
DatabaseFactory createPlatformDatabaseFactory() => throw UnsupportedError(
  'No SQLite binding is available on this platform.',
);

Future<String> resolvePlatformDatabasePath(String fileName) =>
    throw UnsupportedError('No SQLite binding is available on this platform.');
