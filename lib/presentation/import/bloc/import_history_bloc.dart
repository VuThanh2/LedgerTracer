import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../application/import/revert_import/revert_import_dto.dart';
import '../../../application/import/revert_import/revert_import_use_case.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/formatting/number_formatter.dart';
import '../view_models/import_history_view_model.dart';
import 'import_history_event.dart';
import 'import_history_state.dart';

/// Tab *Lịch sử*: xem các lượt nhập và hoàn tác chúng (UC-03).
///
/// Hoàn tác là "xoá đúng những gì bản ghi đó đã thêm", và điều làm nó chính xác
/// được là liên kết nguồn gốc ở tầng dưới. Việc của BLoC này chỉ có hai: nói
/// trước hệ quả bằng con số, và **không** để một lần bấm thành một lần xoá.
///
/// Vì thế hoàn tác luôn đi hai nhịp — hỏi hệ quả rồi mới xin xác nhận. Đây là
/// thao tác phá huỷ không quay lui được, và nó chỉ trở nên an toàn khi con số
/// hiện ra **trước** cú bấm thứ hai chứ không phải sau cú bấm thứ nhất.
final class ImportHistoryBloc
    extends Bloc<ImportHistoryEvent, ImportHistoryState> {
  ImportHistoryBloc({
    required RevertImportUseCase revertImport,
    required ManageAccountsUseCase manageAccounts,
    this.pageSize = defaultPageSize,
  }) : _revert = revertImport,
       _accounts = manageAccounts,
       super(const ImportHistoryState()) {
    on<ImportHistoryStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    on<ImportHistoryNextPageRequested>(
      _onNextPage,
      transformer: EventTransformers.droppable(),
    );
    on<ImportHistorySessionToggled>(_onSessionToggled);
    on<ImportHistoryRevertRequested>(
      _onRevertRequested,
      transformer: EventTransformers.sequential(),
    );
    on<ImportHistoryRevertDismissed>(_onRevertDismissed);
    on<ImportHistoryRevertConfirmed>(
      _onRevertConfirmed,
      transformer: EventTransformers.sequential(),
    );
  }

  final RevertImportUseCase _revert;
  final ManageAccountsUseCase _accounts;
  final NoticeSink _notices = NoticeSink();

  Map<int, String> _accountNames = const <int, String>{};

  final int pageSize;

  static const int defaultPageSize = 20;

  Future<void> _onStarted(
    ImportHistoryStarted event,
    Emitter<ImportHistoryState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearLoadError: true));
    _accountNames = await _loadAccountNames();

    final page = await _revert.history(limit: pageSize, offset: 0);
    switch (page) {
      case Err<ImportHistoryPage>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            loadError: FailurePresenter.of(failure, context: 'import history'),
          ),
        );
      case Ok<ImportHistoryPage>(:final value):
        final sessions = _viewsOf(value);
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            sessions: sessions,
            totalCount: value.totalCount,
            hasMore:
                sessions.length < value.totalCount && value.sessions.isNotEmpty,
            isLoadingMore: false,
          ),
        );
    }
  }

  Future<void> _onNextPage(
    ImportHistoryNextPageRequested event,
    Emitter<ImportHistoryState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore || state.status.isLoading) return;
    emit(state.copyWith(isLoadingMore: true));

    final page = await _revert.history(
      limit: pageSize,
      offset: state.sessions.length,
    );
    switch (page) {
      case Err<ImportHistoryPage>(:final failure):
        emit(
          state.copyWith(
            isLoadingMore: false,
            loadError: FailurePresenter.of(failure, context: 'import history'),
          ),
        );
      case Ok<ImportHistoryPage>(:final value):
        final sessions = <ImportSessionViewModel>[
          ...state.sessions,
          ..._viewsOf(value),
        ];
        emit(
          state.copyWith(
            sessions: sessions,
            totalCount: value.totalCount,
            isLoadingMore: false,
            hasMore:
                sessions.length < value.totalCount && value.sessions.isNotEmpty,
          ),
        );
    }
  }

  void _onSessionToggled(
    ImportHistorySessionToggled event,
    Emitter<ImportHistoryState> emit,
  ) {
    final expanded = <int>{...state.expandedSessionIds};
    if (!expanded.remove(event.sessionId)) expanded.add(event.sessionId);
    emit(state.copyWith(expandedSessionIds: expanded));
  }

  Future<void> _onRevertRequested(
    ImportHistoryRevertRequested event,
    Emitter<ImportHistoryState> emit,
  ) async {
    final preview = switch (event.target) {
      RevertTarget.file => await _revert.previewFileRevert(event.id),
      RevertTarget.session => await _revert.previewSessionRevert(event.id),
    };
    switch (preview) {
      case Err<RevertImpact>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'import run')));
      case Ok<RevertImpact>(:final value):
        emit(
          state.copyWith(
            pendingRevert: RevertConfirmation(
              target: event.target,
              id: event.id,
              label: _labelOf(event.target, event.id),
              impact: _impactViewOf(value),
            ),
          ),
        );
    }
  }

  void _onRevertDismissed(
    ImportHistoryRevertDismissed event,
    Emitter<ImportHistoryState> emit,
  ) => emit(state.copyWith(clearPendingRevert: true));

  Future<void> _onRevertConfirmed(
    ImportHistoryRevertConfirmed event,
    Emitter<ImportHistoryState> emit,
  ) async {
    final pending = state.pendingRevert;
    if (pending == null || pending.isReverting) return;
    emit(state.copyWith(pendingRevert: pending.reverting()));

    final result = switch (pending.target) {
      RevertTarget.file => await _revert.revertFile(pending.id),
      RevertTarget.session => await _revert.revertSession(pending.id),
    };
    switch (result) {
      case Err<RevertImpact>(:final failure):
        emit(
          state.copyWith(
            clearPendingRevert: true,
            notice: _noticeOf(failure, 'import run'),
          ),
        );
      case Ok<RevertImpact>(:final value):
        emit(
          state.copyWith(
            clearPendingRevert: true,
            notice: _notices.success(_revertSummaryOf(value)),
          ),
        );
        // Đọc lại thay vì sửa tại chỗ: bản ghi vừa hoàn tác **ở lại** danh sách
        // với dấu hoàn tác, và dấu ấy cùng thời điểm của nó do tầng dưới ghi —
        // dựng lại chúng trong bộ nhớ là chép tay một sự thật đã có chỗ ở.
        add(const ImportHistoryStarted());
    }
  }

  List<ImportSessionViewModel> _viewsOf(ImportHistoryPage page) =>
      <ImportSessionViewModel>[
        for (final session in page.sessions)
          ImportSessionViewModel.of(session, accountNames: _accountNames),
      ];

  RevertImpactViewModel _impactViewOf(RevertImpact impact) =>
      RevertImpactViewModel(
        deletedTransactionText: NumberFormatter.count(
          impact.deletedTransactionCount,
        ),
        cancelledPairText: NumberFormatter.count(impact.cancelledPairCount),
        cancelledPairCount: impact.cancelledPairCount,
        hasManualEdits: impact.hasManualEdits,
      );

  String _revertSummaryOf(RevertImpact impact) {
    final rows = NumberFormatter.count(impact.deletedTransactionCount);
    if (impact.cancelledPairCount == 0) {
      return 'Reverted: $rows transactions removed.';
    }
    return 'Reverted: $rows transactions removed and '
        '${NumberFormatter.count(impact.cancelledPairCount)} reconciliation '
        'pairs dropped.';
  }

  String _labelOf(RevertTarget target, int id) {
    for (final session in state.sessions) {
      if (target == RevertTarget.session && session.sessionId == id) {
        return 'the import run of ${session.startedAtText}';
      }
      for (final file in session.files) {
        if (target == RevertTarget.file && file.recordId == id) {
          return 'file "${file.fileName}"';
        }
      }
    }
    return 'this record';
  }

  Future<Map<int, String>> _loadAccountNames() async {
    final result = await _accounts.list();
    return <int, String>{
      for (final account in result.valueOrNull ?? const [])
        if (account.accountId != null) account.accountId!: account.displayName,
    };
  }

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}
