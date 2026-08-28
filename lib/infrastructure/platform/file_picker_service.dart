import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../application/import/prepare_import/prepare_import_dto.dart';

/// Chọn file từ thiết bị (UC-02 bước 1, UC-13 bước 2).
///
/// Trả về [PickedFile] — kiểu của tầng Application — chứ không phải kiểu của thư
/// viện chọn file: `PlatformFile` mang theo cả đường dẫn, luồng đọc và chi tiết
/// nền tảng, và để nó đi lên trên là để một thư viện Infrastructure quyết định
/// hình dạng của các tầng trong.
///
/// Không có cổng trừu tượng nào cho việc này ở tầng Application, và đó là có lý
/// do: chọn file là một thao tác **do người dùng khởi xướng ngay trên giao
/// diện**, không phải một phụ thuộc mà use case cần để chạy. Use case nhập sao
/// kê nhận vào bytes đã có sẵn; ai lấy được bytes đó là chuyện của màn hình.
final class FilePickerService {
  const FilePickerService();

  /// Chọn một hoặc nhiều file sao kê để nhập trong cùng một lượt (FR-09).
  ///
  /// Cố ý **không** lọc theo phần mở rộng. Người dùng chỉ chọn file mình đang có
  /// sẵn; việc biết đó là CSV, Excel, MT940 hay JSON là việc của ứng dụng
  /// (UC-02 bước 2), và một bộ lọc theo đuôi file sẽ giấu mất chính những file
  /// hợp lệ mang đuôi lạ — `.sta` của MT940 là ví dụ sẵn có. File không nhận ra
  /// được sẽ về như một `UnrecognizedFile` và hiển thị riêng nó là lỗi, không
  /// kéo theo những file còn lại.
  ///
  /// Trả về danh sách rỗng khi người dùng đóng hộp thoại mà không chọn gì.
  Future<List<PickedFile>> pickStatements() async {
    final files = await FilePicker.pickFiles(dialogTitle: 'Chọn file sao kê');
    return <PickedFile>[
      for (final file in files)
        PickedFile(fileName: file.name, bytes: await file.readAsBytes()),
    ];
  }

  /// Chọn một file sao lưu để khôi phục (UC-13 bước 2).
  ///
  /// Trả `null` khi người dùng huỷ.
  Future<PickedFile?> pickBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Chọn file sao lưu',
    );
    if (file == null) return null;
    final Uint8List bytes = await file.readAsBytes();
    return PickedFile(fileName: file.name, bytes: bytes);
  }
}
