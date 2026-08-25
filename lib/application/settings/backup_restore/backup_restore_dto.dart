import 'dart:typed_data';

import '../contracts/app_data_store.dart';

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

/// Một lần khôi phục **đã kiểm tra xong nhưng chưa ghi gì** (UC-13 bước 3).
///
/// Tồn tại vì UC-13 tách bạch hai việc mà phản xạ tự nhiên hay gộp làm một: giải
/// mã và kiểm toàn vẹn (bước 3) diễn ra **trước**, rồi mới tới cảnh báo "toàn bộ
/// dữ liệu hiện có sẽ bị thay thế" và chờ người dùng xác nhận (bước 4). Gộp lại
/// thì hộp thoại cảnh báo hoặc phải hiện lên trước khi biết file có đọc được hay
/// không — cảnh báo hão về một thao tác sắp thất bại — hoặc phải hiện lên sau
/// khi dữ liệu đã bị ghi đè, lúc đã quá muộn để hỏi.
///
/// Giữ bytes đã giải mã trong bộ nhớ giữa hai bước là chấp nhận được: dữ liệu
/// nằm cục bộ, không rời khỏi thiết bị, và người dùng vừa tự tay cung cấp mật
/// khẩu của chính nó.
final class RestorePlan {
  const RestorePlan({required this.manifest, required this.plain});

  /// Bản sao lưu này chứa gì — nội dung cho hộp thoại cảnh báo.
  final BackupManifest manifest;

  /// Khối dữ liệu đã giải mã và đã kiểm. Chỉ use case khôi phục cần tới nó; giao
  /// diện chỉ đọc [manifest].
  final Uint8List plain;
}
