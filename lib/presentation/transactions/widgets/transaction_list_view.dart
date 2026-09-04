import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/widgets/empty_state.dart';
import '../bloc/transactions_state.dart';
import '../view_models/transaction_row_view_model.dart';
import 'transaction_row_tile.dart';

/// Danh sách giao dịch, cuộn lười, đổi hình thái theo breakpoint.
///
/// Luôn dựng bằng `ListView.builder`: danh sách ở đây đo bằng hàng trăm nghìn
/// dòng, nên dựng sẵn toàn bộ là cách chắc chắn nhất để làm hỏng chính thứ mà
/// ứng dụng này lấy làm đề tài.
///
/// Trang kế tiếp được xin **trước khi** người dùng chạm đáy: chờ tới đáy rồi mới
/// gọi nghĩa là mỗi lần cuộn nhanh đều dừng lại chờ đọc đĩa.
class TransactionListView extends StatefulWidget {
  const TransactionListView({
    required this.state,
    required this.onSelect,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onClearFilters,
    required this.onGoToImport,
    super.key,
  });

  final TransactionsState state;
  final ValueChanged<TransactionRowViewModel> onSelect;
  final VoidCallback onLoadMore;

  /// Nạp lại trang đầu, giữ nguyên bộ lọc và ngữ cảnh đang áp dụng.
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;
  final VoidCallback onGoToImport;

  /// Còn cách đáy bao nhiêu pixel thì xin trang kế tiếp.
  static const double loadMoreThreshold = 480;

  @override
  State<TransactionListView> createState() => _TransactionListViewState();
}

class _TransactionListViewState extends State<TransactionListView> {
  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (!widget.state.hasMore || widget.state.isLoadingMore) return false;
    final remaining =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (remaining <= TransactionListView.loadMoreThreshold) {
      widget.onLoadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final state = widget.state;
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    if (state.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.screen),
        child: state.isNarrowed
            ? EmptyState(
                title: 'No transactions match',
                message:
                    'Clear a filter, or import a statement file to bring more '
                    'data in.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Clear all filters',
                onAction: widget.onClearFilters,
              )
            : EmptyState(
                title: 'No transactions yet',
                message: 'Import a statement file to get started.',
                icon: Icons.receipt_long_outlined,
                actionLabel: 'Go to Import',
                onAction: widget.onGoToImport,
              ),
      );
    }

    final isTable = !sizeClass.usesBottomNavigation;
    // Một mục phụ ở cuối khi còn trang sau, để chỗ cho chỉ báo đang nạp.
    final itemCount = state.rows.length + (state.hasMore ? 1 : 0);

    final list = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: ListView.separated(
        padding: isTable
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(Gap.screen, Gap.sm, Gap.screen, Gap.xl),
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            SizedBox(height: isTable ? 0 : Gap.sm),
        itemBuilder: (context, index) {
          if (index >= state.rows.length) return const _LoadingMoreRow();
          final row = state.rows[index];
          final selected = row.transactionId == state.selectedId;
          return isTable
              ? TransactionRowTile(
                  row: row,
                  index: index,
                  selected: selected,
                  onTap: () => widget.onSelect(row),
                )
              : TransactionCardTile(
                  row: row,
                  selected: selected,
                  onTap: () => widget.onSelect(row),
                );
        },
      ),
    );

    // Kéo-để-tải-lại trên cả hai hình thái. Danh sách này cũ đi vì việc xảy ra ở
    // màn khác — một lượt nhập vừa xong, một lượt hoàn tác ở Lịch sử — nên phải
    // có một cách nạp lại mà không cần rời màn hình. Trên web cử chỉ kéo không
    // tự nhiên, nhưng `RefreshIndicator` vẫn dùng được bằng chuột và không thêm
    // chrome nào khi không kéo.
    final refreshable = RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      color: colors.primary,
      backgroundColor: colors.canvas,
      child: list,
    );

    if (!isTable) {
      return ColoredBox(color: colors.canvasSoft, child: refreshable);
    }

    return Column(
      children: <Widget>[
        const TransactionTableHeader(),
        Expanded(
          child: ColoredBox(color: colors.canvasSoft, child: refreshable),
        ),
      ],
    );
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: Gap.lg),
    child: Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
