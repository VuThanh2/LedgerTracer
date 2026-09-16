import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../shared/export/view_models/export_source.dart';
import '../../shared/export/widgets/export_dialog.dart';
import '../../shared/responsive/breakpoints.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_state.dart';

/// Nút mở hộp thoại xuất dữ liệu cho **tập giao dịch đang hiển thị**.
///
/// Sống ở một file riêng vì nó có hai chỗ đứng tuỳ bề rộng: cạnh nút bộ lọc
/// trong thanh công cụ ở bản rộng, và trên app bar ở bản hẹp. Hai chỗ nhưng một
/// widget — dựng hai bản sao là cách hai nút cùng tên dần dần xuất ra hai tập
/// khác nhau.
///
/// Nút đọc thẳng [TransactionsState] thay vì nhận tham số: thứ nó xuất ra phải
/// là đúng thứ danh sách đang cho xem, và một tham số truyền tay là một cơ hội
/// để hai bên lệch nhau.
class ExportTransactionsButton extends StatelessWidget {
  const ExportTransactionsButton({required this.iconOnly, super.key});

  /// Thu về một icon khi chỗ đứng không đủ rộng cho nhãn.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return BlocBuilder<TransactionsBloc, TransactionsState>(
      buildWhen: (previous, current) =>
          previous.status != current.status || previous.chips != current.chips,
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
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.primary),
            textStyle: LedgerText.bodySm,
            shape: Corner.pillBorder,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            minimumSize: Size(0, sizeClass.controlHeight),
          ),
          icon: const Icon(Icons.file_download_outlined, size: 16),
          label: const Text('Export'),
        );
      },
    );
  }
}
