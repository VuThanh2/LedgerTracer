import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../shared/export/view_models/export_source.dart';
import '../../shared/export/widgets/export_dialog.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../../shell/bloc/app_shell_bloc.dart';
import '../../shell/bloc/app_shell_event.dart';
import '../bloc/import_history_bloc.dart';
import '../bloc/import_history_event.dart';
import '../bloc/import_history_state.dart';
import '../view_models/import_history_view_model.dart';
import 'revert_confirm_dialog.dart';

/// Tab Lịch sử của màn Nhập (UC-03 · UC-11).
///
/// Lượt đã hoàn tác, bị huỷ hay bị gián đoạn **vẫn ở lại** danh sách kèm trạng
/// thái của nó. Lịch sử ở đây là sổ ghi việc đã làm, không phải danh sách việc
/// còn hiệu lực: xoá một lượt khỏi danh sách sau khi hoàn tác sẽ khiến người
/// dùng không còn cách nào biết mình đã từng nhập file đó.
class ImportHistoryTab extends StatefulWidget {
  const ImportHistoryTab({super.key});

  @override
  State<ImportHistoryTab> createState() => _ImportHistoryTabState();
}

class _ImportHistoryTabState extends State<ImportHistoryTab> {
  bool _onScroll(ScrollNotification notification, ImportHistoryState state) {
    if (!state.hasMore || state.isLoadingMore) return false;
    final remaining =
        notification.metrics.maxScrollExtent - notification.metrics.pixels;
    if (remaining <= 320) {
      context.read<ImportHistoryBloc>().add(
        const ImportHistoryNextPageRequested(),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<ImportHistoryBloc, ImportHistoryState>(
        listenWhen: (previous, current) =>
            previous.notice != current.notice ||
            (previous.pendingRevert == null && current.pendingRevert != null),
        listener: (context, state) {
          if (state.pendingRevert != null) {
            RevertConfirmDialog.show(context);
            return;
          }
          if (state.notice case final notice?) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.message.text)));
          }
        },
        builder: (context, state) {
          if (state.status.isInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(Gap.screen),
              child: EmptyState(
                title: 'No import runs yet',
                message:
                    'Import a statement file on the New import tab; every run '
                    'is recorded here.',
                icon: Icons.history,
              ),
            );
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) => _onScroll(notification, state),
            child: ListView(
              padding: const EdgeInsets.all(Gap.screen),
              children: <Widget>[
                if (state.loadError case final FeedbackMessage error) ...[
                  BannerMessage(error),
                  const SizedBox(height: Gap.lg),
                ],
                for (final session in state.sessions) ...<Widget>[
                  _SessionCard(
                    session: session,
                    expanded: state.expandedSessionIds.contains(
                      session.sessionId,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
                if (state.isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Gap.lg),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session, required this.expanded});

  final ImportSessionViewModel session;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      session.startedAtText,
                      style: LedgerText.bodyMd.copyWith(color: colors.ink),
                    ),
                    Text(
                      '${session.files.length} file · '
                      '${session.importedText} new · '
                      '${session.duplicateSkippedText} duplicate · '
                      '${session.errorRowText} errors',
                      style: LedgerText.caption.copyWith(color: colors.inkMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              TonePill(
                label: session.statusLabel,
                background: session.isFullyReverted
                    ? colors.hairline
                    : colors.primaryWash,
                foreground: session.isFullyReverted
                    ? colors.inkSecondary
                    : colors.primaryDeep,
              ),
              IconButton(
                tooltip: expanded ? 'Collapse' : 'Show each file',
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                onPressed: () => context.read<ImportHistoryBloc>().add(
                  ImportHistorySessionToggled(session.sessionId),
                ),
              ),
            ],
          ),
          if (session.statusNote.isNotEmpty) ...<Widget>[
            const SizedBox(height: Gap.md),
            BannerMessage(FeedbackMessage.warning(session.statusNote)),
          ],
          if (expanded) ...<Widget>[
            const SizedBox(height: Gap.md),
            for (final file in session.files) ...<Widget>[
              _FileRow(file: file),
              const SizedBox(height: Gap.sm),
            ],
          ],
          if (session.canRevert) ...<Widget>[
            const SizedBox(height: Gap.md),
            DestructiveButton(
              label: 'Revert this whole run',
              onPressed: () => context.read<ImportHistoryBloc>().add(
                ImportHistoryRevertRequested(
                  target: RevertTarget.session,
                  id: session.sessionId,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  const _FileRow({required this.file});

  final ImportFileRecordViewModel file;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusSm,
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
                  style: LedgerText.bodySm.copyWith(color: colors.ink),
                ),
              ),
              const SizedBox(width: Gap.sm),
              TonePill(
                label: file.statusLabel,
                background: file.isReverted
                    ? colors.hairline
                    : colors.moneyInSoft,
                foreground: file.isReverted
                    ? colors.inkSecondary
                    : colors.moneyIn,
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            '${file.accountName} · ${file.importedText} new · '
            '${file.duplicateSkippedText} duplicate · '
            '${file.errorRowText} errors'
            '${file.isReverted ? ' · reverted ${file.revertedAtText}' : ''}',
            style: LedgerText.caption.copyWith(color: colors.inkMute),
          ),
          const SizedBox(height: Gap.sm),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: <Widget>[
              OutlinedButton(
                onPressed: () => context.read<AppShellBloc>().add(
                  AppShellNavigationRequested(file.toNavigationIntent()),
                ),
                child: const Text('View transactions'),
              ),
              if (file.hasErrorRows)
                OutlinedButton(
                  onPressed: () => ExportDialog.open(
                    context,
                    ExportErrorRowsSource(
                      importFileRecordId: file.recordId,
                      fileName: file.fileName,
                    ),
                  ),
                  child: const Text('Export error rows'),
                ),
              if (file.canRevert)
                DestructiveButton(
                  label: 'Revert this file',
                  onPressed: () => context.read<ImportHistoryBloc>().add(
                    ImportHistoryRevertRequested(
                      target: RevertTarget.file,
                      id: file.recordId,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
