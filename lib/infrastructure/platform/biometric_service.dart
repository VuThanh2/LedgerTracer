import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

import '../../application/settings/app_lock/app_lock_use_case.dart';

/// Hiện thực [BiometricAuthenticator] bằng cảm biến sinh trắc học của thiết bị
/// (UC-12).
///
/// Sinh trắc học là **lớp mở khoá nhanh đặt lên trên mã PIN**, không phải lựa
/// chọn thay thế: cảm biến hỏng thì người dùng vẫn còn PIN, và cùng dữ liệu đó
/// trên Web thì chỉ PIN mới mở được. Vì vậy mọi đường thất bại ở đây đều trả về
/// `false` chứ không ném — không mở được bằng vân tay là một câu trả lời, không
/// phải một sự cố, và ứng dụng luôn còn đúng một đường vào khác.
///
/// Trên Web, [isAvailable] trả `false` ngay lập tức để giao diện **ẩn hẳn** tuỳ
/// chọn thay vì hiện ra rồi báo lỗi sau khi người dùng đã bấm.
final class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      // Hai câu hỏi khác nhau và cần cả hai: thiết bị có cơ chế khoá nào không,
      // và có cảm biến sinh trắc học đã đăng ký không.
      return await _localAuth.isDeviceSupported() &&
          await _localAuth.canCheckBiometrics;
    } on LocalAuthException {
      return false;
    } on MissingPluginException {
      // Nền tảng không có hiện thực cho plugin này (Web, hoặc một nền tảng
      // desktop chưa được cấu hình). Đúng nghĩa "không khả dụng".
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> authenticate() async {
    if (kIsWeb) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Xác thực để mở khoá LedgerTracer',
        // Chỉ nhận sinh trắc học: mã PIN của thiết bị là một bí mật khác với mã
        // PIN của ứng dụng, và để hệ điều hành nhận mã khoá màn hình ở đây sẽ
        // biến lớp khoá riêng của ứng dụng thành lớp khoá của thiết bị.
        biometricOnly: true,
        // Người dùng chuyển ra ngoài rồi quay lại giữa lúc xác thực thì tiếp
        // tục, thay vì thất bại — đúng thao tác hay xảy ra trên điện thoại.
        persistAcrossBackgrounding: true,
      );
    } on LocalAuthException {
      return false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }
}
