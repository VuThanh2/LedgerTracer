import 'package:sqflite_common/sqlite_api.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/value_objects/match_window.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../database/sql_codec.dart';

/// Hiện thực SQLite của [AppSettingsRepository] (UC-08, UC-12).
///
/// Bản ghi đơn nhất được canh bằng chính lược đồ: khoá chính có `CHECK
/// (settings_id = 1)`, nên "đơn nhất" là một ràng buộc chứ không phải một thoả
/// thuận ngầm giữa các nơi gọi.
final class SqliteAppSettingsRepository implements AppSettingsRepository {
  const SqliteAppSettingsRepository(this._db);

  /// Khoá của dòng duy nhất.
  static const int _singletonId = 1;

  final AppDatabase _db;

  /// Bản cài mới chưa có dòng nào, và đó là chuyện bình thường: [AppSettings]
  /// đã có sẵn trạng thái ban đầu, nên không cần một bước "khởi tạo thiết lập"
  /// mà mọi đường vào đều phải nhớ gọi.
  @override
  Future<AppSettings> load() async {
    final rows = await _db.executor.query(
      LedgerSchema.appSettings,
      where: 'settings_id = ?',
      whereArgs: <Object?>[_singletonId],
      limit: 1,
    );
    if (rows.isEmpty) return AppSettings.initial;
    final row = rows.first;
    return AppSettings(
      appLockEnabled: SqlCodec.parseBoolean(row['app_lock_enabled']),
      pinHash: row['pin_hash'] as String?,
      biometricEnabled: SqlCodec.parseBoolean(row['biometric_enabled']),
      matchWindow: MatchWindow(row['match_window_days'] as int),
    );
  }

  @override
  Future<void> save(AppSettings settings) async {
    await _db.executor.insert(
      LedgerSchema.appSettings,
      <String, Object?>{
        'settings_id': _singletonId,
        'app_lock_enabled': SqlCodec.boolean(settings.appLockEnabled),
        // Entity đã bỏ hash khi khoá tắt; ghi thẳng thứ nó mang giữ cho cơ sở dữ
        // liệu không bao giờ giữ lại một bí mật thừa (UC-12).
        'pin_hash': settings.pinHash,
        'biometric_enabled': SqlCodec.boolean(settings.biometricEnabled),
        'match_window_days': settings.matchWindow.days,
      },
      // Ghi đè cả dòng thay vì phân nhánh "đã có chưa": bản ghi đơn nhất không
      // có lịch sử để giữ, và hai đường ghi khác nhau là hai chỗ để lệch nhau.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
