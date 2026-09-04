import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/accounts_event.dart';
import '../bloc/accounts_state.dart';

/// Xác nhận xoá một tài khoản (UC-01).
///
/// Hộp thoại phải nêu **hai con số**, không phải một: số giao dịch bị xoá theo,
/// và số cặp đối soát bị huỷ. Người dùng đến đây vì tài khoản khai nhầm, và họ
/// không tự nghĩ ra rằng việc đó còn kéo theo các phán quyết đối soát đã làm ở
/// một màn hình khác.
class DeleteAccountDialog extends StatelessWidget {
  const DeleteAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<AccountsBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<AccountsBloc>.value(
        value: bloc,
        child: const DeleteAccountDialog(),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<AccountsBloc, AccountsState>(
    listenWhen: (previous, current) =>
        previous.pendingDelete != null && current.pendingDelete == null,
    listener: (context, state) => Navigator.of(context).maybePop(),
    builder: (context, state) {
      final pending = state.pendingDelete;
      if (pending == null) return const SizedBox.shrink();

      return ConfirmDialog(
        title: 'Delete the account "${pending.displayName}"?',
        body:
            'Every transaction in this account is removed from the device. '
            'Only importing the original statement files brings them back.',
        consequence: FeedbackMessage.danger(_impactTextOf(pending)),
        confirmLabel: 'Delete account',
        isBusy: pending.isDeleting,
        onConfirm: () =>
            context.read<AccountsBloc>().add(const AccountDeleteConfirmed()),
        onCancel: () =>
            context.read<AccountsBloc>().add(const AccountDeleteDismissed()),
      );
    },
  );

  static String _impactTextOf(AccountDeletionConfirmation pending) {
    final impact = pending.impact;
    final buffer = StringBuffer(
      '${impact.transactionText} transactions will be removed.',
    );
    if (impact.cancelsPairs) {
      buffer.write(
        ' ${impact.reconciledPairText} reconciliation pairs will be dropped, '
        'and that is not recorded as a rejection.',
      );
    }
    return buffer.toString();
  }
}
