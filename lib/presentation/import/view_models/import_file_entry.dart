import '../../../application/import/import_statements/import_statements_dto.dart';
import '../../../application/import/prepare_import/prepare_import_dto.dart';
import '../../../domain/value_objects/statement_format.dart';

/// Người dùng đã quyết gì khi số tài khoản trong file lệch với số đã ghi nhận
/// (UC-02 bước 4).
///
/// Cảnh báo lệch số tài khoản **không chặn cứng**, vì có lý do hợp lệ: ngân hàng
/// cấp lại số, hoặc lần nhập đầu đã học sai. Nhưng nó **bắt buộc phải được trả
/// lời** trước khi đi tiếp — bỏ qua nó nghĩa là nhập sao kê của tài khoản này
/// vào tài khoản khác mà không ai biết.
///
/// "Gán lại tài khoản khác" không có mặt ở đây vì nó không phải một quyết định
/// về file: nó chỉ là đổi tài khoản đích, và làm thế sẽ chạy lại phép đối chiếu
/// từ đầu — có thể cho ra một phán quyết hoàn toàn khác.
enum MismatchDecision {
  /// Vẫn nhập vào tài khoản đã gán.
  ///
  /// **Không** ghi đè số tài khoản đã ghi nhận: muốn đổi mốc đối chiếu thì phải
  /// sửa tường minh ở màn hình quản lý tài khoản. Nếu chọn ở đây cũng ghi đè thì
  /// một lần bấm vội sẽ âm thầm phá mất mốc đối chiếu của mọi lần nhập sau.
  importAnyway,

  /// Bỏ qua file này. Nó vẫn được ghi nhận vào lịch sử với trạng thái đã bỏ qua
  /// — đây là một quyết định, không phải một lỗi đọc file.
  skipFile,
}

/// Một file trong luồng nhập, từ lúc được chọn tới lúc sẵn sàng nhập.
///
/// Một kiểu duy nhất đi qua cả ba bước tương tác thay vì ba kiểu nối tiếp nhau:
/// người dùng đi tới đi lui giữa bước 1 và bước 2, và mỗi lần quay lại mà phải
/// dựng lại đối tượng là một lần mất những gì họ đã gán.
final class ImportFileEntry {
  const ImportFileEntry({
    required this.fileName,
    this.recognized,
    this.unrecognizedReason,
    this.accountId,
    this.check,
    this.decision,
  });

  factory ImportFileEntry.of(InspectedFile inspected) => switch (inspected) {
    RecognizedFile() => ImportFileEntry(
      fileName: inspected.fileName,
      recognized: inspected,
    ),
    UnrecognizedFile() => ImportFileEntry(
      fileName: inspected.fileName,
      unrecognizedReason: inspected.reason,
    ),
  };

  final String fileName;

  /// `null` khi định dạng không nhận ra được.
  final RecognizedFile? recognized;

  /// Vì sao không nhận ra được. Một file lạ là **dữ liệu**, không phải lỗi làm
  /// hỏng cả lượt: những file còn lại vẫn đi tiếp bình thường (UC-02).
  final String? unrecognizedReason;

  /// Tài khoản đích người dùng đã gán (UC-02 bước 3).
  final int? accountId;

  /// Kết quả đối chiếu số tài khoản, `null` khi chưa gán tài khoản.
  final AccountAssignmentCheck? check;

  /// Quyết định cho phán quyết lệch số tài khoản.
  final MismatchDecision? decision;

  bool get isRecognized => recognized != null;

  StatementFormat? get format => recognized?.format;

  /// File này có bị bỏ qua khi nhập không.
  bool get isSkipped => decision == MismatchDecision.skipFile;

  /// Cảnh báo lệch số tài khoản còn đang chờ người dùng trả lời.
  ///
  /// Đây là điều kiện **chặn** bước 3: đi tiếp khi nó còn đúng nghĩa là bỏ qua
  /// một cảnh báo mà người dùng chưa hề thấy (UC-02 bước 4).
  bool get hasUnresolvedMismatch =>
      (check?.needsUserDecision ?? false) && decision == null;

  /// Hệ thống sẽ tự ghi nhận số tài khoản đọc được từ file này.
  ///
  /// Chỉ đúng khi tài khoản đích **chưa** có số. Việc ghi nhận diễn ra ở bước 3,
  /// ngay trước khi nhập, để lần nhập sau có mốc mà đối chiếu.
  bool get willLearnAccountNumber =>
      check?.verdict == AccountNumberVerdict.willLearn;

  /// Sẵn sàng đi tiếp: đã nhận ra định dạng, đã gán tài khoản, và không còn cảnh
  /// báo nào treo.
  bool get isReady =>
      isRecognized && accountId != null && !hasUnresolvedMismatch;

  ImportFileEntry copyWith({
    int? accountId,
    AccountAssignmentCheck? check,
    MismatchDecision? decision,
    bool clearDecision = false,
  }) => ImportFileEntry(
    fileName: fileName,
    recognized: recognized,
    unrecognizedReason: unrecognizedReason,
    accountId: accountId ?? this.accountId,
    check: check ?? this.check,
    decision: clearDecision ? null : (decision ?? this.decision),
  );

  /// Đổi sang đầu vào của use case nhập. Chỉ gọi được khi [isReady].
  ImportFileInput toInput() => ImportFileInput(
    fileName: fileName,
    bytes: recognized!.bytes,
    format: recognized!.format,
    accountId: accountId!,
    skip: isSkipped,
  );
}
