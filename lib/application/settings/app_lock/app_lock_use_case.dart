import '../../../core/result/result.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/errors/settings_errors.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../shared/domain_failures.dart';

/// Băm và kiểm PIN. Việc băm là chuyện của Infrastructure; Domain chỉ đảm bảo PIN
/// thô không có chỗ nào để tồn tại (UC-12).
abstract interface class PinHasher {
  String hash(String pin);

  bool verify(String pin, String hash);
}

/// Mở khoá bằng sinh trắc học — chỉ có trên native (UC-12).
abstract interface class BiometricAuthenticator {
  Future<bool> isAvailable();

  /// Trả `true` nếu người dùng vượt qua xác thực sinh trắc học.
  Future<bool> authenticate();
}

/// Trạng thái khoá dành cho màn hình Thiết lập — cố ý **không** mang `pinHash`:
/// bí mật không đi ra khỏi tầng dưới.
final class AppLockStatus {
  const AppLockStatus({
    required this.appLockEnabled,
    required this.biometricEnabled,
    required this.biometricAvailable,
  });

  final bool appLockEnabled;
  final bool biometricEnabled;

  /// Nền tảng có hỗ trợ sinh trắc học không — giao diện ẩn tuỳ chọn nếu không.
  final bool biometricAvailable;
}

/// Bật/tắt khoá ứng dụng, đổi PIN, bật/tắt sinh trắc học, và xác thực lúc mở
/// (UC-12).
///
/// Khoá ứng dụng là lớp chặn truy cập thiết bị, **không** phải tài khoản người
/// dùng đám mây. PIN là bắt buộc khi bật khoá; sinh trắc học là lớp mở nhanh đặt
/// **trên** nó chứ không thay thế — cảm biến hỏng không được khoá người dùng ra
/// ngoài. Đổi PIN và tắt khoá đều bắt buộc nhập đúng PIN hiện tại, nếu không
/// người đang cầm máy đã mở sẽ vô hiệu hoá được lớp bảo vệ.
final class AppLockUseCase {
  AppLockUseCase({
    required this._settings,
    required this._hasher,
    required this._biometric,
  });

  final AppSettingsRepository _settings;
  final PinHasher _hasher;
  final BiometricAuthenticator _biometric;

  Future<Result<AppLockStatus>> status() => Result.guardAsync(() async {
    final settings = await _settings.load();
    return AppLockStatus(
      appLockEnabled: settings.appLockEnabled,
      biometricEnabled: settings.biometricEnabled,
      biometricAvailable: await _biometric.isAvailable(),
    );
  }, onError: failureFromError);

  /// Bật khoá và đặt PIN (UC-12 bước 2).
  /// Bật khoá lần đầu và đặt mã PIN (UC-12 bước 1–2).
  ///
  /// Từ chối khi khoá **đang bật**: bật lại một thứ đã bật chỉ có nghĩa là ghi đè
  /// mã PIN, và làm việc đó mà không hỏi PIN hiện tại thì người đang cầm thiết bị
  /// mở sẵn vô hiệu hoá được cả lớp bảo vệ. Đổi PIN là [changePin], và nó bắt
  /// buộc xác thực PIN cũ.
  Future<Result<void>> enableLock(String pin) =>
      Result.guardAsync(() async {
        final settings = await _settings.load();
        if (settings.appLockEnabled) throw const AppLockAlreadyEnabledError();
        await _settings.save(settings.enableLock(pinHash: _hasher.hash(pin)));
      }, onError: failureFromError);

  /// Tắt khoá; phải nhập đúng PIN hiện tại trước.
  Future<Result<void>> disableLock(String currentPin) =>
      _updateVerified(currentPin, (settings) => settings.disableLock());

  /// Đổi PIN; phải nhập đúng PIN hiện tại trước.
  Future<Result<void>> changePin({
    required String currentPin,
    required String newPin,
  }) => _updateVerified(
    currentPin,
    (settings) => settings.changePin(_hasher.hash(newPin)),
  );

  /// Bật/tắt sinh trắc học. Bật đòi nền tảng có hỗ trợ (ném
  /// [BiometricUnavailableError]) và khoá đang bật (Domain ném
  /// [AppLockDisabledError]).
  Future<Result<void>> setBiometric(bool enabled) =>
      Result.guardAsync(() async {
        if (enabled && !await _biometric.isAvailable()) {
          throw const BiometricUnavailableError();
        }
        final settings = await _settings.load();
        await _settings.save(settings.withBiometric(enabled));
      }, onError: failureFromError);

  /// Xác thực bằng PIN lúc mở ứng dụng. Khoá đang tắt thì mở được ngay.
  Future<Result<bool>> unlockWithPin(String pin) =>
      Result.guardAsync(() async {
        final settings = await _settings.load();
        if (!settings.appLockEnabled) return true;
        return _hasher.verify(pin, settings.pinHash!);
      }, onError: failureFromError);

  /// Xác thực bằng sinh trắc học lúc mở ứng dụng (native). Trả
  /// [BiometricUnavailableError] khi không khả dụng thay vì âm thầm thất bại.
  Future<Result<bool>> unlockWithBiometric() =>
      Result.guardAsync(() async {
        final settings = await _settings.load();
        if (!settings.appLockEnabled || !settings.biometricEnabled) {
          throw const BiometricUnavailableError();
        }
        if (!await _biometric.isAvailable()) {
          throw const BiometricUnavailableError();
        }
        return _biometric.authenticate();
      }, onError: failureFromError);

  Future<Result<void>> _updateVerified(
    String currentPin,
    AppSettings Function(AppSettings settings) change,
  ) => Result.guardAsync(() async {
    final settings = await _settings.load();
    _verifyPin(settings, currentPin);
    await _settings.save(change(settings));
  }, onError: failureFromError);

  void _verifyPin(AppSettings settings, String pin) {
    final hash = settings.pinHash;
    // Không có PIN để so nghĩa là khoá đang tắt — không có gì để xác thực.
    if (hash == null) throw const AppLockDisabledError();
    if (!_hasher.verify(pin, hash)) throw const IncorrectPinError();
  }
}
