import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Binding SQLite cho nền tảng có `dart:io`.
///
/// Hai đường khác nhau vì lý do khác nhau, không phải vì sở thích:
///
/// * **Android/iOS** dùng `sqflite`, tức thư viện SQLite do chính hệ điều hành
///   cung cấp qua platform channel — đây là nền tảng đích thật của ứng dụng.
/// * **Desktop** dùng `sqflite_common_ffi`, vốn nạp SQLite qua FFI. Nó có mặt
///   không phải để phát hành mà để chạy được ứng dụng và **test tầng
///   Infrastructure** trên máy phát triển: cùng một câu lệnh SQL, cùng một
///   `DatabaseFactory`, nên thứ được kiểm chính là thứ sẽ chạy trên thiết bị.
DatabaseFactory createPlatformDatabaseFactory() {
  if (Platform.isAndroid || Platform.isIOS) return sqflite.databaseFactory;
  sqfliteFfiInit();
  return databaseFactoryFfi;
}

/// Đường dẫn file cơ sở dữ liệu, do chính factory của nền tảng quyết định.
///
/// Hỏi factory thay vì tự dựng đường dẫn: trên Android thư mục hợp lệ là thư mục
/// riêng của ứng dụng và chỉ hệ điều hành mới biết nó ở đâu.
Future<String> resolvePlatformDatabasePath(String fileName) async =>
    p.join(await createPlatformDatabaseFactory().getDatabasesPath(), fileName);
