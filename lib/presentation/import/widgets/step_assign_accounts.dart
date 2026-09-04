import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/bank_account.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../bloc/import_state.dart';
import '../view_models/import_file_entry.dart';
import 'account_mismatch_dialog.dart';
import 'step_pick_files.dart';

/// Bước 2: gán tài khoản đích cho từng file (UC-02 b3, b4 · UC-01).
///
/// Đây là bước **chặn**: không có tài khoản thì giao dịch không thuộc về đâu, và
/// một lần nhập sai tài khoản phải hoàn tác cả file mới sửa được. Nút đi tiếp
/// khoá lại cho tới khi mọi file đã sẵn sàng, và lý do khoá được nói ra ở chân
/// stepper chứ không để người dùng tự đoán.
class StepAssignAccounts extends StatelessWidget {
  const StepAssignAccounts({
    required this.state,
    required this.onAssign,
    required this.onImportAnyway,
    required this.onSkipFile,
    required this.onCreateAccount,
    super.key,
  });

  final ImportState state;
  final void Function(String fileName, int accountId) onAssign;
  final ValueChanged<String> onImportAnyway;
  final ValueChanged<String> onSkipFile;

  /// Tạo tài khoản mới rồi gán ngay cho file đang xét.
  final ValueChanged<String> onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final files = state.recognizedFiles;
    if (files.isEmpty) {
      return const BannerMessage(
        FeedbackMessage.warning(
          'No file could be read, so there is nothing to assign an account to.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final file in files) ...<Widget>[
          _AssignRow(
            entry: file,
            accounts: state.accounts,
            onAssign: (accountId) => onAssign(file.fileName, accountId),
            onImportAnyway: () => onImportAnyway(file.fileName),
            onSkipFile: () => onSkipFile(file.fileName),
            onCreateAccount: () => onCreateAccount(file.fileName),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ],
    );
  }
}

class _AssignRow extends StatelessWidget {
  const _AssignRow({
    required this.entry,
    required this.accounts,
    required this.onAssign,
    required this.onImportAnyway,
    required this.onSkipFile,
    required this.onCreateAccount,
  });

  final ImportFileEntry entry;
  final List<BankAccount> accounts;
  final ValueChanged<int> onAssign;
  final VoidCallback onImportAnyway;
  final VoidCallback onSkipFile;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final format = entry.format;
    final borderColor = entry.hasUnresolvedMismatch
        ? colors.lemon
        : colors.hairline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.all(Gap.md),
          decoration: BoxDecoration(
            color: colors.canvas,
            borderRadius: Corner.radiusMd,
            border: Border.all(color: borderColor),
          ),
          child: Wrap(
            spacing: Gap.md,
            runSpacing: Gap.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (format != null)
                TonePill.soft(context, StepPickFiles.labelOf(format)),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 200, maxWidth: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      entry.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LedgerText.bodyMd.copyWith(
                        color: entry.isSkipped ? colors.inkMute : colors.ink,
                      ),
                    ),
                    Text(
                      _subtitleOf(entry),
                      style: LedgerText.caption.copyWith(color: colors.inkMute),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 236,
                child: DropdownButtonFormField<int>(
                  initialValue: entry.accountId,
                  isExpanded: true,
                  style: LedgerText.bodyMd.copyWith(color: colors.ink),
                  decoration: const InputDecoration(
                    hintText: 'Choose an account…',
                  ),
                  items: <DropdownMenuItem<int>>[
                    for (final account in accounts)
                      DropdownMenuItem<int>(
                        value: account.accountId,
                        child: Text(
                          account.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: entry.isSkipped
                      ? null
                      : (value) {
                          if (value != null) onAssign(value);
                        },
                ),
              ),
            ],
          ),
        ),
        if (entry.mismatch case final check?) ...<Widget>[
          const SizedBox(height: Gap.xs),
          AccountMismatchNotice(
            check: check,
            onImportAnyway: onImportAnyway,
            onSkipFile: onSkipFile,
            onCreateAccount: onCreateAccount,
          ),
        ],
        if (entry.isSkipped) ...<Widget>[
          const SizedBox(height: Gap.xs),
          const BannerMessage(
            FeedbackMessage.info(
              'This file will be skipped. The run still records it, so the '
              'history reflects exactly what you picked.',
            ),
          ),
        ] else if (entry.willLearnAccountNumber) ...<Widget>[
          const SizedBox(height: Gap.xs),
          const BannerMessage(
            FeedbackMessage.info(
              'This account has no number yet. The app will learn the number '
              'read from the file and check against it on later imports.',
            ),
          ),
        ],
      ],
    );
  }

  static String _subtitleOf(ImportFileEntry entry) {
    final number = entry.recognized?.embeddedAccountNumber;
    if (number == null) return 'This file carries no account number.';
    return 'Account number read from file: $number';
  }
}
