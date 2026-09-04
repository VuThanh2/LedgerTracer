import '../../../application/import/contracts/import_progress.dart';
import '../../../application/import/import_statements/import_statements_dto.dart';
import '../../../domain/value_objects/import_file_status.dart';
import '../../shared/formatting/number_formatter.dart';

/// Tiến trình một lượt nhập, đã thành chữ (UC-02 bước 5).
///
/// Hình dạng của nó bị quy định bởi một sự thật khó chịu ở tầng dưới: trên native
/// **nhiều file được phân tích song song**, nên không có khái niệm "file hiện
/// tại". Vì vậy thanh tiến trình chính gắn với [processedTotal] — tổng số dòng
/// của cả lượt — còn tên file chỉ là một dòng trạng thái nói lô vừa rồi đến từ
/// đâu. Nó nhảy qua nhảy lại giữa các file, và đó là hành vi đúng.
final class ImportProgressViewModel {
  const ImportProgressViewModel({
    required this.fileCount,
    required this.completedFiles,
    required this.reportingFileName,
    required this.processedTotal,
    required this.processedTotalText,
    required this.fileFraction,
    required this.isBackground,
  });

  factory ImportProgressViewModel.of(ImportProgress progress) =>
      ImportProgressViewModel(
        fileCount: progress.fileCount,
        completedFiles: progress.completedFiles,
        reportingFileName: progress.reportingFileName,
        processedTotal: progress.processedTotal,
        processedTotalText: NumberFormatter.count(progress.processedTotal),
        fileFraction: progress.fileFraction,
        isBackground: progress.isBackground,
      );

  final int fileCount;

  /// Số file đã **ghi xong hẳn** — con số duy nhất tăng đơn điệu và không bao
  /// giờ lùi, nên nó là thứ dùng để nói "3/5 file".
  final int completedFiles;

  final String reportingFileName;

  final int processedTotal;

  final String processedTotalText;

  /// Mức hoàn thành của riêng file vừa báo, `null` khi định dạng không cho biết
  /// tổng số dòng — khi ấy thanh của file là loại không xác định.
  final double? fileFraction;

  /// Đang chạy trong isolate hay ngay trên luồng giao diện (UC-14).
  final bool isBackground;

  /// Mức hoàn thành của **cả lượt**, đo bằng số file đã xong.
  ///
  /// Không đo bằng số dòng, vì tổng số dòng của cả lượt chỉ biết được sau khi đã
  /// đọc xong mọi file — tức là sau khi thanh tiến trình không còn ai cần nữa.
  double get sessionFraction => fileCount == 0 ? 0 : completedFiles / fileCount;
}

/// Kết quả nhập của một file trên bảng tổng kết (UC-02 bước 8).
final class FileImportSummaryViewModel {
  const FileImportSummaryViewModel({
    required this.recordId,
    required this.fileName,
    required this.accountName,
    required this.status,
    required this.statusLabel,
    required this.importedText,
    required this.duplicateSkippedText,
    required this.errorRowText,
    required this.errorRowCount,
  });

  factory FileImportSummaryViewModel.of(
    FileImportSummary summary, {
    required String accountName,
  }) => FileImportSummaryViewModel(
    recordId: summary.recordId,
    fileName: summary.fileName,
    accountName: accountName,
    status: summary.status,
    statusLabel: _labelOf(summary.status),
    importedText: NumberFormatter.count(summary.importedCount),
    duplicateSkippedText: NumberFormatter.count(summary.duplicateSkippedCount),
    errorRowText: NumberFormatter.count(summary.errorRowCount),
    errorRowCount: summary.errorRowCount,
  );

  final int recordId;
  final String fileName;
  final String accountName;
  final ImportFileStatus status;
  final String statusLabel;
  final String importedText;
  final String duplicateSkippedText;
  final String errorRowText;

  /// Giữ dạng số để giao diện biết có nên hiện nút xuất danh sách dòng lỗi hay
  /// không — nút xuất một file rỗng là một nút vô nghĩa.
  final int errorRowCount;

  bool get hasErrorRows => errorRowCount > 0;

  static String _labelOf(ImportFileStatus status) => switch (status) {
    ImportFileStatus.completed => 'Committed',
    ImportFileStatus.partiallyFailed => 'Has error rows',
    ImportFileStatus.cancelled => 'Cancelled',
    ImportFileStatus.skipped => 'Skipped',
  };
}

/// Bảng tổng kết cả lượt (UC-02 bước 8).
final class ImportSummaryViewModel {
  const ImportSummaryViewModel({
    required this.sessionId,
    required this.files,
    required this.importedText,
    required this.duplicateSkippedText,
    required this.errorRowText,
    required this.wasCancelled,
    required this.ranInBackground,
    required this.hasErrorRows,
  });

  factory ImportSummaryViewModel.of(
    ImportSummary summary, {
    required Map<int, String> accountNames,
  }) => ImportSummaryViewModel(
    sessionId: summary.sessionId,
    files: <FileImportSummaryViewModel>[
      for (final file in summary.files)
        FileImportSummaryViewModel.of(
          file,
          accountName: accountNames[file.accountId] ?? '',
        ),
    ],
    importedText: NumberFormatter.count(summary.importedCount),
    duplicateSkippedText: NumberFormatter.count(summary.duplicateSkippedCount),
    errorRowText: NumberFormatter.count(summary.errorRowCount),
    wasCancelled: summary.wasCancelled,
    ranInBackground: summary.mode.isBackground,
    hasErrorRows: summary.errorRowCount > 0,
  );

  final int sessionId;
  final List<FileImportSummaryViewModel> files;
  final String importedText;

  /// Số dòng bị bỏ qua vì trùng. Con số này không đếm lại được từ bất cứ đâu —
  /// dòng bị bỏ qua không nằm ở đâu cả — nên nó luôn phải hiện, kể cả bằng 0.
  final String duplicateSkippedText;

  final String errorRowText;

  /// Người dùng đã dừng giữa chừng; phần đã ghi vẫn được giữ, và nhập lại chính
  /// file đó về sau chỉ bổ sung phần còn thiếu (UC-02 bước 7).
  final bool wasCancelled;

  final bool ranInBackground;

  final bool hasErrorRows;
}
