import '../entities/app_settings.dart';

/// Cổng lưu trữ của bản ghi thiết lập đơn nhất (UC-08, UC-12).
abstract interface class AppSettingsRepository {
  /// Thiết lập đã lưu, hoặc thiết lập ban đầu nếu là bản cài mới.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}
