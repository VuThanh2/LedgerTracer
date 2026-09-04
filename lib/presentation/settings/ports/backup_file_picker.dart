import '../../../application/import/prepare_import/prepare_import_dto.dart';

/// Mở hộp thoại chọn file sao lưu để khôi phục (UC-13 bước 2).
///
/// Cùng lý do tồn tại với `StatementFilePicker`: chọn file là thao tác do người
/// dùng khởi xướng trên giao diện, nên tầng Application không có cổng cho nó —
/// nhưng một BLoC vẫn không được gọi thẳng xuống Infrastructure. Cổng nằm ở tầng
/// cần nó; composition root nối nó với hiện thực thật.
///
/// Tách riêng khỏi cổng chọn file sao kê dù hiện thực bên dưới là **cùng một
/// lớp**: hai màn hình khác nhau cần hai thao tác khác nhau, và gộp lại sẽ buộc
/// mọi bản giả trong test của màn hình này phải cài đặt cả phương thức nó không
/// bao giờ gọi.
abstract interface class BackupFilePicker {
  /// Trả `null` khi người dùng huỷ.
  Future<PickedFile?> pickBackup();
}
