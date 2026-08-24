import 'dart:typed_data';

/// Mã hoá và giải mã file sao lưu (UC-13).
///
/// File sao lưu chứa **toàn bộ** dữ liệu và chỉ để chính ứng dụng đọc lại, nên nó
/// **phải** được mã hoá — khác hẳn file xuất báo cáo ở UC-11. Khoá dẫn xuất từ
/// mật khẩu do người dùng đặt, **độc lập hoàn toàn với mã PIN khoá ứng dụng**:
/// lối thoát khi quên PIN là reset rồi khôi phục từ sao lưu, nên nếu sao lưu mã
/// hoá bằng chính PIN đã quên thì hai use case triệt tiêu nhau.
abstract interface class BackupCodec {
  Future<Uint8List> encrypt(Uint8List plain, String password);

  /// Ném [BackupPasswordException] khi sai mật khẩu hoặc file không qua được kiểm
  /// tra toàn vẹn — trước khi bất kỳ dữ liệu hiện có nào bị đụng tới.
  Future<Uint8List> decrypt(Uint8List cipher, String password);
}

/// Sai mật khẩu sao lưu, hoặc file sao lưu hỏng. Không bao giờ mang theo chính
/// mật khẩu mà nó nói tới.
final class BackupPasswordException implements Exception {
  const BackupPasswordException([
    this.message = 'Sai mật khẩu hoặc file sao lưu đã hỏng.',
  ]);

  final String message;

  @override
  String toString() => 'BackupPasswordException: $message';
}

/// Chụp toàn bộ dữ liệu ra một payload thuần và ghi đè lại từ payload đó.
///
/// Việc gói/mở gói toàn bộ cơ sở dữ liệu là của Infrastructure — nó có quyền
/// chạm tới mọi bảng; use case chỉ điều phối chụp → mã hoá → lưu, và ngược lại.
/// Khôi phục chỉ hỗ trợ **ghi đè toàn bộ**, không hợp nhất: cả ba tình huống thực
/// tế (cài lại, mất thiết bị, reset do quên PIN) đều diễn ra trên ứng dụng trống.
abstract interface class BackupStore {
  Future<Uint8List> snapshot();

  Future<void> replaceAll(Uint8List plain);
}

/// Nơi file sao lưu đã được lưu tới.
final class BackupLocation {
  const BackupLocation({this.path, required this.viaBrowserDownload});

  /// Đường dẫn trên thiết bị (Android); `null` trên Web (UC-13).
  final String? path;

  final bool viaBrowserDownload;
}

/// Ghi bytes sao lưu ra nơi người dùng chọn (Android) hoặc qua tải xuống của
/// trình duyệt (Web).
abstract interface class BackupWriter {
  Future<BackupLocation> write(
    Uint8List bytes, {
    required String suggestedName,
  });
}

/// Yêu cầu sao lưu: một mật khẩu cho riêng file này. Mất mật khẩu thì không có
/// đường khôi phục file đó — cảnh báo này thuộc về giao diện ở bước đặt mật khẩu.
final class BackupRequest {
  const BackupRequest({required this.password});

  final String password;
}

final class BackupResult {
  const BackupResult({required this.location});

  final BackupLocation location;
}

/// Yêu cầu khôi phục: bytes file người dùng đã chọn và mật khẩu của nó.
final class RestoreRequest {
  const RestoreRequest({required this.bytes, required this.password});

  final Uint8List bytes;
  final String password;
}
