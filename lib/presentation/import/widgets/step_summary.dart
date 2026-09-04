import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/value_objects/import_file_status.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/responsive/breakpoints.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../bloc/import_state.dart';
import '../view_models/import_progress_view_model.dart';

/// Bước 4: bảng kết quả theo từng file và tổng cộng (UC-02 b8 · UC-11).
///
/// Ba con số của mỗi file — mới / trùng / lỗi — luôn hiện đủ, kể cả khi bằng 0.
/// "Bỏ qua do trùng" không phải một lỗi mà là bằng chứng rằng nhập lại cùng một
/// file không nhân đôi dữ liệu; giấu nó đi là bỏ mất lời trấn an duy nhất mà
/// người dùng cần trước khi nhập lại lần nữa.
class StepSummary extends StatelessWidget {
  const StepSummary({
    required this.state,
    required this.onExportErrors,
    required this.onGoToReconciliation,
    super.key,
  });

  final ImportState state;

  /// Nhận `recordId` và tên file của dòng cần xuất.
  final void Function(int recordId, String fileName) onExportErrors;

  final VoidCallback onGoToReconciliation;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    if (summary == null) return const SizedBox.shrink();
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (summary.wasCancelled)
          const BannerMessage(
            FeedbackMessage.warning(
              'Import was cancelled at a batch boundary. Committed rows are '
              'kept and this run stays in History so you can revert it.',
            ),
          )
        else
          BannerMessage(
            FeedbackMessage.success(
              'Import finished. ${summary.importedText} new transactions '
              'committed.',
            ),
          ),
        const SizedBox(height: Gap.lg),

        if (sizeClass.usesBottomNavigation)
          for (final file in summary.files) ...<Widget>[
            _FileCard(file: file, onExportErrors: onExportErrors),
            const SizedBox(height: Gap.sm),
          ]
        else
          _SummaryTable(state: state, onExportErrors: onExportErrors),

        const SizedBox(height: Gap.lg),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (state.canGoToReconciliation) ...<Widget>[
              OutlinedButton(
                onPressed: onGoToReconciliation,
                child: const Text('Go to reconciliation'),
              ),
              Text(
                'Two accounts now hold transactions, so reconciliation is '
                'available.',
                style: LedgerText.caption.copyWith(
                  color: context.ledger.inkMute,
                ),
              ),
            ] else
              Text(
                'Reconciliation needs at least two accounts holding '
                'transactions, so it is not available yet.',
                style: LedgerText.caption.copyWith(
                  color: context.ledger.inkMute,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryTable extends StatelessWidget {
  const _SummaryTable({required this.state, required this.onExportErrors});

  final ImportState state;
  final void Function(int recordId, String fileName) onExportErrors;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final summary = state.summary!;

    Widget headerCell(String label, {TextAlign align = TextAlign.left}) =>
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: align,
            style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.hairlineStructure),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(flex: 14, child: headerCell('File')),
                Expanded(flex: 10, child: headerCell('Account')),
                SizedBox(
                  width: 96,
                  child: headerCell('New', align: TextAlign.right),
                ),
                SizedBox(
                  width: 96,
                  child: headerCell('Duplicate', align: TextAlign.right),
                ),
                SizedBox(
                  width: 88,
                  child: headerCell('Errors', align: TextAlign.right),
                ),
                SizedBox(width: 140, child: headerCell('Status')),
              ],
            ),
          ),
          for (final file in summary.files)
            _SummaryRow(file: file, onExportErrors: onExportErrors),
          Container(
            color: colors.canvasSoft,
            child: Row(
              children: <Widget>[
                Expanded(flex: 14, child: headerCell('Total')),
                const Expanded(flex: 10, child: SizedBox.shrink()),
                SizedBox(
                  width: 96,
                  child: _NumberCell(
                    text: summary.importedText,
                    color: colors.moneyIn,
                    emphasized: true,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _NumberCell(text: summary.duplicateSkippedText),
                ),
                SizedBox(
                  width: 88,
                  child: _NumberCell(
                    text: summary.errorRowText,
                    color: colors.moneyOut,
                  ),
                ),
                const SizedBox(width: 140),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.file, required this.onExportErrors});

  final FileImportSummaryViewModel file;
  final void Function(int recordId, String fileName) onExportErrors;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 14,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              child: Text(
                file.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LedgerText.bodySm.copyWith(color: colors.ink),
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: Gap.sm,
              ),
              child: Text(
                file.accountName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: _NumberCell(
              text: file.importedText,
              color: colors.moneyIn,
              emphasized: true,
            ),
          ),
          SizedBox(
            width: 96,
            child: _NumberCell(text: file.duplicateSkippedText),
          ),
          SizedBox(
            width: 88,
            child: _NumberCell(
              text: file.errorRowText,
              color: file.hasErrorRows ? colors.moneyOut : null,
            ),
          ),
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Row(
                children: <Widget>[
                  _StatusPill(file: file),
                  if (file.hasErrorRows)
                    IconButton(
                      tooltip: 'Export error rows',
                      icon: const Icon(Icons.file_download_outlined, size: 16),
                      onPressed: () =>
                          onExportErrors(file.recordId, file.fileName),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file, required this.onExportErrors});

  final FileImportSummaryViewModel file;
  final void Function(int recordId, String fileName) onExportErrors;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.bodyMd.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(width: Gap.sm),
              _StatusPill(file: file),
            ],
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.lg,
            children: <Widget>[
              Text(
                '${file.importedText} new',
                style: LedgerText.caption.copyWith(color: colors.moneyIn),
              ),
              Text(
                '${file.duplicateSkippedText} duplicate',
                style: LedgerText.caption.copyWith(color: colors.inkSecondary),
              ),
              Text(
                '${file.errorRowText} errors',
                style: LedgerText.caption.copyWith(
                  color: file.hasErrorRows ? colors.moneyOut : colors.inkMute,
                ),
              ),
            ],
          ),
          if (file.hasErrorRows) ...<Widget>[
            const SizedBox(height: Gap.md),
            OutlinedButton(
              onPressed: () => onExportErrors(file.recordId, file.fileName),
              child: const Text('Export error rows'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.file});

  final FileImportSummaryViewModel file;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final (background, foreground) = switch (file.status) {
      ImportFileStatus.completed => (colors.moneyInSoft, colors.moneyIn),
      ImportFileStatus.partiallyFailed => (colors.canvasCream, colors.lemonInk),
      ImportFileStatus.cancelled ||
      ImportFileStatus.skipped => (colors.hairline, colors.inkSecondary),
    };
    return TonePill(
      label: file.statusLabel,
      background: background,
      foreground: foreground,
    );
  }
}

class _NumberCell extends StatelessWidget {
  const _NumberCell({required this.text, this.color, this.emphasized = false});

  final String text;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.sm),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: (emphasized ? LedgerText.bodyTabular : LedgerText.caption)
            .copyWith(color: color ?? colors.inkSecondary),
      ),
    );
  }
}
