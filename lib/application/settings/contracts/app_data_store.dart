import 'dart:typed_data';

/// Thông tin đọc được từ một file sao lưu **đã giải mã**, để hộp thoại cảnh báo
/// nói được cụ thể sẽ thay thế dữ liệu hiện có bằng cái gì (UC-13 bước 3–4).
final class BackupManifest {
  const BackupManifest({
    required this.createdAt,
    required this.accountCount,
    required this.transactionCount,
  });

  /// Thời điểm bản sao lưu được tạo.
  final DateTime createdAt;

  final int accountCount;

  final int transactionCount;
}

/// File sao lưu giải mã được nhưng nội dung bên trong không phải một bản sao lưu
/// hợp lệ (sai định dạng, thiếu phần, hỏng giữa chừng).
///
/// Tách khỏi `BackupPasswordException` vì hai thứ khác hẳn nhau về nguyên nhân
/// lẫn về việc người dùng làm gì tiếp: sai mật khẩu thì gõ lại, còn file hỏng
/// thì phải tìm bản sao lưu khác.
final class CorruptBackupException implements Exception {
  const CorruptBackupException([
    this.message = 'File sao lưu không đúng định dạng hoặc đã hỏng.',
  ]);

  final String message;

  @override
  String toString() => 'CorruptBackupException: $message';
}

/// Toàn bộ dữ liệu cục bộ, nhìn như một khối duy nhất.
///
/// Ba use case dùng chung nó và đó là lý do nó không mang tên "BackupStore": sao
/// lưu đọc khối ấy ra, khôi phục ghi khối ấy vào, và **reset ứng dụng** xoá sạch
/// nó. Cả ba nói về cùng một thứ, nên tách thành ba cổng riêng chỉ tạo ra ba
/// đường vào cùng một cơ sở dữ liệu mà không ai thấy được chúng liên quan tới
/// nhau.
///
/// Định dạng của khối bytes là chuyện riêng của Infrastructure; tầng Application
/// chỉ chuyển nó qua lại giữa cơ sở dữ liệu và bộ mã hoá.
abstract interface class AppDataStore {
  /// Đọc toàn bộ dữ liệu ra một khối chưa mã hoá.
  Future<Uint8List> snapshot();

  /// Đọc thông tin mô tả từ một khối đã giải mã, **không** đụng tới dữ liệu hiện
  /// có. Ném [CorruptBackupException] nếu khối không phải bản sao lưu hợp lệ.
  Future<BackupManifest> inspect(Uint8List plain);

  /// Thay thế **toàn bộ** dữ liệu hiện có bằng khối này.
  ///
  /// Chỉ hỗ trợ ghi đè toàn bộ, không hợp nhất: cả ba tình huống khôi phục thực
  /// tế (cài lại ứng dụng, mất thiết bị, reset do quên PIN) đều diễn ra trên một
  /// ứng dụng trống, nơi ghi đè và hợp nhất cho cùng kết quả (UC-13).
  Future<void> replaceAll(Uint8List plain);

  /// Xoá sạch dữ liệu cục bộ, **bao gồm cả thiết lập và mã PIN**.
  ///
  /// Phần "bao gồm cả mã PIN" là toàn bộ lý do phương thức này tồn tại: reset là
  /// lối thoát **duy nhất** khi người dùng quên PIN (UC-12). Nếu nó chừa thiết
  /// lập lại thì ứng dụng sau khi reset vẫn khoá bằng đúng mã PIN đã quên, và
  /// use case triệt tiêu chính nó.
  Future<void> wipe();
}
