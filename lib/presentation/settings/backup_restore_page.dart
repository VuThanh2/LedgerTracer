import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/confirm_dialog.dart';
import '../shared/widgets/section_card.dart';
import 'bloc/backup_restore_bloc.dart';
import 'bloc/backup_restore_event.dart';
import 'bloc/backup_restore_state.dart';
import 'widgets/restore_overwrite_dialog.dart';

/// Sao lưu và khôi phục (UC-13).
///
/// Mật khẩu file **độc lập với mã PIN** của ứng dụng, và điều đó phải nói ra:
/// người dùng mặc định cho rằng một ứng dụng chỉ có một mật khẩu. Hai thứ này
/// bảo vệ hai vật khác nhau — PIN giữ ứng dụng trên máy này, mật khẩu file đi
/// theo file sang bất kỳ máy nào — nên gộp chúng là làm mất một trong hai.
class BackupRestorePage extends StatelessWidget {
  const BackupRestorePage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const BackupRestorePage());

  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context);
    return BlocProvider<BackupRestoreBloc>(
      create: (_) => BackupRestoreBloc(
        backupRestore: dependencies.backupRestore,
        filePicker: dependencies.backupFilePicker,
      )..add(const BackupRestoreStarted()),
      child: const _BackupRestoreView(),
    );
  }
}

class _BackupRestoreView extends StatefulWidget {
  const _BackupRestoreView();

  @override
  State<_BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends State<_BackupRestoreView> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordConfirm = TextEditingController();
  final TextEditingController _restorePassword = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _passwordConfirm.dispose();
    _restorePassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: BlocConsumer<BackupRestoreBloc, BackupRestoreState>(
        listenWhen: (previous, current) =>
            previous.notice != current.notice ||
            (!previous.isAwaitingOverwriteConfirmation &&
                current.isAwaitingOverwriteConfirmation),
        listener: (context, state) {
          if (state.isAwaitingOverwriteConfirmation) {
            RestoreOverwriteDialog.show(context);
            return;
          }
          if (state.notice case final notice?) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.message.text)));
          }
        },
        builder: (context, state) {
          final bloc = context.read<BackupRestoreBloc>();
          return ListView(
            padding: const EdgeInsets.all(Gap.screen),
            children: <Widget>[
              SectionCard(
                title: 'Create a backup',
                subtitle: 'The file password is separate from your app PIN.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _PasswordField(
                      label: 'File password',
                      controller: _password,
                      errorText: state.backupPasswordError,
                      onChanged: () => bloc.add(
                        BackupPasswordChanged(
                          password: _password.text,
                          confirm: _passwordConfirm.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.md),
                    _PasswordField(
                      label: 'Repeat the file password',
                      controller: _passwordConfirm,
                      onChanged: () => bloc.add(
                        BackupPasswordChanged(
                          password: _password.text,
                          confirm: _passwordConfirm.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    const BannerMessage(
                      FeedbackMessage.danger(
                        'Lose this password and the backup file cannot be '
                        'opened. There is no recovery path — nothing is stored '
                        'anywhere else.',
                      ),
                    ),
                    const SizedBox(height: Gap.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        onPressed: state.canBackup
                            ? () => bloc.add(const BackupRequested())
                            : null,
                        child: Text(
                          state.isBackingUp
                              ? 'Creating the file…'
                              : 'Create backup file',
                        ),
                      ),
                    ),
                    if (state.savedLocationText case final String saved) ...[
                      const SizedBox(height: Gap.md),
                      BannerMessage(FeedbackMessage.success(saved)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: Gap.lg),

              SectionCard(
                title: 'Restore from a backup',
                subtitle:
                    'Restoring replaces everything currently on this device.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _PickedFileRow(
                      fileName: state.pickedFileName,
                      onPick: () => bloc.add(const RestoreFilePicked()),
                    ),
                    const SizedBox(height: Gap.md),
                    _PasswordField(
                      label: 'File password',
                      controller: _restorePassword,
                      onChanged: () => bloc.add(
                        RestorePasswordChanged(_restorePassword.text),
                      ),
                    ),
                    if (state.restoreError
                        case final FeedbackMessage error) ...[
                      const SizedBox(height: Gap.md),
                      BannerMessage(error),
                    ],
                    const SizedBox(height: Gap.lg),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DestructiveButton(
                        label: state.isPreparing
                            ? 'Opening the file…'
                            : 'Restore and overwrite',
                        onPressed: state.canPrepareRestore
                            ? () => bloc.add(const RestorePrepared())
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Gap.xs),
        TextField(
          controller: controller,
          obscureText: true,
          style: LedgerText.bodyMd.copyWith(color: colors.ink),
          decoration: InputDecoration(errorText: errorText),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}

class _PickedFileRow extends StatelessWidget {
  const _PickedFileRow({required this.fileName, required this.onPick});

  final String? fileName;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: Corner.radiusSm,
              border: Border.all(color: colors.hairlineControl),
            ),
            child: Text(
              fileName ?? 'No backup file chosen yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerText.bodyMd.copyWith(
                color: fileName == null ? colors.inkMute : colors.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: Gap.sm),
        OutlinedButton(onPressed: onPick, child: const Text('Choose file')),
      ],
    );
  }
}
