import '../../../core/concurrency/execution_mode.dart';

/// Ảnh chụp tiến trình của một lượt nhập, gửi ra sau mỗi lô (UC-02 bước 5).
///
/// Hình dạng của nó bị quy định bởi một sự thật khó chịu: trên native **nhiều
/// file được phân tích song song**, nên tại một thời điểm có nhiều hơn một file
/// đang tiến triển. Vì vậy ở đây không có khái niệm "file hiện tại".
///
/// - [completedFiles] đếm số file đã **ghi xong hẳn**, không phải số file đã bắt
///   đầu — đó là con số duy nhất tăng đơn điệu và không bao giờ lùi.
/// - [processedTotal] là tổng số dòng đã phân tích của cả lượt; đây mới là đại
///   lượng nên gắn vào thanh tiến trình chính.
/// - [reportingFileIndex] chỉ nói **lô vừa rồi đến từ file nào**, để màn hình
///   ghi được một dòng trạng thái. Nó nhảy qua nhảy lại giữa các file khi chạy
///   song song, và đó là hành vi đúng chứ không phải lỗi.
final class ImportProgress {
  const ImportProgress({
    required this.fileCount,
    required this.completedFiles,
    required this.reportingFileIndex,
    required this.reportingFileName,
    required this.processedInFile,
    this.totalInFile,
    required this.processedTotal,
    required this.mode,
  });

  final int fileCount;

  /// Số file đã ghi xong hẳn (hoàn tất, bị huỷ, hoặc thất bại).
  final int completedFiles;

  /// Thứ tự file vừa báo tiến trình, theo thứ tự người dùng chọn.
  final int reportingFileIndex;

  final String reportingFileName;

  /// Số dòng đã phân tích trong riêng file vừa báo.
  final int processedInFile;

  /// Ước lượng tổng số dòng của file đó, `null` khi định dạng không cho biết rẻ
  /// tiền — khi ấy thanh tiến trình của file là loại không xác định.
  final int? totalInFile;

  /// Tổng số dòng đã phân tích của **cả lượt**, cộng dồn trên mọi file.
  final int processedTotal;

  /// Chế độ chạy thực tế. Trên Web nó suy biến về luồng chính, và giao diện phải
  /// nói đúng điều đó thay vì giấu đi (UC-14).
  final ExecutionMode mode;

  bool get isBackground => mode.isBackground;

  double? get fileFraction {
    final total = totalInFile;
    if (total == null || total <= 0) return null;
    final ratio = processedInFile / total;
    return ratio > 1 ? 1 : ratio;
  }

  @override
  String toString() =>
      'ImportProgress($completedFiles/$fileCount file(s) done, '
      '$processedTotal row(s), latest from "$reportingFileName")';
}
