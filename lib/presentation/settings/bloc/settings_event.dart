/// Những gì xảy ra trên màn hình Thiết lập (UC-12).
///
/// Màn hình này **cấu hình** lớp khoá; việc *vượt qua* lớp khoá lúc mở ứng dụng
/// là chuyện của `AppLockBloc`. Hai việc dùng chung một use case nhưng sống ở
/// hai vòng đời khác hẳn nhau, nên chúng là hai BLoC.
sealed class SettingsEvent {
  const SettingsEvent();
}

final class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

/// Bật khoá ứng dụng lần đầu và đặt mã PIN (UC-12 bước 1–2).
final class SettingsLockEnabled extends SettingsEvent {
  const SettingsLockEnabled({required this.pin, required this.confirmPin});

  final String pin;

  /// Ô nhập lại. Đặt một mã PIN gõ nhầm nghĩa là khoá mình ra khỏi dữ liệu của
  /// chính mình, và đường ra duy nhất là xoá sạch — nên phép so hai ô là bắt
  /// buộc, không phải một tiện ích.
  final String confirmPin;
}

/// Tắt khoá ứng dụng. **Bắt buộc** nhập đúng PIN hiện tại: không có bước đó thì
/// người đang cầm một thiết bị đã mở sẽ vô hiệu hoá được lớp bảo vệ.
final class SettingsLockDisabled extends SettingsEvent {
  const SettingsLockDisabled(this.currentPin);

  final String currentPin;
}

/// Đổi mã PIN; cũng bắt buộc nhập đúng PIN hiện tại.
final class SettingsPinChanged extends SettingsEvent {
  const SettingsPinChanged({
    required this.currentPin,
    required this.newPin,
    required this.confirmPin,
  });

  final String currentPin;
  final String newPin;
  final String confirmPin;
}

/// Bật/tắt mở khoá bằng sinh trắc học.
///
/// Là lớp mở nhanh đặt **trên** mã PIN chứ không thay thế nó: cảm biến hỏng
/// không được khoá người dùng ra ngoài. Chỉ có trên native; trên Web tuỳ chọn
/// này bị ẩn hẳn thay vì hiện ra rồi báo lỗi sau khi bấm (UC-12).
final class SettingsBiometricToggled extends SettingsEvent {
  const SettingsBiometricToggled(this.enabled);

  final bool enabled;
}

/// Chạm vào mục ẩn ở cuối màn hình.
///
/// Màn hình chẩn đoán nằm ngoài Domain và không phục vụ người dùng cuối; nó tồn
/// tại để đo đánh đổi concurrency cho phần thực nghiệm. Giấu sau một chuỗi chạm
/// giữ nó ra khỏi luồng bình thường mà vẫn tới được trên đúng thiết bị cần đo.
final class SettingsHiddenEntryTapped extends SettingsEvent {
  const SettingsHiddenEntryTapped();
}
