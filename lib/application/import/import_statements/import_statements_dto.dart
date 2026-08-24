import 'dart:typed_data';

import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';
import '../../../domain/value_objects/import_file_status.dart';
import '../../../domain/value_objects/statement_format.dart';

/// Một file đã sẵn sàng nhập, sau khi các bước tương tác của UC-02 (chọn file,
/// nhận diện định dạng, gán tài khoản đích, xử lý cảnh báo lệch số tài khoản) đã
/// xong.
///
/// Việc nhận diện định dạng và đối chiếu số tài khoản cố ý nằm **trước** use case
/// này: cả hai chỉ đọc phần đầu file và phải chờ người dùng quyết, nên chúng chạy
/// đồng bộ trước khi bắt đầu xử lý nền — nhờ vậy việc chờ người dùng không làm
/// nghẽn hàng đợi ghi tuần tự ở bước 5 (UC-02 bước 4).
final class ImportFileInput {
  const ImportFileInput({
    required this.fileName,
    required this.bytes,
    required this.format,
    required this.accountId,
    this.skip = false,
  });

  final String fileName;

  final Uint8List bytes;

  /// Định dạng đã nhận diện — người dùng không bao giờ phải chọn (UC-02 bước 2).
  final StatementFormat format;

  /// Tài khoản đích đã gán cho riêng file này (UC-02 bước 3).
  final int accountId;

  /// Người dùng chọn "bỏ qua file này" ở cảnh báo lệch số tài khoản. File vẫn
  /// được ghi nhận vào lịch sử với trạng thái đã bỏ qua, không phải lỗi đọc file
  /// (UC-02 bước 4).
  final bool skip;
}

/// Một lượt nhập: nhóm file người dùng chọn cùng lúc, cùng chiến lược concurrency
/// đã chọn cho lượt này (UC-02).
final class ImportStatementsRequest {
  const ImportStatementsRequest({
    required this.files,
    required this.strategy,
    this.cancellation,
  });

  /// Theo đúng thứ tự người dùng chọn — cũng là thứ tự ghi, để hai lần nhập cùng
  /// một tập file cho cùng một kết quả (Rule – Write Order Is Deterministic).
  final List<ImportFileInput> files;

  final ConcurrencyStrategy strategy;

  final CancellationSignal? cancellation;
}

/// Kết quả nhập của một file, hiển thị ở màn hình tổng kết (UC-02 bước 8).
final class FileImportSummary {
  const FileImportSummary({
    required this.recordId,
    required this.fileName,
    required this.accountId,
    required this.status,
    required this.importedCount,
    required this.duplicateSkippedCount,
    required this.errorRowCount,
  });

  final int recordId;
  final String fileName;
  final int accountId;
  final ImportFileStatus status;
  final int importedCount;
  final int duplicateSkippedCount;
  final int errorRowCount;
}

/// Tổng kết cả lượt: từng file và cộng dồn (UC-02 bước 8).
final class ImportSummary {
  const ImportSummary({
    required this.sessionId,
    required this.files,
    required this.mode,
    required this.wasCancelled,
  });

  final int sessionId;

  final List<FileImportSummary> files;

  /// Xử lý nền thật (isolate) hay suy biến đồng bộ (Web/mainThread) — để màn hình
  /// tổng kết nói đúng điều đã xảy ra (UC-14).
  final ExecutionMode mode;

  /// Người dùng đã huỷ giữa chừng; phần đã ghi vẫn được giữ (UC-02 bước 7).
  final bool wasCancelled;

  int get importedCount =>
      files.fold(0, (total, file) => total + file.importedCount);

  int get duplicateSkippedCount =>
      files.fold(0, (total, file) => total + file.duplicateSkippedCount);

  int get errorRowCount =>
      files.fold(0, (total, file) => total + file.errorRowCount);
}
