import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../bloc/import_history_bloc.dart';
import '../bloc/import_history_event.dart';
import '../bloc/import_history_state.dart';

/// Xác nhận hoàn tác một file hoặc cả một lượt nhập (UC-03).
///
/// Hoàn tác không phải "xoá cái vừa làm": nó gỡ đúng những dòng do lượt nhập đó
/// ghi ra, kể cả khi sau đó người dùng đã sửa tay một vài dòng. Hai hệ quả phải
/// nói trước — số cặp đối soát bị huỷ, và việc các sửa tay sẽ mất theo — vì cả
/// hai đều nằm ngoài thứ người dùng đang nghĩ tới lúc bấm.
class RevertConfirmDialog extends StatelessWidget {
  const RevertConfirmDialog({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<ImportHistoryBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<ImportHistoryBloc>.value(
        value: bloc,
        child: const RevertConfirmDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ImportHistoryBloc, ImportHistoryState>(
        listenWhen: (previous, current) =>
            previous.pendingRevert != null && current.pendingRevert == null,
        listener: (context, state) => Navigator.of(context).maybePop(),
        builder: (context, state) {
          final pending = state.pendingRevert;
          if (pending == null) return const SizedBox.shrink();

          return ConfirmDialog(
            title: pending.target == RevertTarget.file
                ? 'Revert this file?'
                : 'Revert this whole import run?',
            body: pending.label,
            consequence: _consequenceOf(pending),
            confirmLabel: 'Revert',
            isBusy: pending.isReverting,
            onConfirm: () => context.read<ImportHistoryBloc>().add(
              const ImportHistoryRevertConfirmed(),
            ),
            onCancel: () => context.read<ImportHistoryBloc>().add(
              const ImportHistoryRevertDismissed(),
            ),
          );
        },
      );

  static FeedbackMessage _consequenceOf(RevertConfirmation pending) {
    final impact = pending.impact;
    final buffer = StringBuffer(
      '${impact.deletedTransactionText} transactions will be removed from this '
      'device.',
    );
    if (impact.cancelsPairs) {
      buffer.write(
        ' ${impact.cancelledPairText} reconciliation pairs will be dropped.',
      );
    }
    if (impact.hasManualEdits) {
      buffer.write(
        ' Some of those rows were edited by hand after the import; those edits '
        'go with them and cannot be brought back.',
      );
    }
    return FeedbackMessage.danger(buffer.toString());
  }
}
