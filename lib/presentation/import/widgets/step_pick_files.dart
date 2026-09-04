import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../bloc/import_state.dart';
import '../view_models/import_file_entry.dart';

/// Bước 1: chọn file và nhận diện định dạng (UC-02 b1, b2).
///
/// Định dạng do hệ thống đọc ra từ nội dung, không phải do người dùng khai —
/// badge CSV/EXCEL/MT940/JSON ở đây là **kết quả**, không phải một ô chọn. File
/// không nhận diện được vẫn ở lại danh sách kèm lý do, vì im lặng bỏ nó đi là
/// cách chắc chắn để người dùng tưởng mình đã nhập rồi.
class StepPickFiles extends StatelessWidget {
  const StepPickFiles({
    required this.state,
    required this.onPick,
    required this.onRemove,
    super.key,
  });

  final ImportState state;
  final VoidCallback onPick;
  final ValueChanged<String> onRemove;

  static String labelOf(StatementFormat format) => switch (format) {
    StatementFormat.csv => 'CSV',
    StatementFormat.excel => 'Excel',
    StatementFormat.mt940 => 'MT940',
    StatementFormat.json => 'JSON',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        InkWell(
          onTap: state.isPicking ? null : onPick,
          borderRadius: Corner.radiusMd,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.xxl,
            ),
            decoration: BoxDecoration(
              color: colors.primaryWash,
              borderRadius: Corner.radiusMd,
              border: Border.all(
                color: colors.primarySubdued,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.file_upload_outlined,
                  size: 32,
                  color: colors.primaryDeep,
                ),
                const SizedBox(height: Gap.md),
                Text(
                  state.isPicking
                      ? 'Opening the file picker…'
                      : 'Pick one or more statement files from this device',
                  textAlign: TextAlign.center,
                  style: LedgerText.bodyLg.copyWith(color: colors.inkSecondary),
                ),
                const SizedBox(height: Gap.md),
                Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (final format in StatementFormat.values)
                      TonePill.soft(context, labelOf(format)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Gap.lg),

        for (final file in state.files) ...<Widget>[
          _FileRow(entry: file, onRemove: () => onRemove(file.fileName)),
          const SizedBox(height: Gap.sm),
        ],

        if (state.unrecognizedFiles.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.sm),
          BannerMessage(
            FeedbackMessage.warning(
              '${state.unrecognizedFiles.length} files could not be read and '
              'will be skipped. They stay in the list so you can see what you '
              'picked.',
            ),
          ),
        ],
      ],
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.entry, required this.onRemove});

  final ImportFileEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final format = entry.format;

    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.md),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(
          color: entry.isRecognized ? colors.hairline : colors.lemon,
        ),
      ),
      child: Row(
        children: <Widget>[
          if (format != null)
            TonePill.soft(context, StepPickFiles.labelOf(format))
          else
            TonePill(
              label: 'Unreadable',
              background: colors.creamWash,
              foreground: colors.lemonInk,
            ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  entry.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.bodyMd.copyWith(color: colors.ink),
                ),
                if (entry.unrecognizedReason case final String reason)
                  Text(
                    reason,
                    style: LedgerText.caption.copyWith(color: colors.lemonInk),
                  )
                else if (entry.recognized?.embeddedAccountNumber
                    case final String number)
                  Text(
                    'Account number read from file: $number',
                    style: LedgerText.caption.copyWith(color: colors.inkMute),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          DestructiveButton(label: 'Remove', onPressed: onRemove),
        ],
      ),
    );
  }
}
