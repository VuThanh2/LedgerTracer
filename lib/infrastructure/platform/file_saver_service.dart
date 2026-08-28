import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../application/export/export_dataset/export_dataset_dto.dart';
import '../../application/settings/backup_restore/backup_restore_dto.dart';
import '../../core/concurrency/cancellation_signal.dart';

/// Ghi bytes ra nơi người dùng chọn (Android) hoặc qua cơ chế tải xuống của
/// trình duyệt (Web).
///
/// Một lớp hiện thực **cả hai** cổng ghi file — [FileSaver] của file xuất
/// (UC-11) và [BackupWriter] của file sao lưu (UC-13) — vì cả hai nói cùng một
/// việc: đưa một khối bytes ra khỏi ứng dụng. Hai cổng vẫn tách nhau ở tầng
/// Application, nơi chúng mang hai ý nghĩa nghiệp vụ khác nhau (một file mở được
/// bằng Excel, một file chỉ ứng dụng đọc lại được); nhưng dựng hai hiện thực
/// giống hệt nhau ở đây chỉ tạo ra hai chỗ để cùng một lỗi nền tảng phải sửa hai
/// lần.
///
/// Khác biệt nền tảng được phản ánh trung thực trong giá trị trả về thay vì bị
/// giấu: trên Android người dùng chọn được vị trí lưu và nhận lại đường dẫn, còn
/// trên Web file đi qua cơ chế tải xuống của trình duyệt và **không có đường dẫn
/// nào để trả về** (UC-11, UC-13).
final class PlatformFileSaverService implements FileSaver, BackupWriter {
  const PlatformFileSaverService();

  @override
  Future<SavedFile> save({
    required Uint8List bytes,
    required String suggestedName,
    required ExportFormat format,
  }) async {
    final location = await _write(
      bytes,
      suggestedName: suggestedName,
      mimeType: _mimeTypeOf(format),
    );
    return SavedFile(
      path: location.path,
      viaBrowserDownload: location.viaBrowserDownload,
    );
  }

  @override
  Future<BackupLocation> write(
    Uint8List bytes, {
    required String suggestedName,
  }) => _write(
    bytes,
    suggestedName: suggestedName,
    // Bản sao lưu là dữ liệu nhị phân của riêng ứng dụng; không có kiểu MIME
    // nào mô tả nó, và gán bừa một kiểu quen thuộc sẽ khiến hệ điều hành gợi ý
    // mở nó bằng một ứng dụng không đọc nổi.
    mimeType: 'application/octet-stream',
  );

  Future<BackupLocation> _write(
    Uint8List bytes, {
    required String suggestedName,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: suggestedName,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (uri == null) {
      // Người dùng đóng hộp thoại lưu. Đây là một **kết cục**, không phải lỗi:
      // tầng Application đổi nó thành `CancelledFailure` và giao diện báo đã
      // huỷ, thay vì báo có vấn đề với một thao tác mà chính người dùng vừa
      // dừng lại.
      throw const CancellationException();
    }
    // Trình duyệt không cho biết file đi đâu; `blob:` và `data:` là dấu hiệu
    // file đã đi qua cơ chế tải xuống chứ không nằm ở một đường dẫn nào.
    final isFilePath = uri.scheme == 'file';
    return BackupLocation(
      path: isFilePath ? uri.toFilePath() : null,
      viaBrowserDownload: kIsWeb || !isFilePath,
    );
  }

  static String _mimeTypeOf(ExportFormat format) => switch (format) {
    ExportFormat.csv => 'text/csv',
    ExportFormat.excel =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  };
}
