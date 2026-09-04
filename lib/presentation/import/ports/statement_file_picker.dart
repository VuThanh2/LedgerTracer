import '../../../application/import/prepare_import/prepare_import_dto.dart';

/// Mở hộp thoại chọn file sao kê của nền tảng (UC-02 bước 1).
///
/// ## Vì sao cổng này nằm ở tầng Presentation
///
/// Tầng Application cố ý **không** có cổng nào cho việc chọn file, và ghi rõ lý
/// do: chọn file là một thao tác do người dùng khởi xướng ngay trên giao diện,
/// không phải một phụ thuộc mà use case cần để chạy. `ImportStatementsUseCase`
/// nhận bytes đã có sẵn; ai lấy được bytes đó là chuyện của màn hình.
///
/// Nhưng "chuyện của màn hình" không có nghĩa là màn hình được gọi thẳng xuống
/// `FilePickerService` của tầng Infrastructure — chiều phụ thuộc chỉ đi vào
/// trong, và một BLoC biết tên một lớp Infrastructure là một BLoC không test
/// được nếu không có `file_picker` thật. Cổng này vì thế được khai báo ở đúng
/// nơi cần nó, và composition root nối nó với hiện thực thật. Đó chính là
/// Dependency Inversion: người dùng interface sở hữu interface.
///
/// Cố ý chỉ có **một** phương thức: khôi phục sao lưu cũng chọn file, nhưng đó
/// là một nhu cầu khác của một màn hình khác, và gộp hai thứ vào một cổng buộc
/// mọi bản giả trong test phải cài đặt cả phương thức nó không dùng.
abstract interface class StatementFilePicker {
  /// Trả về danh sách rỗng khi người dùng đóng hộp thoại mà không chọn gì —
  /// không phải một lỗi, chỉ là không có gì để làm tiếp.
  Future<List<PickedFile>> pickStatements();
}
