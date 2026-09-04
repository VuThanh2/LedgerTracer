import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_event.dart';
import '../bloc/transactions_state.dart';

/// Xác nhận xoá một giao dịch (UC-05).
///
/// Không có ngoại lệ nào cho phép xoá mà không hỏi, và câu hỏi phải nói ra hệ
/// quả thật: cặp đối soát chứa giao dịch này **bị huỷ**, nhưng việc huỷ đó
/// *không* được ghi thành một phán quyết từ chối — nên lần quét sau hệ thống vẫn
/// có quyền gợi ý lại một cặp tương tự. Người dùng chỉ tránh được bất ngờ đó nếu
/// biết trước.
///
/// Dialog tự đóng khi BLoC xoá `pendingDelete`, nên đường thành công và đường
/// thất bại không cần hai lệnh `pop` riêng ở hai chỗ.
class DeleteTransactionDialog extends StatelessWidget {
  const DeleteTransactionDialog({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<TransactionsBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider<TransactionsBloc>.value(
        value: bloc,
        child: const DeleteTransactionDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TransactionsBloc, TransactionsState>(
        listenWhen: (previous, current) =>
            previous.pendingDelete != null && current.pendingDelete == null,
        listener: (context, state) => Navigator.of(context).maybePop(),
        builder: (context, state) {
          final pending = state.pendingDelete;
          if (pending == null) return const SizedBox.shrink();

          return ConfirmDialog(
            title: 'Delete this transaction?',
            body:
                'The row is removed from this device and cannot be brought '
                'back, unless you import the original statement file again.',
            consequence: _consequenceOf(pending),
            confirmLabel: 'Delete',
            isBusy: pending.isDeleting,
            onConfirm: () => context.read<TransactionsBloc>().add(
              const TransactionDeleteConfirmed(),
            ),
            onCancel: () => context.read<TransactionsBloc>().add(
              const TransactionDeleteDismissed(),
            ),
          );
        },
      );

  static FeedbackMessage? _consequenceOf(DeleteConfirmation pending) =>
      pending.cancelsReconciliation
      ? const FeedbackMessage.danger(
          'This row belongs to a reconciliation pair. The pair will be dropped, '
          'and because that is not recorded as a rejection, the next scan can '
          'suggest a similar pair again.',
        )
      : null;
}
