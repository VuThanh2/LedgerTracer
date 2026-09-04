import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../bloc/app_lock_bloc.dart';
import '../bloc/app_lock_event.dart';
import '../bloc/app_lock_state.dart';

/// "Quên mã PIN?" — và câu trả lời trung thực là: không khôi phục được.
///
/// Không có tài khoản, không có máy chủ, không có email đặt lại. Đường duy nhất
/// trở vào là xoá toàn bộ dữ liệu cục bộ, nên hộp thoại này nói thẳng điều đó và
/// bắt gõ đúng một chuỗi xác nhận — một nút bấm thôi thì quá nhẹ so với hậu quả.
class ForgotPinDialog extends StatelessWidget {
  const ForgotPinDialog({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<AppLockBloc>()
      ..add(const AppLockResetRequested());
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<AppLockBloc>.value(
        value: bloc,
        child: const ForgotPinDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AppLockBloc, AppLockState>(
    listenWhen: (previous, current) =>
        previous.isResetPending && !current.isResetPending,
    listener: (context, state) => Navigator.of(context).maybePop(),
    builder: (context, state) {
      final bloc = context.read<AppLockBloc>();
      return ConfirmDialog(
        title: 'Forgot your PIN?',
        body:
            'There is no account and no server, so the PIN cannot be reset. '
            'The only way back in is to delete all local data.',
        consequence: const FeedbackMessage.danger(
          'Every transaction, account and reconciliation verdict on this '
          'device is erased. Only a backup file can bring them back.',
        ),
        confirmLabel: 'Delete all data',
        cancelLabel: 'Cancel',
        isBusy: state.isResetting,
        canConfirm: state.canConfirmReset,
        extra: _ConfirmationField(state: state),
        onCancel: () => bloc.add(const AppLockResetDismissed()),
        onConfirm: () => bloc.add(const AppLockResetConfirmed()),
      );
    },
  );
}

class _ConfirmationField extends StatelessWidget {
  const _ConfirmationField({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'TYPE "${AppLockState.resetConfirmationPhrase}" TO CONTINUE',
          style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Gap.xs),
        TextField(
          autofocus: true,
          enabled: !state.isResetting,
          style: LedgerText.bodyMd.copyWith(color: colors.ink),
          decoration: InputDecoration(
            hintText: AppLockState.resetConfirmationPhrase,
          ),
          onChanged: (value) => context.read<AppLockBloc>().add(
            AppLockResetConfirmationTyped(value),
          ),
        ),
      ],
    );
  }
}
