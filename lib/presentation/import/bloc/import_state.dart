import '../../../domain/entities/bank_account.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/queries/account_activity.dart';
import '../view_models/import_file_entry.dart';
import '../view_models/import_progress_view_model.dart';

/// Bốn bước của stepper nhập sao kê (UC-02).
///
/// Là **trạng thái của cùng một tab**, không phải bốn route: quay lại bằng nút
/// back của hệ điều hành ở giữa một lượt nhập đang chạy sẽ bỏ dở tác vụ nền, và
/// bốn route nghĩa là bốn chỗ phải tự chống lại chuyện đó.
enum ImportStep {
  /// Chọn file và nhận diện định dạng.
  pickFiles,

  /// Gán tài khoản đích và xử lý cảnh báo lệch số tài khoản. **Bắt buộc chặn**
  /// trước bước 3.
  assignAccounts,

  /// Đang phân tích và ghi.
  running,

  /// Bảng tổng kết.
  summary;

  bool get canGoBack =>
      this == ImportStep.assignAccounts;
}

/// Trạng thái tab *Nhập mới*.
///
/// Không có `==` theo giá trị, cùng lý do với các state khác: mỗi `emit` ở đây
/// đều mang thay đổi thật, và [files] giữ nguyên bytes của từng file nên so sánh
/// sâu sẽ đụng tới hàng chục megabyte.
final class ImportState {
  const ImportState({
    this.step = ImportStep.pickFiles,
    this.files = const <ImportFileEntry>[],
    this.accounts = const <BankAccount>[],
    this.isPicking = false,
    this.progress,
    this.isCancelling = false,
    this.summary,
    this.accountsWithTransactions = 0,
    this.supportsIsolates = true,
    this.notice,
    this.error,
  });

  final ImportStep step;

  /// Mọi file người dùng đã chọn, **kể cả file không nhận ra định dạng**: một
  /// file lạ phải hiện ra là lỗi của riêng nó, không im lặng biến mất.
  final List<ImportFileEntry> files;

  /// Tài khoản đã khai báo, cho ô chọn ở bước 2.
  final List<BankAccount> accounts;

  final bool isPicking;

  /// `null` khi chưa chạy hoặc đã chạy xong.
  final ImportProgressViewModel? progress;

  /// Đã bấm Huỷ nhưng lô hiện tại còn chạy nốt (UC-02 bước 7, UC-14).
  final bool isCancelling;

  final ImportSummaryViewModel? summary;

  /// Số tài khoản **có giao dịch** trên toàn hệ thống, đọc lại sau khi nhập xong.
  ///
  /// Chỉ dùng cho một việc: quyết định có hiện nút "Chạy đối soát" ở bảng tổng
  /// kết hay không. Đối soát nội bộ ghép tiền chuyển giữa **hai** tài khoản khác
  /// nhau, nên mời người dùng chạy nó khi mới có một tài khoản là dẫn họ tới một
  /// màn hình chỉ có thể nói "chưa đủ điều kiện".
  final int accountsWithTransactions;

  /// Nền tảng có isolate thật không — Web Degradation Indicator nhúng vào bước 3
  /// đọc cờ này để nói ra hai hệ quả: mất isolate thì giao diện có thể giật, mất
  /// song song nhiều file thì tổng thời gian dài hơn (UC-14).
  final bool supportsIsolates;

  final TransientNotice? notice;

  final FeedbackMessage? error;

  List<ImportFileEntry> get recognizedFiles =>
      <ImportFileEntry>[for (final file in files) if (file.isRecognized) file];

  List<ImportFileEntry> get unrecognizedFiles =>
      <ImportFileEntry>[for (final file in files) if (!file.isRecognized) file];

  /// Bước 1 → 2: cần ít nhất một file đọc được.
  bool get canAssignAccounts => recognizedFiles.isNotEmpty;

  /// Bước 2 → 3: **mọi** file đọc được đã có tài khoản và không còn cảnh báo
  /// lệch số tài khoản nào chưa trả lời (UC-02 bước 4).
  bool get canRun =>
      canAssignAccounts && recognizedFiles.every((file) => file.isReady);

  /// Còn file nào chưa gán tài khoản — để bước 2 chỉ ra đúng chỗ đang chặn.
  int get unassignedCount =>
      recognizedFiles.where((file) => file.accountId == null).length;

  int get unresolvedMismatchCount =>
      recognizedFiles.where((file) => file.hasUnresolvedMismatch).length;

  bool get isRunning => step == ImportStep.running;

  /// Bảng tổng kết có nên hiện nút **điều hướng** sang màn hình đối soát không
  /// (UC-02 bước 8 → UC-08).
  ///
  /// Là nút phụ và chỉ **điều hướng**, không tự chạy: chạy đối soát xoá sạch mọi
  /// cặp chưa xác nhận, và một thao tác như thế không được khởi động từ một cú
  /// bấm ở màn hình khác.
  bool get canGoToReconciliation =>
      summary != null &&
      accountsWithTransactions >=
          AccountActivity.minimumAccountsForReconciliation;

  ImportState copyWith({
    ImportStep? step,
    List<ImportFileEntry>? files,
    List<BankAccount>? accounts,
    bool? isPicking,
    ImportProgressViewModel? progress,
    bool clearProgress = false,
    bool? isCancelling,
    ImportSummaryViewModel? summary,
    bool clearSummary = false,
    int? accountsWithTransactions,
    bool? supportsIsolates,
    TransientNotice? notice,
    FeedbackMessage? error,
    bool clearError = false,
  }) => ImportState(
    step: step ?? this.step,
    files: files ?? this.files,
    accounts: accounts ?? this.accounts,
    isPicking: isPicking ?? this.isPicking,
    progress: clearProgress ? null : (progress ?? this.progress),
    isCancelling: isCancelling ?? this.isCancelling,
    summary: clearSummary ? null : (summary ?? this.summary),
    accountsWithTransactions:
        accountsWithTransactions ?? this.accountsWithTransactions,
    supportsIsolates: supportsIsolates ?? this.supportsIsolates,
    notice: notice ?? this.notice,
    error: clearError ? null : (error ?? this.error),
  );
}
