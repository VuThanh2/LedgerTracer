/// Những gì xảy ra ở màn hình khoá, thứ chặn toàn bộ ứng dụng khi App Lock bật
/// (UC-12).
sealed class AppLockEvent {
  const AppLockEvent();
}

/// Hỏi xem có phải khoá không, ngay khi ứng dụng khởi động.
final class AppLockChecked extends AppLockEvent {
  const AppLockChecked();
}

/// Nhập mã PIN để vào.
final class AppLockPinSubmitted extends AppLockEvent {
  const AppLockPinSubmitted(this.pin);

  final String pin;
}

/// Bấm nút mở khoá bằng sinh trắc học. Chỉ có trên native, và chỉ khi người dùng
/// đã bật nó trong Thiết lập.
final class AppLockBiometricRequested extends AppLockEvent {
  const AppLockBiometricRequested();
}

/// Bấm "Quên PIN?".
///
/// Không có cơ chế bỏ qua mã PIN nào, vì một cơ chế như thế vô hiệu hoá chính
/// lớp bảo vệ mà mã PIN dựng lên. Lối thoát duy nhất là **xoá sạch dữ liệu cục
/// bộ** rồi lấy lại từ bản sao lưu đã mã hoá — và điều đó chỉ đi được vì mật
/// khẩu sao lưu độc lập hoàn toàn với mã PIN (UC-12, UC-13).
final class AppLockResetRequested extends AppLockEvent {
  const AppLockResetRequested();
}

final class AppLockResetDismissed extends AppLockEvent {
  const AppLockResetDismissed();
}

/// Gõ chuỗi xác nhận trong hộp thoại xoá dữ liệu.
///
/// Một chuỗi phải gõ tay chứ không phải một nút "Đồng ý": đây là thao tác phá
/// huỷ không quay lui được và nó nằm ngay trên màn hình một người đang bối rối
/// vì không vào được ứng dụng của mình.
final class AppLockResetConfirmationTyped extends AppLockEvent {
  const AppLockResetConfirmationTyped(this.text);

  final String text;
}

final class AppLockResetConfirmed extends AppLockEvent {
  const AppLockResetConfirmed();
}
