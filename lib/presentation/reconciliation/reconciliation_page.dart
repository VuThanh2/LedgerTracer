import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../shared/export/view_models/export_source.dart';
import '../shared/export/widgets/export_dialog.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/formatting/number_formatter.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/confirm_dialog.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/progress_panel.dart';
import '../shared/widgets/section_card.dart';
import '../shared/widgets/web_limitation_banner.dart';
import '../shell/bloc/app_shell_bloc.dart';
import '../shell/bloc/app_shell_event.dart';
import '../shell/view_models/navigation_intent.dart';
import 'bloc/reconciliation_bloc.dart';
import 'bloc/reconciliation_event.dart';
import 'bloc/reconciliation_state.dart';
import 'view_models/reconciliation_group.dart';
import 'widgets/match_window_control.dart';
import 'widgets/pair_swipe_card.dart';
import 'widgets/pair_table.dart';
import 'widgets/rejected_list.dart';
import 'widgets/verdict_segmented_control.dart';

/// Màn Đối soát: chạy quét và duyệt kết quả trên cùng một màn (UC-08, UC-09).
///
/// Một màn chứ không hai, vì hai việc ấy đan vào nhau: người dùng nới cửa sổ
/// ghép cặp *vì* danh sách trước còn thiếu, và chạy lại *sau khi* đã duyệt xong
/// nhóm gợi ý. Tách ra thì mọi vòng lặp đó thành một chuyến đi lại giữa hai màn.
class ReconciliationPage extends StatefulWidget {
  const ReconciliationPage({super.key});

  @override
  State<ReconciliationPage> createState() => _ReconciliationPageState();
}

class _ReconciliationPageState extends State<ReconciliationPage> {
  bool _onScroll(ScrollNotification notification, ReconciliationState state) {
    if (!state.hasMore || state.isLoadingMore) return false;
    final remaining =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (remaining <= 400) {
      context.read<ReconciliationBloc>().add(
        const ReconciliationNextPageRequested(),
      );
    }
    return false;
  }

  /// Cảnh báo trước khi chạy lại: mọi cặp còn chờ quyết định sẽ bị xoá và dựng
  /// lại từ đầu. Đó là công người dùng đã bỏ ra để đọc từng cặp, nên nó không
  /// được biến mất trong im lặng.
  Future<void> _requestRun(
    BuildContext context,
    ReconciliationState state,
  ) async {
    final bloc = context.read<ReconciliationBloc>();
    if (!state.runWouldClearPending) {
      bloc.add(const ReconciliationRunRequested());
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: 'Run the scan again?',
      body: 'Pairs you have already confirmed or rejected are kept.',
      consequence: FeedbackMessage.danger(
        'Every one of the ${NumberFormatter.count(state.pendingCount)} pairs '
        'still awaiting a decision is discarded and rebuilt from scratch.',
      ),
      confirmLabel: 'Run scan',
      cancelLabel: 'Cancel',
    );
    if (!confirmed) {
      bloc.add(const ReconciliationRunDismissed());
      return;
    }
    bloc.add(
      const ReconciliationRunRequested(acknowledgedClearingPending: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return BlocConsumer<ReconciliationBloc, ReconciliationState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        final notice = state.notice;
        if (notice == null) return;
        final undoable = state.undoableRejectionId;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(notice.message.text),
              duration: const Duration(seconds: 6),
              action: undoable == null
                  ? null
                  : SnackBarAction(
                      label: 'Undo',
                      onPressed: () => context.read<ReconciliationBloc>().add(
                        ReconciliationRejectionUndone(undoable),
                      ),
                    ),
            ),
          );
      },
      builder: (context, state) {
        if (state.status.isInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!state.canRun && state.pairs.isEmpty && state.rejected.isEmpty) {
          return _NotEnoughAccounts(state: state);
        }

        return Column(
          children: <Widget>[
            _Toolbar(
              state: state,
              compact: sizeClass.usesBottomNavigation,
              onRun: () => _requestRun(context, state),
            ),
            if (state.isRunning)
              Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: Column(
                  children: <Widget>[
                    ProgressPanel(
                      label: _progressLabelOf(state),
                      fraction: state.progress?.fraction,
                      trailing: DestructiveButton(
                        label:
                            state.runPhase == ReconciliationRunPhase.cancelling
                            ? 'Cancelling…'
                            : 'Cancel',
                        onPressed:
                            state.runPhase == ReconciliationRunPhase.cancelling
                            ? null
                            : () => context.read<ReconciliationBloc>().add(
                                const ReconciliationRunCancelled(),
                              ),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    WebLimitationBanner(
                      supportsIsolates: state.supportsIsolates,
                    ),
                  ],
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) =>
                    _onScroll(notification, state),
                child: _GroupBody(state: state, sizeClass: sizeClass),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _progressLabelOf(ReconciliationState state) {
    final progress = state.progress;
    if (progress == null) return 'Preparing…';
    return '${NumberFormatter.count(progress.processed)} / '
        '${NumberFormatter.count(progress.total)} transactions scanned · '
        '${NumberFormatter.count(progress.pairsFound)} pairs found';
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.state,
    required this.compact,
    required this.onRun,
  });

  final ReconciliationState state;
  final bool compact;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final bloc = context.read<ReconciliationBloc>();

    final matchWindow = MatchWindowControl(
      days: state.matchWindowDays,
      enabled: !state.isRunning,
      onChanged: (days) => bloc.add(ReconciliationMatchWindowChanged(days)),
    );
    final segmented = VerdictSegmentedControl(
      state: state,
      expand: compact,
      onSelected: (group) => bloc.add(ReconciliationGroupSelected(group)),
    );
    final runButton = FilledButton(
      onPressed: state.isRunning ? null : onRun,
      child: const Text('Run scan'),
    );

    return Container(
      padding: const EdgeInsets.all(Gap.screen),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(children: <Widget>[matchWindow, const Spacer(), runButton]),
                const SizedBox(height: Gap.md),
                segmented,
              ],
            )
          : Row(
              children: <Widget>[
                matchWindow,
                const SizedBox(width: Gap.lg),
                Flexible(
                  child: Text(
                    'Applies to the next scan only. Confirmed pairs are never '
                    'touched.',
                    style: LedgerText.caption.copyWith(color: colors.inkMute),
                  ),
                ),
                const Spacer(),
                segmented,
                const SizedBox(width: Gap.md),
                runButton,
              ],
            ),
    );
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.state, required this.sizeClass});

  final ReconciliationState state;
  final WindowSizeClass sizeClass;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final bloc = context.read<ReconciliationBloc>();

    final isRejectedGroup = state.group == ReconciliationGroup.rejected;
    final isEmpty = isRejectedGroup
        ? state.rejected.isEmpty
        : state.pairs.isEmpty;

    return ColoredBox(
      color: colors.canvasSoft,
      child: ListView(
        padding: const EdgeInsets.all(Gap.screen),
        children: <Widget>[
          if (state.loadError case final FeedbackMessage error) ...<Widget>[
            BannerMessage(error),
            const SizedBox(height: Gap.lg),
          ],
          if (isEmpty)
            EmptyState(
              title: _emptyTitleOf(state.group),
              message: _emptyMessageOf(state.group),
              icon: switch (state.group) {
                ReconciliationGroup.pending => Icons.search_off,
                ReconciliationGroup.confirmed => Icons.check_circle_outline,
                ReconciliationGroup.rejected => Icons.block_outlined,
              },
            )
          else if (isRejectedGroup)
            RejectedList(
              state: state,
              onUndo: (id) => bloc.add(ReconciliationRejectionUndone(id)),
            )
          else if (sizeClass.usesBottomNavigation)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final pair in state.pairs) ...<Widget>[
                  PairSwipeCard(
                    pair: pair,
                    expanded: state.openPairId == pair.pairId,
                    detail: state.openPairId == pair.pairId
                        ? state.detail
                        : null,
                    detailLoading:
                        state.openPairId == pair.pairId &&
                        state.detailStatus.isLoading,
                    onToggleDetail: () => bloc.add(
                      ReconciliationPairOpened(
                        state.openPairId == pair.pairId ? null : pair.pairId,
                      ),
                    ),
                    onConfirm: () =>
                        bloc.add(ReconciliationPairConfirmed(pair.pairId)),
                    onReject: () =>
                        bloc.add(ReconciliationPairRejected(pair.pairId)),
                  ),
                  const SizedBox(height: Gap.md),
                ],
              ],
            )
          else
            PairTable(
              state: state,
              onToggleDetail: (pairId) =>
                  bloc.add(ReconciliationPairOpened(pairId)),
              onConfirm: (pairId) =>
                  bloc.add(ReconciliationPairConfirmed(pairId)),
              onReject: (pairId) =>
                  bloc.add(ReconciliationPairRejected(pairId)),
            ),
          if (state.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Gap.lg),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          const SizedBox(height: Gap.lg),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => ExportDialog.open(
                context,
                ExportReconciliationSource(
                  status: state.group.pairStatus,
                  groupLabel: state.group.label,
                ),
              ),
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text('Export this group'),
            ),
          ),
        ],
      ),
    );
  }

  static String _emptyTitleOf(ReconciliationGroup group) => switch (group) {
    ReconciliationGroup.pending => 'Nothing awaiting a decision',
    ReconciliationGroup.confirmed => 'No confirmed pairs yet',
    ReconciliationGroup.rejected => 'No rejections recorded',
  };

  static String _emptyMessageOf(ReconciliationGroup group) => switch (group) {
    ReconciliationGroup.pending =>
      'Run a scan to look for internal transfers across your accounts.',
    ReconciliationGroup.confirmed =>
      'Confirm a suggested pair and it will be listed here.',
    ReconciliationGroup.rejected =>
      'Rejections are kept forever, so the same pair is never suggested twice.',
  };
}

/// Chưa đủ hai tài khoản có giao dịch: thay nút Chạy bằng lời giải thích.
///
/// Đối soát nội bộ theo định nghĩa là ghép hai vế ở **hai tài khoản khác nhau**,
/// nên với một tài khoản thì nút Chạy không "tạm thời chưa dùng được" mà là vô
/// nghĩa. Ở đây nói thẳng điều kiện và dẫn tới việc làm cho nó đúng.
class _NotEnoughAccounts extends StatelessWidget {
  const _NotEnoughAccounts({required this.state});

  final ReconciliationState state;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(Gap.screen),
    child: Column(
      children: <Widget>[
        SectionCard(
          child: EmptyState(
            title: 'Reconciliation needs two accounts',
            message:
                'Only ${state.accountsWithTransactions} account holds '
                'transactions so far. An internal match is the same amount '
                'showing up in two different accounts, so two is the minimum.',
            icon: Icons.account_balance_outlined,
            actionLabel: 'Import more statements',
            onAction: () => context.read<AppShellBloc>().add(
              const AppShellNavigationRequested(OpenImport()),
            ),
          ),
        ),
      ],
    ),
  );
}
