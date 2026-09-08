import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/formatting/number_formatter.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/filter_chip_bar.dart';
import '../shell/bloc/app_shell_bloc.dart';
import '../shell/bloc/app_shell_event.dart';
import '../shell/view_models/navigation_intent.dart';
import 'bloc/transactions_bloc.dart';
import 'bloc/transactions_event.dart';
import 'bloc/transactions_state.dart';
import 'transaction_detail_page.dart';
import 'transaction_edit_page.dart';
import 'view_models/filter_chip_view_model.dart';
import 'view_models/transaction_row_view_model.dart';
import 'widgets/delete_transaction_dialog.dart';
import 'widgets/filter_panel.dart';
import 'widgets/transaction_detail_pane.dart';
import 'widgets/transaction_list_view.dart';
import 'widgets/transaction_search_field.dart';

/// Màn hình chính của ứng dụng (UC-04, UC-06, UC-07).
///
/// Ba hình thái theo breakpoint, cùng một trạng thái:
/// * Expanded — danh sách ở giữa, panel lọc **hoặc** pane chi tiết bên phải;
/// * Medium — như trên nhưng rail thu gọn;
/// * Compact — danh sách dạng card, bộ lọc là bottom sheet, chi tiết là route.
///
/// Panel lọc và pane chi tiết không mở cùng lúc dù màn có đủ chỗ: cả hai đều là
/// "cột thứ hai", và mở cả hai đẩy bảng — thứ người dùng đang đọc — xuống còn
/// một dải hẹp.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  /// Panel lọc là trạng thái của khung nhìn, không phải của dữ liệu, nên nó
  /// không thuộc về BLoC: đóng panel lại không đổi thứ gì trong tập kết quả.
  bool _filterOpen = false;

  void _openFilterSheet(BuildContext context) {
    final bloc = context.read<TransactionsBloc>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => BlocProvider<TransactionsBloc>.value(
        value: bloc,
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: BlocBuilder<TransactionsBloc, TransactionsState>(
            builder: (context, state) => FilterPanel(
              state: state,
              onDraftChanged: (draft) => context.read<TransactionsBloc>().add(
                TransactionsFilterDraftChanged(draft),
              ),
              onApply: () {
                context.read<TransactionsBloc>().add(
                  const TransactionsFilterApplied(),
                );
                Navigator.of(context).pop();
              },
              onClear: () => context.read<TransactionsBloc>().add(
                const TransactionsFilterCleared(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _select(
    BuildContext context,
    TransactionRowViewModel row,
    WindowSizeClass sizeClass,
  ) async {
    final bloc = context.read<TransactionsBloc>()
      ..add(TransactionSelected(row.transactionId));
    if (sizeClass.usesTwoPane) {
      setState(() => _filterOpen = false);
      return;
    }
    await Navigator.of(context).push(TransactionDetailPage.route(context));
    // Rời màn chi tiết là bỏ chọn: ở Compact không có gì trên màn hình biểu
    // diễn "dòng đang chọn", nên giữ lại lựa chọn chỉ tạo trạng thái vô hình.
    bloc.add(const TransactionSelected(null));
  }

  Future<void> _openEditor(BuildContext context, int transactionId) async {
    final bloc = context.read<TransactionsBloc>();
    final saved = await Navigator.of(context)
        .push(TransactionEditPage.route(context, transactionId));
    if (saved ?? false) {
      bloc.add(TransactionsInvalidated(changedTransactionId: transactionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return BlocConsumer<TransactionsBloc, TransactionsState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice ||
          (previous.pendingDelete == null && current.pendingDelete != null),
      listener: (context, state) {
        if (state.pendingDelete != null) {
          // Ở Compact, màn chi tiết được đẩy chồng lên trang này và trang này
          // vẫn còn trong cây, nên cả hai đều nghe thấy cùng một `pendingDelete`.
          // Chỉ route đang ở trên cùng được mở hộp thoại; nếu không, người dùng
          // nhận hai hộp thoại xoá chồng nhau cho một lần bấm.
          if (ModalRoute.of(context)?.isCurrent ?? true) {
            DeleteTransactionDialog.show(context);
          }
          return;
        }
        if (state.notice case final notice?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice.message.text)));
        }
      },
      builder: (context, state) {
        final showDetail =
            sizeClass.usesTwoPane && state.detail != null && !_filterOpen;
        final showFilter = sizeClass.usesFilterPanel && _filterOpen;

        return Row(
          children: <Widget>[
            Expanded(
              child: Column(
                children: <Widget>[
                  _SearchHeader(
                    state: state,
                    filterOpen: _filterOpen,
                    onKeywordChanged: (value) => context
                        .read<TransactionsBloc>()
                        .add(TransactionsKeywordChanged(value)),
                    onToggleFilter: () {
                      if (sizeClass.usesFilterPanel) {
                        setState(() => _filterOpen = !_filterOpen);
                      } else {
                        _openFilterSheet(context);
                      }
                    },
                    onRemoveChip: (kind) => context
                        .read<TransactionsBloc>()
                        .add(TransactionsChipRemoved(kind)),
                  ),
                  if (state.loadError case final FeedbackMessage error)
                    Padding(
                      padding: const EdgeInsets.all(Gap.screen),
                      child: BannerMessage(error),
                    ),
                  Expanded(
                    child: state.status.isInitial
                        ? const Center(child: CircularProgressIndicator())
                        : TransactionListView(
                            state: state,
                            onSelect: (row) => _select(context, row, sizeClass),
                            onLoadMore: () => context
                                .read<TransactionsBloc>()
                                .add(const TransactionsNextPageRequested()),
                            onRefresh: () => context
                                .read<TransactionsBloc>()
                                .add(const TransactionsRefreshed()),
                            onClearFilters: () => context
                                .read<TransactionsBloc>()
                                .add(const TransactionsFilterCleared()),
                            onGoToImport: () =>
                                context.read<AppShellBloc>().add(
                                  const AppShellNavigationRequested(
                                    OpenImport(),
                                  ),
                                ),
                          ),
                  ),
                ],
              ),
            ),
            if (showFilter)
              _SidePanel(
                width: FilterPanel.panelWidth,
                child: FilterPanel(
                  state: state,
                  onDraftChanged: (draft) => context
                      .read<TransactionsBloc>()
                      .add(TransactionsFilterDraftChanged(draft)),
                  onApply: () => context.read<TransactionsBloc>().add(
                    const TransactionsFilterApplied(),
                  ),
                  onClear: () => context.read<TransactionsBloc>().add(
                    const TransactionsFilterCleared(),
                  ),
                  onClose: () => setState(() => _filterOpen = false),
                ),
              ),
            if (showDetail)
              _SidePanel(
                width: TransactionDetailPane.paneWidth,
                child: TransactionDetailPane(
                  detail: state.detail!,
                  onEdit: () =>
                      _openEditor(context, state.detail!.transactionId),
                  onDelete: () => context.read<TransactionsBloc>().add(
                    TransactionDeleteRequested(state.detail!.transactionId),
                  ),
                  onOpenReconciliation: () => context.read<AppShellBloc>().add(
                    const AppShellNavigationRequested(OpenReconciliation()),
                  ),
                  onClose: () => context.read<TransactionsBloc>().add(
                    const TransactionSelected(null),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SidePanel extends StatelessWidget {
  const _SidePanel({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(left: BorderSide(color: colors.hairline)),
      ),
      child: child,
    );
  }
}

/// Ô tìm kiếm, nút bộ lọc, và dải chip — ba thứ mô tả "đang xem tập nào".
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.state,
    required this.filterOpen,
    required this.onKeywordChanged,
    required this.onToggleFilter,
    required this.onRemoveChip,
  });

  final TransactionsState state;
  final bool filterOpen;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback onToggleFilter;
  final ValueChanged<FilterChipKind> onRemoveChip;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.screen,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TransactionSearchField(
                  keyword: state.keyword,
                  onChanged: onKeywordChanged,
                ),
              ),
              const SizedBox(width: Gap.sm),
              _FilterButton(
                active: filterOpen || !state.filter.isEmpty,
                onPressed: onToggleFilter,
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FilterChipBar(
            chips: state.chips,
            onRemove: onRemoveChip,
            trailing: Text(
              _countLabelOf(state),
              style: LedgerText.caption.copyWith(color: colors.inkMute),
            ),
          ),
        ],
      ),
    );
  }

  /// "Đã tải / tổng khớp".
  ///
  /// Cả hai con số nói về cùng một tập, vì bộ lọc lẫn ngữ cảnh cùng đi xuống một
  /// truy vấn — người dùng ở đây đối chiếu sổ sách và sẽ đem con số này đi so,
  /// nên nó phải là con số đúng chứ không phải một ước lượng.
  static String _countLabelOf(TransactionsState state) {
    if (!state.status.isReady) return 'Loading…';
    return '${NumberFormatter.count(state.visibleCount)} / '
        '${NumberFormatter.count(state.totalCount)} transactions';
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? colors.primaryWash : colors.canvas,
        foregroundColor: active ? colors.primaryDeep : colors.inkSecondary,
        side: BorderSide(
          color: active ? colors.primary : colors.hairlineControl,
        ),
        textStyle: LedgerText.micro,
        shape: Corner.pillBorder,
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        minimumSize: const Size(0, 40),
      ),
      icon: const Icon(Icons.tune, size: 14),
      label: const Text('Filters'),
    );
  }
}
