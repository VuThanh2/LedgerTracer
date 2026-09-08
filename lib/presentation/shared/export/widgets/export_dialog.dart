import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme.dart';
import '../../../../application/export/export_dataset/export_dataset_dto.dart';
import '../../failures/feedback_message.dart';
import '../../widgets/banner_message.dart';
import '../../widgets/filter_chip_bar.dart';
import '../../widgets/progress_panel.dart';
import '../bloc/export_bloc.dart';
import '../bloc/export_event.dart';
import '../bloc/export_state.dart';
import '../view_models/export_source.dart';

/// Dialog xuất dữ liệu — **một** component với năm điểm vào (UC-11).
///
/// Nó không tự biết đang xuất cái gì; [ExportSource] mang theo cả tiêu đề lẫn
/// danh sách tiêu chí, nên thêm một điểm vào thứ sáu chỉ là thêm một `ExportSource`
/// chứ không phải sửa dialog.
///
/// Hai điều bắt buộc phải nói ra ngay tại đây, không đợi người dùng mở file:
/// mọi tiêu chí đang áp dụng sẽ được ghi vào đầu file, và file xuất **không được
/// mã hoá**.
class ExportDialog extends StatelessWidget {
  const ExportDialog({super.key});

  /// Mở dialog cho [source]. Bloc được cấp từ trên cây widget nên dialog dùng
  /// chung một lượt xuất với màn hình gọi nó.
  static Future<void> open(BuildContext context, ExportSource source) {
    final bloc = context.read<ExportBloc>()..add(ExportOpened(source));
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider<ExportBloc>.value(
        value: bloc,
        child: const ExportDialog(),
      ),
    ).then((_) => bloc.add(const ExportDismissed()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return BlocBuilder<ExportBloc, ExportState>(
      builder: (context, state) {
        final source = state.source;
        if (source == null) return const SizedBox.shrink();

        return AlertDialog(
          insetPadding: const EdgeInsets.all(Gap.xxl),
          titlePadding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, 0),
          contentPadding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, 0),
          actionsPadding: const EdgeInsets.all(Gap.xl),
          title: Text(source.title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 512),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Every criterion below is written into the file header, so '
                    'the export can be read back later without guessing.',
                    style: LedgerText.bodyLg.copyWith(
                      color: colors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.lg),
                  _FormatChoice(state: state),
                  const SizedBox(height: Gap.lg),
                  _CriteriaBox(source: source),
                  const SizedBox(height: Gap.md),
                  const BannerMessage(ExportState.notEncryptedWarning),
                  if (state.isRunning) ...<Widget>[
                    const SizedBox(height: Gap.lg),
                    ProgressPanel(
                      label: _progressLabelOf(state),
                      fraction: state.fraction,
                    ),
                  ],
                  if (state.outcome case final FeedbackMessage outcome) ...[
                    const SizedBox(height: Gap.lg),
                    BannerMessage(outcome),
                  ],
                  if (state.savedLocationText case final String saved) ...[
                    const SizedBox(height: Gap.lg),
                    BannerMessage(FeedbackMessage.success(saved)),
                  ],
                ],
              ),
            ),
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: state.isRunning && !state.canCancel
                  ? null
                  : () {
                      if (state.canCancel) {
                        context.read<ExportBloc>().add(const ExportCancelled());
                        return;
                      }
                      Navigator.of(context).pop();
                    },
              child: Text(state.canCancel ? 'Cancel' : 'Close'),
            ),
            FilledButton(
              onPressed: state.isRunning || state.isDone
                  ? null
                  : () =>
                        context.read<ExportBloc>().add(const ExportRequested()),
              child: const Text('Export'),
            ),
          ],
        );
      },
    );
  }

  static String _progressLabelOf(ExportState state) {
    final total = state.total;
    if (total == null) return state.stageLabel;
    return '${state.stageLabel} ${state.processed} / $total';
  }
}

class _FormatChoice extends StatelessWidget {
  const _FormatChoice({required this.state});

  final ExportState state;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      for (final format in ExportFormat.values) ...<Widget>[
        ToggleChip(
          label: switch (format) {
            ExportFormat.csv => 'CSV',
            ExportFormat.excel => 'Excel',
          },
          selected: state.format == format,
          onTap: state.isRunning
              ? () {}
              : () => context.read<ExportBloc>().add(
                  ExportFormatSelected(format),
                ),
        ),
        const SizedBox(width: Gap.sm),
      ],
    ],
  );
}

class _CriteriaBox extends StatelessWidget {
  const _CriteriaBox({required this.source});

  final ExportSource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final line in source.criteriaLines)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: Text(
                line,
                style: LedgerText.bodySm.copyWith(color: colors.ink),
              ),
            ),
        ],
      ),
    );
  }
}
