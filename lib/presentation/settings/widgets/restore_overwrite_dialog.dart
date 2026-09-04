import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../bloc/backup_restore_bloc.dart';
import '../bloc/backup_restore_event.dart';
import '../bloc/backup_restore_state.dart';

/// Xác nhận ghi đè trước khi khôi phục (UC-13).
///
/// Chỉ mở **sau khi** file đã giải mã thành công, nên nó hiển thị được nội dung
/// thật của bản sao lưu: tạo lúc nào, bao nhiêu tài khoản, bao nhiêu giao dịch.
/// Đó là cách duy nhất người dùng biết mình sắp thay dữ liệu hiện tại bằng cái
/// gì — hỏi trước khi giải mã thì câu hỏi chỉ là một lời doạ không có nội dung.
class RestoreOverwriteDialog extends StatelessWidget {
  const RestoreOverwriteDialog({super.key});

  static Future<void> show(BuildContext context) {
    final bloc = context.read<BackupRestoreBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<BackupRestoreBloc>.value(
        value: bloc,
        child: const RestoreOverwriteDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<BackupRestoreBloc, BackupRestoreState>(
        listenWhen: (previous, current) =>
            previous.isAwaitingOverwriteConfirmation &&
            !current.isAwaitingOverwriteConfirmation,
        listener: (context, state) => Navigator.of(context).maybePop(),
        builder: (context, state) {
          final manifest = state.manifest;
          if (manifest == null) return const SizedBox.shrink();

          return ConfirmDialog(
            title: 'Restore and overwrite?',
            body:
                'This backup was made at ${manifest.createdAtText} and holds '
                '${manifest.accountText} accounts and '
                '${manifest.transactionText} transactions.',
            consequence: const FeedbackMessage.danger(
              'Everything currently on this device is replaced by the contents '
              'of the backup file. This cannot be undone.',
            ),
            confirmLabel: 'Restore',
            cancelLabel: 'Keep it',
            isBusy: state.isRestoring,
            onCancel: () =>
                context.read<BackupRestoreBloc>().add(const RestoreDismissed()),
            onConfirm: () =>
                context.read<BackupRestoreBloc>().add(const RestoreCommitted()),
          );
        },
      );
}
