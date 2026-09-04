import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Binding SQLite cho Flutter Web: SQLite biên dịch sang WebAssembly, dữ liệu
/// nằm trong bộ nhớ bền vững của chính trình duyệt.
///
/// Nguyên tắc offline giữ nguyên trên Web — không byte nào rời khỏi máy người
/// dùng (FR-23). Cái đổi là **nơi** "cục bộ" trỏ tới: gỡ ứng dụng trên Android
/// và xoá dữ liệu trang trên trình duyệt là hai thao tác khác nhau nhưng cùng
/// một hệ quả, và đó là lý do bản sao lưu đã mã hoá ở UC-13 là đường lùi duy
/// nhất trên cả hai nền tảng.
///
/// Cần chạy `dart run sqflite_common_ffi_web:setup` một lần để đặt `sqlite3.wasm`
/// và web worker vào thư mục `web/`; thiếu bước đó thì bản build Web mở cơ sở dữ
/// liệu sẽ thất bại lúc chạy.
DatabaseFactory createPlatformDatabaseFactory() => databaseFactoryFfiWeb;

/// Trên Web không có hệ thống file để đặt đường dẫn: tên là **khoá** của cơ sở
/// dữ liệu trong kho lưu trữ của trình duyệt, nên trả về nguyên tên file.
Future<String> resolvePlatformDatabasePath(String fileName) async => fileName;
