import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/router.dart';
import '../../app/theme.dart';
import '../../domain/value_objects/pair_status.dart';
import '../import/bloc/import_bloc.dart';
import '../import/bloc/import_state.dart';
import '../import/import_page.dart';
import '../reconciliation/bloc/reconciliation_bloc.dart';
import '../reconciliation/bloc/reconciliation_event.dart';
import '../reconciliation/bloc/reconciliation_state.dart';
import '../reconciliation/reconciliation_page.dart';
import '../reconciliation/view_models/reconciliation_group.dart';
import '../shared/export/view_models/export_source.dart';
import '../shared/export/widgets/export_dialog.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/frame_pulse.dart';
import '../statistics/bloc/statistics_bloc.dart';
import '../statistics/bloc/statistics_event.dart';
import '../statistics/statistics_page.dart';
import '../transactions/bloc/transactions_bloc.dart';
import '../transactions/bloc/transactions_event.dart';
import '../transactions/bloc/transactions_state.dart';
import '../transactions/transactions_page.dart';
import 'bloc/app_shell_bloc.dart';
import 'bloc/app_shell_event.dart';
import 'bloc/app_shell_state.dart';
import 'view_models/navigation_intent.dart';
import 'widgets/nav_bar.dart';
import 'widgets/nav_rail.dart';

/// Khung điều hướng bao ngoài bốn màn hình hằng ngày.
///
/// Bốn trang nằm trong một [IndexedStack] chứ không dựng lại theo tab: một lượt
/// nhập đang chạy phải sống sót khi người dùng sang tab khác — thiết kế yêu cầu
/// đúng điều đó, và app bar giữ một Frame Pulse thu nhỏ để họ vẫn thấy nó chạy.
///
/// Điều hướng mang ngữ cảnh (`NavigationIntent`) được tiêu thụ ở đây: mọi đường
/// đi giữa các màn đều đi qua một chỗ duy nhất, nên không màn nào phải biết cách
/// khởi động một màn khác.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Tab đã được khởi động lần đầu.
  ///
  /// Mỗi màn chỉ đọc dữ liệu khi người dùng thực sự mở nó: đọc sẵn cả bốn lúc
  /// khởi động là bốn truy vấn trên một cơ sở dữ liệu vài trăm nghìn dòng, ngay
  /// tại thời điểm ứng dụng cần khởi động nhanh nhất.
  final Set<NavDestination> _started = <NavDestination>{
    NavDestination.transactions,
  };

  @override
  void initState() {
    super.initState();
    context.read<AppShellBloc>().add(const AppShellStarted());
    context.read<TransactionsBloc>().add(const TransactionsStarted());
  }

  void _ensureStarted(NavDestination destination) {
    if (_started.contains(destination)) return;
    setState(() => _started.add(destination));
    switch (destination) {
      case NavDestination.transactions:
        context.read<TransactionsBloc>().add(const TransactionsStarted());
      case NavDestination.reconciliation:
        context.read<ReconciliationBloc>().add(const ReconciliationStarted());
      case NavDestination.statistics:
        context.read<StatisticsBloc>().add(const StatisticsStarted());
      case NavDestination.import:
        // `ImportBloc` tự nạp danh sách tài khoản ở `ImportStarted`, phát ra
        // ngay khi khung ứng dụng dựng lên, nên không có gì phải làm thêm.
        break;
    }
  }

  /// Tiêu thụ một ý định điều hướng: chuyển tab **và** truyền ngữ cảnh xuống
  /// đúng BLoC, để tập dữ liệu ở đích trùng với thứ người dùng vừa bấm.
  void _consume(PendingNavigation pending) {
    final intent = pending.intent;
    _ensureStarted(intent.destination);

    switch (intent) {
      case OpenTransactions(context: final query, :final draft):
        context.read<TransactionsBloc>().add(
          TransactionsStarted(context: query, draft: draft),
        );
      case OpenReconciliation(:final focusPairId, :final status):
        final bloc = context.read<ReconciliationBloc>();
        if (status case final PairStatus value) {
          bloc.add(ReconciliationGroupSelected(_groupOf(value)));
        }
        bloc.add(ReconciliationStarted(focusPairId: focusPairId));
      case OpenImport():
        break;
    }
    context.read<AppShellBloc>().add(const AppShellNavigationConsumed());
  }

  /// Nhóm phán quyết ứng với một [PairStatus].
  ///
  /// Ánh xạ chỉ đi được một chiều: nhóm "đã từ chối" không có [PairStatus] nào,
  /// vì cặp bị từ chối đã bị xoá khỏi bảng cặp.
  static ReconciliationGroup _groupOf(PairStatus status) => switch (status) {
    PairStatus.suggested => ReconciliationGroup.pending,
    PairStatus.confirmed => ReconciliationGroup.confirmed,
  };

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return BlocConsumer<AppShellBloc, AppShellState>(
      listenWhen: (previous, current) =>
          previous.pendingNavigation != current.pendingNavigation &&
          current.pendingNavigation != null,
      listener: (context, state) => _consume(state.pendingNavigation!),
      builder: (context, state) {
        final body = Column(
          children: <Widget>[
            if (state.recoveryNotice case final notice?)
              Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: BannerMessage(
                  notice,
                  onDismiss: () => context.read<AppShellBloc>().add(
                    const AppShellRecoveryNoticeDismissed(),
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: state.destination.index,
                children: <Widget>[
                  for (final destination in NavDestination.values)
                    _started.contains(destination)
                        ? _pageOf(destination)
                        : const SizedBox.shrink(),
                ],
              ),
            ),
          ],
        );

        return Scaffold(
          appBar: _ShellAppBar(
            destination: state.destination,
            compact: sizeClass.usesBottomNavigation,
          ),
          body: sizeClass.usesBottomNavigation
              ? body
              : Row(
                  children: <Widget>[
                    NavRail(
                      destination: state.destination,
                      showLabels: sizeClass.showsNavigationLabels,
                      onSelected: _select,
                      onSettings: () =>
                          Navigator.of(context)
                              .pushNamed(LedgerRoutes.settings),
                    ),
                    Expanded(child: body),
                  ],
                ),
          bottomNavigationBar: sizeClass.usesBottomNavigation
              ? NavBar(destination: state.destination, onSelected: _select)
              : null,
        );
      },
    );
  }

  /// Trang của một ô nav.
  ///
  /// [IndexedStack] dựng **mọi** con của nó, không chỉ con đang hiện. Nếu bốn
  /// trang đều dựng ngay từ đầu thì ba trang chưa được mở sẽ đứng ở trạng thái
  /// `initial` và quay vòng tròn chờ mãi — ba animation chạy liên tục sau lưng
  /// một bảng đang cuộn, đúng thứ mà ứng dụng này lấy làm đề tài. Trang chỉ được
  /// dựng khi người dùng thực sự mở nó, và từ đó ở lại để lượt nhập đang chạy
  /// không bị dựng lại.
  Widget _pageOf(NavDestination destination) => switch (destination) {
    NavDestination.transactions => const TransactionsPage(),
    NavDestination.import => const ImportPage(),
    NavDestination.reconciliation => const ReconciliationPage(),
    NavDestination.statistics => const StatisticsPage(),
  };

  void _select(NavDestination destination) {
    _ensureStarted(destination);
    context.read<AppShellBloc>().add(AppShellDestinationSelected(destination));
  }
}

/// App bar của khung: tiêu đề, chỉ báo tác vụ nền, và các hành động của tab.
class _ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ShellAppBar({required this.destination, required this.compact});

  final NavDestination destination;

  /// Ở Compact, bánh răng Cài đặt nằm ở app bar (rail không tồn tại), và nhãn
  /// tiến độ bị lược đi — chỉ còn dải vạch, vì bề rộng ở đó không đủ cho cả tiêu
  /// đề lẫn một câu chữ.
  final bool compact;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) => AppBar(
    title: Row(
      children: <Widget>[
        Flexible(
          child: Text(destination.label, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: Gap.md),
        _BackgroundWorkIndicator(showLabel: !compact),
      ],
    ),
    actions: <Widget>[
      if (destination == NavDestination.transactions)
        Padding(
          padding: const EdgeInsets.only(right: Gap.sm),
          child: _ExportTransactionsButton(iconOnly: compact),
        ),
      if (compact)
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          onPressed: () =>
              Navigator.of(context).pushNamed(LedgerRoutes.settings),
        ),
      const SizedBox(width: Gap.sm),
    ],
  );
}

/// Frame Pulse thu nhỏ trên app bar khi một tác vụ nền đang chạy.
///
/// Người dùng được phép rời tab trong lúc nhập hoặc quét, nên phải có một chỗ
/// nói rằng việc đó chưa xong. Sáu vạch thay vì mười hai: nó là lời nhắc, không
/// phải chỉ báo chính.
class _BackgroundWorkIndicator extends StatelessWidget {
  const _BackgroundWorkIndicator({required this.showLabel});

  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return BlocBuilder<ImportBloc, ImportState>(
      buildWhen: (previous, current) =>
          previous.isRunning != current.isRunning ||
          previous.progress?.processedTotalText !=
              current.progress?.processedTotalText,
      builder: (context, importState) =>
          BlocBuilder<ReconciliationBloc, ReconciliationState>(
            buildWhen: (previous, current) =>
                previous.isRunning != current.isRunning,
            builder: (context, reconciliationState) {
              final busy =
                  importState.isRunning || reconciliationState.isRunning;
              if (!busy) return const SizedBox.shrink();

              final label = importState.isRunning
                  ? 'Importing ${importState.progress?.processedTotalText ?? ''}'
                  : 'Scanning for internal transfers';
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Tooltip(message: label, child: const FramePulse.compact()),
                  if (showLabel) ...<Widget>[
                    const SizedBox(width: Gap.sm),
                    Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: LedgerText.caption.copyWith(color: colors.inkMute),
                    ),
                  ],
                ],
              );
            },
          ),
    );
  }
}

class _ExportTransactionsButton extends StatelessWidget {
  const _ExportTransactionsButton({required this.iconOnly});

  final bool iconOnly;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TransactionsBloc, TransactionsState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.chips != current.chips,
        builder: (context, state) {
          void open() => ExportDialog.open(
            context,
            ExportTransactionsSource(
              filter: state.filter,
              context: state.context,
              chips: state.chips,
            ),
          );
          final onPressed = state.status.isReady ? open : null;

          if (iconOnly) {
            return IconButton(
              tooltip: 'Export transactions',
              icon: const Icon(Icons.file_download_outlined),
              onPressed: onPressed,
            );
          }
          return OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Export'),
          );
        },
      );
}
