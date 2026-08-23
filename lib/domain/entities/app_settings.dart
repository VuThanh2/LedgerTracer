import '../errors/settings_errors.dart';
import '../value_objects/match_window.dart';

/// Bản ghi thiết lập đơn nhất của ứng dụng (UC-08, UC-12).
///
/// Khoá ứng dụng là lớp chặn truy cập thiết bị, không phải tài khoản người dùng:
/// ứng dụng không có máy chủ và không có danh tính từ xa nào cả.
final class AppSettings {
  const AppSettings._({
    required this.appLockEnabled,
    required this.pinHash,
    required this.biometricEnabled,
    required this.matchWindow,
  });

  /// Dựng lại bản ghi từ nơi lưu trữ, kiểm lại các bất biến mà khoá ứng dụng
  /// dựa vào. Ném [PinRequiredError] nếu bật khoá mà không có PIN.
  factory AppSettings({
    required bool appLockEnabled,
    String? pinHash,
    bool biometricEnabled = false,
    MatchWindow matchWindow = MatchWindow.standard,
  }) {
    if (appLockEnabled && pinHash == null) throw const PinRequiredError();
    return AppSettings._(
      appLockEnabled: appLockEnabled,
      // Giữ hash PIN khi khoá đang tắt là để lại một bí mật thừa, còn sinh trắc
      // học mà không có khoá thì chẳng mở cái gì.
      pinHash: appLockEnabled ? pinHash : null,
      biometricEnabled: appLockEnabled && biometricEnabled,
      matchWindow: matchWindow,
    );
  }

  /// Trạng thái của bản cài mới: chưa khoá, cửa sổ ghép cặp mặc định (UC-12 quy
  /// định khoá mặc định tắt).
  static const AppSettings initial = AppSettings._(
    appLockEnabled: false,
    pinHash: null,
    biometricEnabled: false,
    matchWindow: MatchWindow.standard,
  );

  final bool appLockEnabled;

  /// Chỉ bao giờ là mã băm — PIN dạng thuần không bao giờ được lưu (UC-12).
  /// Việc băm là chuyện của Infrastructure; Domain chỉ đảm bảo PIN thô không có
  /// chỗ nào để tồn tại ở đây.
  final String? pinHash;

  /// Chỉ có ý nghĩa trên native; trên Web tuỳ chọn này không được hiện ra.
  final bool biometricEnabled;

  /// Ngưỡng lệch dùng cho lần quét đối soát kế tiếp (UC-08).
  final MatchWindow matchWindow;

  /// Bật khoá. PIN là bắt buộc: sinh trắc học là lớp mở nhanh đặt trên nó chứ
  /// không thay thế (UC-12).
  AppSettings enableLock({required String pinHash}) => AppSettings(
    appLockEnabled: true,
    pinHash: pinHash,
    biometricEnabled: biometricEnabled,
    matchWindow: matchWindow,
  );

  /// Tắt khoá và bỏ luôn hash đã lưu. Việc kiểm PIN hiện tại trước khi gọi hàm
  /// này là của tầng Application — chỉ nó mới so được PIN người dùng gõ với
  /// [pinHash].
  AppSettings disableLock() =>
      AppSettings(appLockEnabled: false, matchWindow: matchWindow);

  /// Ném [AppLockDisabledError] khi khoá đang tắt — lúc đó không có PIN nào để
  /// đổi.
  AppSettings changePin(String newPinHash) {
    if (!appLockEnabled) throw const AppLockDisabledError();
    return AppSettings(
      appLockEnabled: true,
      pinHash: newPinHash,
      biometricEnabled: biometricEnabled,
      matchWindow: matchWindow,
    );
  }

  /// Ném [AppLockDisabledError] khi bật sinh trắc học lúc khoá đang tắt.
  AppSettings withBiometric(bool enabled) {
    if (enabled && !appLockEnabled) throw const AppLockDisabledError();
    return AppSettings(
      appLockEnabled: appLockEnabled,
      pinHash: pinHash,
      biometricEnabled: enabled,
      matchWindow: matchWindow,
    );
  }

  AppSettings withMatchWindow(MatchWindow window) => AppSettings(
    appLockEnabled: appLockEnabled,
    pinHash: pinHash,
    biometricEnabled: biometricEnabled,
    matchWindow: window,
  );

  /// Bản ghi đơn nhất: hai giá trị thiết lập bằng nhau khi chúng nói cùng một
  /// điều.
  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.appLockEnabled == appLockEnabled &&
      other.pinHash == pinHash &&
      other.biometricEnabled == biometricEnabled &&
      other.matchWindow == matchWindow;

  @override
  int get hashCode =>
      Object.hash(appLockEnabled, pinHash, biometricEnabled, matchWindow);

  @override
  String toString() =>
      'AppSettings(lock: $appLockEnabled, '
      'biometric: $biometricEnabled, window: $matchWindow)';
}
