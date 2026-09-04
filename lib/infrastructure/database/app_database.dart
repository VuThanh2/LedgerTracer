import 'package:sqflite_common/sqlite_api.dart';

import '../../core/persistence/unit_of_work.dart';
import 'database_factory_provider.dart';
import 'schema.dart';

/// Cơ sở dữ liệu SQLite cục bộ, và đồng thời là hiện thực của [UnitOfWork].
///
/// ## Vì sao hai vai trò nằm chung một object
///
/// `UnitOfWork` yêu cầu các repository lấy từ DI container **tham gia được vào
/// ranh giới đang mở**. Với sqflite điều đó không phải chuyện tuỳ chọn: trong
/// thân một `Database.transaction`, mọi câu lệnh phải đi qua đối tượng
/// [Transaction] được trao cho callback — gọi thẳng lên `Database` sẽ nằm ngoài
/// transaction đó và, tệ hơn, chờ chính transaction đang giữ khoá.
///
/// Cách duy nhất để repository không phải nhận thêm một tham số "executor" ở mọi
/// phương thức là để **một nơi** biết ranh giới nào đang mở. Nơi đó là đây:
/// repository luôn đọc [executor], và [executor] trả về transaction hiện hành
/// nếu có, còn không thì trả về chính cơ sở dữ liệu.
///
/// Lời gọi lồng nhau được coi là một phần của ranh giới ngoài, đúng như hợp đồng
/// của [UnitOfWork]: hoàn tác cả một lượt nhập là lần lượt hoàn tác từng bản ghi
/// con, và mỗi bước đó tự nó cũng là một thao tác nguyên tử (UC-03).
final class AppDatabase implements UnitOfWork {
  AppDatabase._(this._database);

  /// Tên file mặc định; trên Web đây là khoá của cơ sở dữ liệu trong kho lưu trữ
  /// của trình duyệt chứ không phải đường dẫn.
  static const String defaultFileName = 'ledger_tracer.db';

  /// Mở cơ sở dữ liệu, dựng lược đồ nếu đây là lần chạy đầu.
  ///
  /// [factory] và [path] tồn tại để test mở được một cơ sở dữ liệu trong bộ nhớ;
  /// đường đi bình thường của ứng dụng là gọi không tham số.
  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final resolvedFactory = factory ?? PlatformDatabase.factory;
    final resolvedPath = path ?? await PlatformDatabase.pathFor(defaultFileName);
    final database = await resolvedFactory.openDatabase(
      resolvedPath,
      options: OpenDatabaseOptions(
        version: LedgerSchema.version,
        onConfigure: _configure,
        onCreate: _create,
        onUpgrade: _upgrade,
      ),
    );
    return AppDatabase._(database);
  }

  final Database _database;

  Transaction? _openTransaction;

  /// Nơi mọi repository gửi câu lệnh tới. Đọc lại ở **mỗi** lần dùng, không giữ
  /// lại trong một trường: giá trị của nó đổi theo việc có ranh giới nào đang mở
  /// hay không.
  DatabaseExecutor get executor => _openTransaction ?? _database;

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    // Ranh giới lồng nhau chạy thẳng trong ranh giới ngoài. Mở transaction thứ
    // hai ở đây sẽ khoá chính mình, và về nghiệp vụ cũng sai: "được ăn cả, ngã
    // về không" phải tính trên toàn bộ chuỗi, không phải trên từng mắt xích.
    if (_openTransaction != null) return action();
    return _database.transaction<T>((txn) async {
      _openTransaction = txn;
      try {
        return await action();
      } finally {
        // Trả executor về cơ sở dữ liệu **trước khi** lỗi lan tiếp: sqflite quay
        // lui phần đã ghi, còn việc quên dọn trường này sẽ khiến mọi câu lệnh
        // sau đó gửi vào một transaction đã chết.
        _openTransaction = null;
      }
    });
  }

  Future<void> close() => _database.close();

  static Future<void> _configure(Database db) async {
    // Khoá ngoại phải bật tường minh: SQLite mặc định tắt, và tắt thì lược đồ
    // mất luôn lưới an toàn cho các chuỗi xoá dây chuyền ở UC-01/UC-03.
    await db.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> _create(Database db, int version) async {
    final batch = db.batch();
    for (final statement in LedgerSchema.createStatements) {
      batch.execute(statement);
    }
    await batch.commit(noResult: true);
  }

  static Future<void> _upgrade(Database db, int from, int to) async {
    final statements = LedgerSchema.migrate(fromVersion: from, toVersion: to);
    for (final statement in statements) {
      await db.execute(statement);
    }
  }
}
