import '../../../application/reconciliation/run_reconciliation/run_reconciliation_dto.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/queries/account_activity.dart';
import '../view_models/pair_view_model.dart';
import '../view_models/reconciliation_group.dart';

/// Lần quét đang ở đâu (UC-08).
enum ReconciliationRunPhase {
  /// Chưa chạy, hoặc đã chạy xong.
  idle,

  /// Nhóm *Chờ quyết định* khác rỗng và người dùng vừa bấm Chạy: cảnh báo đang
  /// đợi xác nhận, chưa có gì bị xoá.
  awaitingConfirmation,

  running,

  /// Đã yêu cầu dừng nhưng lô hiện tại còn đang chạy. Trạng thái riêng vì nút
  /// Huỷ chỉ được đọc tại ranh giới lô, và giấu quãng chờ đó đi là nói dối về
  /// một giới hạn có thật (UC-14).
  cancelling,
}

/// Tiến trình một lần quét, đã thành chữ.
final class ReconciliationProgressViewModel {
  const ReconciliationProgressViewModel({
    required this.processed,
    required this.total,
    required this.pairsFound,
    required this.fraction,
    required this.isBackground,
  });

  factory ReconciliationProgressViewModel.of(ReconciliationProgress p) =>
      ReconciliationProgressViewModel(
        processed: p.processed,
        total: p.total,
        pairsFound: p.pairsFound,
        fraction: p.fraction,
        isBackground: p.isBackground,
      );

  final int processed;
  final int total;

  /// Số cặp đã **ghi được** tới lúc này — con số thật, không phải ước lượng: cặp
  /// được ghi dần theo lô.
  final int pairsFound;

  /// `null` khi chưa xác định được tổng.
  final double? fraction;

  /// Quét đang chạy trong isolate hay ngay trên luồng giao diện (UC-14).
  final bool isBackground;
}

/// Toàn bộ trạng thái màn hình đối soát.
///
/// Cùng lý do với `TransactionsState`, lớp này **không** có `==` theo giá trị:
/// mọi `emit` ở đây đều mang theo thay đổi thật, và các danh sách bên trong đủ
/// dài để so sánh sâu tốn hơn việc vẽ lại.
final class ReconciliationState {
  const ReconciliationState({
    this.status = LoadStatus.initial,
    this.group = ReconciliationGroup.pending,
    this.pendingCount = 0,
    this.confirmedCount = 0,
    this.rejectedCount = 0,
    this.rejectedCountIsCapped = false,
    this.pairs = const <PairRowViewModel>[],
    this.rejected = const <RejectedRowViewModel>[],
    this.hasMore = false,
    this.isLoadingMore = false,
    this.openPairId,
    this.detail,
    this.detailStatus = LoadStatus.initial,
    this.runPhase = ReconciliationRunPhase.idle,
    this.progress,
    this.lastRun,
    this.matchWindowDays = 3,
    this.accountsWithTransactions = 0,
    this.supportsIsolates = true,
    this.undoableRejectionId,
    this.notice,
    this.loadError,
  });

  final LoadStatus status;

  /// Nhóm đang chọn trên Segmented Control.
  final ReconciliationGroup group;

  /// Ba số đếm **luôn** hiển thị, kể cả bằng 0 (UC-09).
  final int pendingCount;
  final int confirmedCount;
  final int rejectedCount;

  /// Nhóm *Đã từ chối* đã chạm trần nạp, nên [rejectedCount] là "ít nhất từng
  /// ấy" chứ không phải con số đúng.
  ///
  /// Tồn tại vì nhóm này được đếm bằng cách **nạp trọn rồi đếm** — cách duy nhất
  /// lấy được số đếm mà không phá quyết định có chủ đích của `RejectedPage` là
  /// không trả tổng số. Giả định đằng sau nó ("bảng này không bao giờ lớn") là
  /// một giả định, và cờ này là chỗ nó được nói thành lời thay vì âm thầm hiển
  /// thị một con số cụt.
  final bool rejectedCountIsCapped;

  /// Danh sách cặp của nhóm đang chọn; rỗng khi nhóm đang chọn là *Đã từ chối*.
  final List<PairRowViewModel> pairs;

  /// Danh sách phán quyết từ chối. Được nạp **trọn** chứ không phân trang — xem
  /// `ReconciliationBloc.maxRejectedRows`.
  final List<RejectedRowViewModel> rejected;

  final bool hasMore;
  final bool isLoadingMore;

  final int? openPairId;
  final PairDetailViewModel? detail;
  final LoadStatus detailStatus;

  final ReconciliationRunPhase runPhase;

  final ReconciliationProgressViewModel? progress;

  /// Kết quả lần chạy gần nhất trong phiên này.
  final RunReconciliationResult? lastRun;

  /// Ngưỡng lệch thời gian đang đặt (UC-08).
  final int matchWindowDays;

  final int accountsWithTransactions;

  /// Nền tảng có isolate thật không. Sai trên Web, và đó là thứ Web Degradation
  /// Indicator nói ra (UC-14).
  final bool supportsIsolates;

  /// Phán quyết từ chối vừa ghi, để snackbar có nút Hoàn tác (UC-09 bước 3).
  final int? undoableRejectionId;

  final TransientNotice? notice;

  final FeedbackMessage? loadError;

  /// Đối soát cần hai tài khoản khác nhau để có gì mà ghép (UC-08).
  bool get canRun =>
      accountsWithTransactions >=
      AccountActivity.minimumAccountsForReconciliation;

  bool get isRunning =>
      runPhase == ReconciliationRunPhase.running ||
      runPhase == ReconciliationRunPhase.cancelling;

  /// Chạy lại sẽ xoá sạch nhóm *Chờ quyết định*; cặp đã xác nhận sống sót.
  bool get runWouldClearPending => pendingCount > 0;

  int countOf(ReconciliationGroup group) => switch (group) {
    ReconciliationGroup.pending => pendingCount,
    ReconciliationGroup.confirmed => confirmedCount,
    ReconciliationGroup.rejected => rejectedCount,
  };

  ReconciliationState copyWith({
    LoadStatus? status,
    ReconciliationGroup? group,
    int? pendingCount,
    int? confirmedCount,
    int? rejectedCount,
    bool? rejectedCountIsCapped,
    List<PairRowViewModel>? pairs,
    List<RejectedRowViewModel>? rejected,
    bool? hasMore,
    bool? isLoadingMore,
    int? openPairId,
    bool clearOpenPair = false,
    PairDetailViewModel? detail,
    bool clearDetail = false,
    LoadStatus? detailStatus,
    ReconciliationRunPhase? runPhase,
    ReconciliationProgressViewModel? progress,
    bool clearProgress = false,
    RunReconciliationResult? lastRun,
    int? matchWindowDays,
    int? accountsWithTransactions,
    bool? supportsIsolates,
    int? undoableRejectionId,
    bool clearUndoableRejection = false,
    TransientNotice? notice,
    FeedbackMessage? loadError,
    bool clearLoadError = false,
  }) => ReconciliationState(
    status: status ?? this.status,
    group: group ?? this.group,
    pendingCount: pendingCount ?? this.pendingCount,
    confirmedCount: confirmedCount ?? this.confirmedCount,
    rejectedCount: rejectedCount ?? this.rejectedCount,
    rejectedCountIsCapped: rejectedCountIsCapped ?? this.rejectedCountIsCapped,
    pairs: pairs ?? this.pairs,
    rejected: rejected ?? this.rejected,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    openPairId: clearOpenPair ? null : (openPairId ?? this.openPairId),
    detail: clearDetail ? null : (detail ?? this.detail),
    detailStatus: detailStatus ?? this.detailStatus,
    runPhase: runPhase ?? this.runPhase,
    progress: clearProgress ? null : (progress ?? this.progress),
    lastRun: lastRun ?? this.lastRun,
    matchWindowDays: matchWindowDays ?? this.matchWindowDays,
    accountsWithTransactions:
        accountsWithTransactions ?? this.accountsWithTransactions,
    supportsIsolates: supportsIsolates ?? this.supportsIsolates,
    undoableRejectionId: clearUndoableRejection
        ? null
        : (undoableRejectionId ?? this.undoableRejectionId),
    notice: notice ?? this.notice,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}
