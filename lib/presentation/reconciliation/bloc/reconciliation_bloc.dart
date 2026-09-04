import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../application/reconciliation/confirm_pair/confirm_pair_use_case.dart';
import '../../../application/reconciliation/list_match_alternatives/list_match_alternatives_dto.dart';
import '../../../application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import '../../../application/reconciliation/reject_pair/reject_pair_use_case.dart';
import '../../../application/reconciliation/run_reconciliation/run_reconciliation_dto.dart';
import '../../../application/reconciliation/run_reconciliation/run_reconciliation_use_case.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/value_objects/match_window.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/queries/account_activity.dart';
import '../view_models/pair_view_model.dart';
import '../view_models/reconciliation_group.dart';
import 'reconciliation_event.dart';
import 'reconciliation_state.dart';

/// Màn hình đối soát nội bộ: chạy lượt quét **và** duyệt kết quả (UC-08, UC-09).
///
/// Một BLoC cho cả hai vì chúng là một màn hình, và vì chúng chia nhau đúng
/// những con số quyết định lẫn nhau: nút Chạy phải biết nhóm *Chờ quyết định*
/// đang có bao nhiêu cặp để cảnh báo trước khi xoá sạch chúng, và mỗi lần xác
/// nhận hay từ chối lại làm ba số đếm ấy đổi.
///
/// Ba nhóm trên Segmented Control đến từ **hai** đường đọc khác nhau: *Chờ quyết
/// định* và *Đã xác nhận* là hai trạng thái của cùng bảng cặp, còn *Đã từ chối*
/// là một bảng riêng — từ chối xoá cặp đi và ghi lại một phán quyết độc lập, vì
/// một giao dịch chỉ thuộc tối đa một cặp nhưng có thể bị từ chối với nhiều giao
/// dịch khác nhau.
final class ReconciliationBloc
    extends Bloc<ReconciliationEvent, ReconciliationState> {
  ReconciliationBloc({
    required RunReconciliationUseCase runReconciliation,
    required ListMatchAlternativesUseCase listPairs,
    required ConfirmPairUseCase confirmPair,
    required RejectPairUseCase rejectPair,
    required ManageAccountsUseCase manageAccounts,
    required ViewCashFlowUseCase viewCashFlow,
    required this.capabilities,
    this.pageSize = defaultPageSize,
    this.maxRejectedRows = defaultMaxRejectedRows,
  }) : _run = runReconciliation,
       _list = listPairs,
       _confirm = confirmPair,
       _reject = rejectPair,
       _accounts = manageAccounts,
       _cashFlow = viewCashFlow,
       super(const ReconciliationState()) {
    on<ReconciliationStarted>(_onStarted, transformer: EventTransformers.restartable());
    on<ReconciliationGroupSelected>(_onGroupSelected, transformer: EventTransformers.restartable());
    on<ReconciliationNextPageRequested>(_onNextPage, transformer: EventTransformers.droppable());
    on<ReconciliationPairOpened>(_onPairOpened, transformer: EventTransformers.restartable());
    // Chạy quét là tác vụ dài duy nhất của màn hình này: bấm lần thứ hai trong
    // lúc lượt đầu còn chạy phải **rơi**, không được xếp hàng để chạy lại ngay
    // sau đó. Đường dừng là nút Huỷ.
    on<ReconciliationRunRequested>(_onRunRequested, transformer: EventTransformers.droppable());
    on<ReconciliationRunDismissed>(_onRunDismissed);
    on<ReconciliationRunCancelled>(_onRunCancelled);
    on<ReconciliationPairConfirmed>(_onPairConfirmed, transformer: EventTransformers.sequential());
    on<ReconciliationPairRejected>(_onPairRejected, transformer: EventTransformers.sequential());
    on<ReconciliationRejectionUndone>(_onRejectionUndone, transformer: EventTransformers.sequential());
    on<ReconciliationMatchWindowChanged>(_onMatchWindowChanged, transformer: EventTransformers.sequential());
  }

  final RunReconciliationUseCase _run;
  final ListMatchAlternativesUseCase _list;
  final ConfirmPairUseCase _confirm;
  final RejectPairUseCase _reject;
  final ManageAccountsUseCase _accounts;
  final ViewCashFlowUseCase _cashFlow;
  final PlatformCapabilities capabilities;
  final NoticeSink _notices = NoticeSink();

  /// Tín hiệu huỷ của lượt quét đang chạy; `null` khi không có lượt nào.
  CancellationSignal? _cancellation;

  Map<int, String> _accountNames = const <int, String>{};

  final int pageSize;

  static const int defaultPageSize = 50;

  /// Trần số dòng nạp cho nhóm *Đã từ chối*.
  ///
  /// Nhóm này được nạp **trọn** thay vì phân trang, và đó là đi theo một quyết
  /// định đã có ở tầng dưới chứ không phải bỏ sót: `RejectedPage` cố ý không trả
  /// tổng số, vì mỗi phán quyết là một lần người dùng bấm tay nên bảng ấy không
  /// bao giờ lớn — thêm một phép đếm toàn bảng cho nó là trả chi phí lấy một con
  /// số không màn hình nào dùng.
  ///
  /// Nhưng Segmented Control **bắt buộc** hiển thị số đếm của cả ba nhóm. Cách
  /// duy nhất lấy được con số đó mà không phá quyết định trên là đọc hết rồi
  /// đếm — hợp lý đúng trong giả định "bảng này nhỏ". Trần ở đây là chỗ giả định
  /// ấy được nói thành lời: vượt qua nó thì `rejectedCountIsCapped` bật lên và
  /// số đếm hiển thị kèm dấu "+", chứ không phải luồng đọc chạy mãi.
  final int maxRejectedRows;

  static const int defaultMaxRejectedRows = 500;

  @override
  Future<void> close() {
    // Màn hình đóng giữa lúc quét: phát tín hiệu dừng để lượt quét không chạy
    // tiếp trên một BLoC đã chết. Phần đã ghi vẫn giữ — huỷ không phải rollback.
    _cancellation?.cancel();
    return super.close();
  }

  Future<void> _onStarted(
    ReconciliationStarted event,
    Emitter<ReconciliationState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        supportsIsolates: capabilities.supportsIsolates,
      ),
    );

    _accountNames = await _loadAccountNames();
    final window = await _run.currentMatchWindow();
    final accounts = await AccountActivity.countAccountsWithTransactions(
      _cashFlow,
    );

    emit(
      state.copyWith(
        matchWindowDays: window.valueOrNull?.days ?? state.matchWindowDays,
        accountsWithTransactions: accounts,
      ),
    );

    await _reloadCounts(emit);
    await _reloadGroup(emit);

    if (event.focusPairId != null) {
      await _openPair(event.focusPairId!, emit);
    }
  }

  Future<void> _onGroupSelected(
    ReconciliationGroupSelected event,
    Emitter<ReconciliationState> emit,
  ) async {
    if (event.group == state.group) return;
    emit(state.copyWith(group: event.group, clearOpenPair: true, clearDetail: true));
    await _reloadGroup(emit);
  }

  Future<void> _onNextPage(
    ReconciliationNextPageRequested event,
    Emitter<ReconciliationState> emit,
  ) async {
    // Nhóm *Đã từ chối* đã nạp trọn ngay từ đầu, nên không có trang kế tiếp.
    if (state.group == ReconciliationGroup.rejected) return;
    if (!state.hasMore || state.isLoadingMore || state.status.isLoading) return;

    emit(state.copyWith(isLoadingMore: true));
    final page = await _list.pairs(
      status: state.group.pairStatus,
      limit: pageSize,
      offset: state.pairs.length,
    );
    switch (page) {
      case Err<PairsPage>(:final failure):
        emit(
          state.copyWith(
            isLoadingMore: false,
            loadError: FailurePresenter.of(failure, context: 'cặp đối soát'),
          ),
        );
      case Ok<PairsPage>(:final value):
        final rows = <PairRowViewModel>[
          ...state.pairs,
          for (final view in value.items) PairRowViewModel.of(view),
        ];
        emit(
          state.copyWith(
            pairs: rows,
            isLoadingMore: false,
            hasMore: rows.length < value.totalCount && value.items.isNotEmpty,
          ),
        );
    }
  }

  Future<void> _onPairOpened(
    ReconciliationPairOpened event,
    Emitter<ReconciliationState> emit,
  ) async {
    final pairId = event.pairId;
    if (pairId == null) {
      emit(
        state.copyWith(
          clearOpenPair: true,
          clearDetail: true,
          detailStatus: LoadStatus.initial,
        ),
      );
      return;
    }
    await _openPair(pairId, emit);
  }

  Future<void> _onRunRequested(
    ReconciliationRunRequested event,
    Emitter<ReconciliationState> emit,
  ) async {
    if (state.isRunning) return;
    if (!state.canRun) {
      emit(
        state.copyWith(
          notice: _notices.info(
            'Đối soát cần ít nhất hai tài khoản có giao dịch để có gì mà ghép.',
          ),
        ),
      );
      return;
    }
    // Chạy lại **xoá sạch** mọi cặp chưa xác nhận rồi tính lại từ đầu. Người
    // dùng có thể đã duyệt nửa danh sách, nên việc đó phải được nói ra trước
    // khi nó xảy ra, không phải sau (UC-08).
    if (state.runWouldClearPending && !event.acknowledgedClearingPending) {
      emit(state.copyWith(runPhase: ReconciliationRunPhase.awaitingConfirmation));
      return;
    }

    final cancellation = CancellationSignal();
    _cancellation = cancellation;
    emit(
      state.copyWith(
        runPhase: ReconciliationRunPhase.running,
        clearProgress: true,
        clearOpenPair: true,
        clearDetail: true,
        clearLoadError: true,
      ),
    );

    final result = await _run.execute(
      RunReconciliationRequest(cancellation: cancellation),
      onProgress: (progress) {
        // Bỏ qua báo cáo tới sau khi BLoC đã đóng: lô cuối vẫn chạy nốt sau khi
        // tín hiệu huỷ được phát.
        if (isClosed) return;
        emit(
          state.copyWith(
            progress: ReconciliationProgressViewModel.of(progress),
          ),
        );
      },
    );

    _cancellation = null;
    switch (result) {
      case Err<RunReconciliationResult>(:final failure):
        emit(
          state.copyWith(
            runPhase: ReconciliationRunPhase.idle,
            clearProgress: true,
            notice: _noticeOf(failure, 'lượt đối soát'),
          ),
        );
      case Ok<RunReconciliationResult>(:final value):
        // `loading` chứ không `ready`: ba số đếm và danh sách vừa trở nên cũ, và
        // một state nói "xong" trong lúc chúng còn cũ là một state nói dối —
        // giao diện sẽ vẽ kết quả của lần chạy **trước** kèm câu tổng kết của
        // lần chạy này.
        emit(
          state.copyWith(
            status: LoadStatus.loading,
            runPhase: ReconciliationRunPhase.idle,
            clearProgress: true,
            lastRun: value,
            group: ReconciliationGroup.pending,
            notice: _notices.of(_runSummaryOf(value)),
          ),
        );
        await _reloadCounts(emit);
        await _reloadGroup(emit);
    }
  }

  void _onRunDismissed(
    ReconciliationRunDismissed event,
    Emitter<ReconciliationState> emit,
  ) {
    if (state.runPhase != ReconciliationRunPhase.awaitingConfirmation) return;
    emit(state.copyWith(runPhase: ReconciliationRunPhase.idle));
  }

  void _onRunCancelled(
    ReconciliationRunCancelled event,
    Emitter<ReconciliationState> emit,
  ) {
    if (state.runPhase != ReconciliationRunPhase.running) return;
    _cancellation?.cancel();
    // Trạng thái riêng thay vì quay thẳng về `idle`: lô đang chạy chưa dừng, và
    // hiện "đã dừng" ngay lúc này là nói dối trong quãng còn lại của lô (UC-14).
    emit(state.copyWith(runPhase: ReconciliationRunPhase.cancelling));
  }

  Future<void> _onPairConfirmed(
    ReconciliationPairConfirmed event,
    Emitter<ReconciliationState> emit,
  ) async {
    // Lượt quét đang dựng lại chính danh sách này; một phán quyết chen vào giữa
    // sẽ bị lượt đọc lại của nó ghi đè, và dòng vừa xử lý hiện ra trở lại.
    if (state.isRunning) return;
    final result = await _confirm.execute(event.pairId);
    switch (result) {
      case Err<ReconciliationPair>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'cặp đối soát')));
      case Ok<ReconciliationPair>():
        emit(
          state.copyWith(
            status: LoadStatus.loading,
            notice: _notices.success('Đã xác nhận cặp đối soát.'),
            clearUndoableRejection: true,
          ),
        );
        await _afterVerdict(event.pairId, emit);
    }
  }

  Future<void> _onPairRejected(
    ReconciliationPairRejected event,
    Emitter<ReconciliationState> emit,
  ) async {
    if (state.isRunning) return;
    final result = await _reject.execute(event.pairId);
    switch (result) {
      case Err<RejectedMatch>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'cặp đối soát')));
      case Ok<RejectedMatch>(:final value):
        emit(
          state.copyWith(
            // Phán quyết được ghi nhớ và cặp này sẽ **không** được gợi ý lại ở
            // các lần chạy sau — snackbar phải nói ra điều đó, vì đó mới là hệ
            // quả lâu dài của một cú bấm trông như chỉ xoá một dòng (UC-09).
            status: LoadStatus.loading,
            notice: _notices.info(
              'Đã ghi nhận từ chối. Cặp này sẽ không được gợi ý lại.',
            ),
            undoableRejectionId: value.rejectedMatchId,
          ),
        );
        await _afterVerdict(event.pairId, emit);
    }
  }

  Future<void> _onRejectionUndone(
    ReconciliationRejectionUndone event,
    Emitter<ReconciliationState> emit,
  ) async {
    final result = await _reject.undo(event.rejectedMatchId);
    switch (result) {
      case Err<void>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'phán quyết từ chối')));
      case Ok<void>():
        emit(
          state.copyWith(
            // Gỡ phán quyết **không** dựng lại cặp: cặp đã bị xoá lúc từ chối, và
            // nó chỉ quay lại làm ứng viên ở lần chạy đối soát kế tiếp (UC-09
            // bước 5). Nói đúng điều đó tránh việc người dùng đi tìm một dòng
            // vừa "được khôi phục" mà không có ở đâu cả.
            status: LoadStatus.loading,
            notice: _notices.success(
              'Đã gỡ phán quyết. Cặp này sẽ được xét lại ở lần chạy đối soát '
              'kế tiếp.',
            ),
            clearUndoableRejection: true,
          ),
        );
        await _reloadCounts(emit);
        await _reloadGroup(emit);
    }
  }

  Future<void> _onMatchWindowChanged(
    ReconciliationMatchWindowChanged event,
    Emitter<ReconciliationState> emit,
  ) async {
    final result = await _run.setMatchWindow(event.days);
    switch (result) {
      case Err<MatchWindow>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'ngưỡng lệch')));
      case Ok<MatchWindow>(:final value):
        emit(
          state.copyWith(
            matchWindowDays: value.days,
            notice: _notices.info(
              'Ngưỡng lệch mới chỉ áp dụng cho lần chạy sau; các cặp đã xác '
              'nhận không bị đụng tới.',
            ),
          ),
        );
    }
  }

  /// Sau một phán quyết: cặp đó biến mất khỏi danh sách đang xem (xác nhận thì
  /// chuyển nhóm, từ chối thì bị xoá hẳn), nên gỡ nó ngay tại chỗ rồi đọc lại
  /// các con số.
  ///
  /// Gỡ tại chỗ **trước** khi đọc lại là có chủ đích: người dùng vừa vuốt một
  /// thẻ đi và phải thấy nó đi ngay, không phải chờ một lượt truy vấn.
  Future<void> _afterVerdict(int pairId, Emitter<ReconciliationState> emit) async {
    emit(
      state.copyWith(
        pairs: <PairRowViewModel>[
          for (final row in state.pairs)
            if (row.pairId != pairId) row,
        ],
        openPairId: state.openPairId == pairId ? null : state.openPairId,
        clearOpenPair: state.openPairId == pairId,
        clearDetail: state.openPairId == pairId,
      ),
    );
    await _reloadCounts(emit);
    if (state.group == ReconciliationGroup.rejected) {
      // Nhóm *Đã từ chối* được nạp trọn cùng các số đếm, nên `_reloadGroup` ở
      // đây chỉ còn việc đặt lại trạng thái và dọn danh sách cặp.
      await _reloadGroup(emit);
    } else {
      emit(state.copyWith(status: LoadStatus.ready));
    }
  }

  Future<void> _openPair(int pairId, Emitter<ReconciliationState> emit) async {
    emit(state.copyWith(openPairId: pairId, detailStatus: LoadStatus.loading));
    final result = await _list.alternativesForPair(pairId);
    switch (result) {
      case Err<MatchAlternativesView>(:final failure):
        emit(
          state.copyWith(
            detailStatus: LoadStatus.failed,
            clearDetail: true,
            notice: _noticeOf(failure, 'cặp đối soát'),
          ),
        );
      case Ok<MatchAlternativesView>(:final value):
        emit(
          state.copyWith(
            detailStatus: LoadStatus.ready,
            detail: PairDetailViewModel.of(value, accountNames: _accountNames),
          ),
        );
    }
  }

  /// Đọc lại ba số đếm của Segmented Control.
  Future<void> _reloadCounts(Emitter<ReconciliationState> emit) async {
    final suggested = await _list.pairs(
      status: ReconciliationGroup.pending.pairStatus,
      limit: 1,
      offset: 0,
    );
    final confirmed = await _list.pairs(
      status: ReconciliationGroup.confirmed.pairStatus,
      limit: 1,
      offset: 0,
    );
    final rejected = await _loadRejected();

    emit(
      state.copyWith(
        pendingCount: suggested.valueOrNull?.totalCount ?? state.pendingCount,
        confirmedCount:
            confirmed.valueOrNull?.totalCount ?? state.confirmedCount,
        rejectedCount: rejected.rows.length,
        rejectedCountIsCapped: rejected.isCapped,
        rejected: rejected.rows,
      ),
    );
  }

  /// Đọc lại trang đầu của nhóm đang chọn.
  Future<void> _reloadGroup(Emitter<ReconciliationState> emit) async {
    if (state.group == ReconciliationGroup.rejected) {
      // Danh sách từ chối đã được nạp trọn cùng với các số đếm; nó không có
      // trang thứ hai để đọc.
      emit(
        state.copyWith(
          status: LoadStatus.ready,
          pairs: const <PairRowViewModel>[],
          hasMore: false,
          isLoadingMore: false,
        ),
      );
      return;
    }

    emit(state.copyWith(status: LoadStatus.loading, clearLoadError: true));
    final page = await _list.pairs(
      status: state.group.pairStatus,
      limit: pageSize,
      offset: 0,
    );
    switch (page) {
      case Err<PairsPage>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            loadError: FailurePresenter.of(failure, context: 'cặp đối soát'),
          ),
        );
      case Ok<PairsPage>(:final value):
        final rows = <PairRowViewModel>[
          for (final view in value.items) PairRowViewModel.of(view),
        ];
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            pairs: rows,
            hasMore: rows.length < value.totalCount && value.items.isNotEmpty,
            isLoadingMore: false,
          ),
        );
    }
  }

  /// Nạp trọn nhóm *Đã từ chối*, có trần.
  ///
  /// Trả kèm việc đã **chạm trần hay chưa**: số đếm trên Segmented Control đến
  /// từ chính danh sách này, nên nếu vòng lặp dừng vì trần chứ vì hết dữ liệu
  /// thì con số ấy là cận dưới, và giao diện phải nói ra điều đó.
  Future<({List<RejectedRowViewModel> rows, bool isCapped})>
  _loadRejected() async {
    final rows = <RejectedRowViewModel>[];
    var offset = 0;
    var isCapped = false;
    while (true) {
      if (rows.length >= maxRejectedRows) {
        isCapped = true;
        break;
      }
      final page = await _list.rejected(limit: pageSize, offset: offset);
      final value = page.valueOrNull;
      if (value == null) break;
      for (final view in value.items) {
        rows.add(
          RejectedRowViewModel.of(view, accountNames: _accountNames),
        );
      }
      offset += value.items.length;
      if (!value.hasMore) break;
    }
    return (rows: rows, isCapped: isCapped);
  }

  Future<Map<int, String>> _loadAccountNames() async {
    final result = await _accounts.list();
    return <int, String>{
      for (final account in result.valueOrNull ?? const [])
        if (account.accountId != null) account.accountId!: account.displayName,
    };
  }

  /// Câu tổng kết một lần chạy.
  ///
  /// Huỷ và chạy xong là hai kết cục khác nhau và phải nói khác nhau: huỷ nghĩa
  /// là danh sách gợi ý chỉ có phần đã quét được, nên báo "tìm thấy N cặp" mà
  /// không nói đã dừng giữa chừng sẽ khiến người dùng tin N là con số cuối cùng.
  FeedbackMessage _runSummaryOf(RunReconciliationResult result) {
    if (result.wasCancelled) {
      return FeedbackMessage.info(
        'Đã dừng giữa chừng sau khi tìm được ${result.suggestedPairsFound} '
        'cặp. Chạy lại để quét trọn.',
      );
    }
    if (result.suggestedPairsFound == 0) {
      return const FeedbackMessage.info(
        'Không tìm thấy cặp chuyển khoản nội bộ nào. Thử nới ngưỡng lệch nếu '
        'hai sao kê ghi nhận lệch ngày.',
      );
    }
    return FeedbackMessage.success(
      'Tìm được ${result.suggestedPairsFound} cặp chờ quyết định.',
    );
  }

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}
