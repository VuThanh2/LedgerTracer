import '../../../core/concurrency/execution_mode.dart';

/// Ảnh chụp tiến trình của một lượt nhập đang chạy, gửi từ use case lên giao diện
/// (UC-02 bước 5).
///
/// Là trạng thái thực thi, không phải Domain: nó chỉ sống bằng vòng đời của lượt
/// nhập và không bao giờ được lưu. Nó cộng dồn các `ProgressReport` cấp-lô của
/// core thành thứ màn hình nhập cần — file nào đang chạy, đã xong bao nhiêu file.
///
/// [mode] đi kèm để màn hình nói thẳng giới hạn nền tảng thay vì giấu nó: trên
/// Web đây là [ExecutionMode.mainThread], và tiến trình chỉ nhích tại ranh giới
/// giữa các lô (UC-14).
final class ImportProgress {
  const ImportProgress({
    required this.fileCount,
    required this.completedFiles,
    required this.currentFileIndex,
    required this.currentFileName,
    required this.processedInCurrentFile,
    this.totalInCurrentFile,
    required this.mode,
  });

  final int fileCount;

  /// Số file đã đi tới trạng thái cuối. Vì giai đoạn ghi tuần tự theo thứ tự
  /// người dùng chọn, một file xong nghĩa là mọi file trước nó cũng đã xong.
  final int completedFiles;

  /// Thứ tự file đang được ghi (theo thứ tự người dùng chọn).
  final int currentFileIndex;

  final String currentFileName;

  final int processedInCurrentFile;

  /// Tổng ước lượng của file hiện tại, hoặc `null` khi chưa xác định được — số
  /// dòng của một file chỉ biết sau khi đã đọc hết, nên giao diện hiện vòng xoay
  /// thay vì thanh tiến trình.
  final int? totalInCurrentFile;

  final ExecutionMode mode;

  /// Xử lý nền có thật sự chạy ngoài luồng giao diện hay không (native vs Web).
  bool get isBackground => mode.isBackground;

  double? get currentFileFraction {
    final total = totalInCurrentFile;
    if (total == null || total <= 0) return null;
    final ratio = processedInCurrentFile / total;
    return ratio > 1 ? 1 : ratio;
  }

  @override
  String toString() =>
      'ImportProgress(file ${currentFileIndex + 1}/$fileCount, '
      '$processedInCurrentFile/${totalInCurrentFile ?? '?'})';
}
