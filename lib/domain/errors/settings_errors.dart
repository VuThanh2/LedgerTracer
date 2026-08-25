import 'domain_error.dart';

/// Vi phạm của aggregate AppSettings (UC-12).
sealed class SettingsError extends DomainError {
  const SettingsError(super.message);
}

/// Sinh trắc học là lớp mở khoá nhanh đặt **trên** mã PIN chứ không thay thế
/// nó: cảm biến hỏng không được phép khoá người dùng ra ngoài, và cùng dữ liệu
/// đó trên Web thì chỉ có PIN mới mở được (UC-12).
final class PinRequiredError extends SettingsError {
  const PinRequiredError() : super('App lock cannot be enabled without a PIN.');
}

/// Đổi PIN hay bật sinh trắc học chỉ có nghĩa khi khoá ứng dụng đang bật.
/// Bật khoá khi khoá đang bật đồng nghĩa với đặt lại mã PIN mà không cần biết
/// PIN hiện tại — đúng thứ UC-12 cấm. Đường hợp lệ để đổi PIN là
/// `changePin`, vốn bắt buộc xác thực PIN cũ.
final class AppLockAlreadyEnabledError extends SettingsError {
  const AppLockAlreadyEnabledError()
    : super('App lock is already enabled; change the PIN instead.');
}

final class AppLockDisabledError extends SettingsError {
  const AppLockDisabledError()
    : super('App lock is disabled; enable it before changing its options.');
}

/// Tắt khoá và đổi PIN đều phải nhập đúng PIN hiện tại, nếu không người đang cầm
/// máy đã mở sẽ vô hiệu hoá được lớp bảo vệ.
final class IncorrectPinError extends SettingsError {
  const IncorrectPinError() : super('The PIN entered is not correct.');
}

/// Chỉ có trên native; trên Web thì tuỳ chọn này thậm chí không được hiện ra.
final class BiometricUnavailableError extends SettingsError {
  const BiometricUnavailableError()
    : super('Biometric unlock is not available on this platform.');
}
