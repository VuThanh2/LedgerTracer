import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../bloc/import_state.dart';

/// Chỉ báo bốn bước của luồng nhập (UC-02).
///
/// Bốn bước là **trạng thái của cùng một tab**, không phải bốn route: người dùng
/// lùi lại một bước không được làm mất các file đã chọn, và cả luồng phải sống
/// sót qua việc chuyển sang tab khác trong lúc đang chạy.
///
/// Ở Compact chỉ còn dãy chấm số; nhãn bước đã nằm ngay dưới dưới dạng tiêu đề
/// `display-md`, nên lặp lại nó ở đây chỉ tốn chiều cao.
class ImportStepper extends StatelessWidget {
  const ImportStepper({required this.step, this.showLabels = true, super.key});

  final ImportStep step;
  final bool showLabels;

  static String labelOf(ImportStep step) => switch (step) {
    ImportStep.pickFiles => 'Choose files',
    ImportStep.assignAccounts => 'Assign accounts',
    ImportStep.running => 'Processing',
    ImportStep.summary => 'Summary',
  };

  static String titleOf(ImportStep step) => switch (step) {
    ImportStep.pickFiles => 'Choose statement files',
    ImportStep.assignAccounts => 'Assign an account to each file',
    ImportStep.running => 'Importing',
    ImportStep.summary => 'Import summary',
  };

  static String subtitleOf(ImportStep step) => switch (step) {
    ImportStep.pickFiles =>
      'CSV, Excel, MT940 and JSON statements. PDF is not supported — export CSV '
          'or Excel from your bank instead.',
    ImportStep.assignAccounts =>
      'Every file needs a destination account before processing can start.',
    ImportStep.running =>
      'Rows are committed batch by batch. Cancel takes effect at the next batch '
          'boundary, and rows already committed stay.',
    ImportStep.summary =>
      'Nothing else is pending. You can export the error rows or move on to '
          'reconciliation.',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final steps = ImportStep.values;
    final currentIndex = steps.indexOf(step);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.screen,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: Row(
                children: <Widget>[
                  if (i > 0)
                    Expanded(
                      child: Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(horizontal: Gap.sm),
                        color: i <= currentIndex
                            ? colors.primary
                            : colors.hairline,
                      ),
                    ),
                  _StepDot(
                    number: i + 1,
                    done: i < currentIndex,
                    current: i == currentIndex,
                  ),
                  if (showLabels) ...<Widget>[
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Text(
                        labelOf(steps[i]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LedgerText.bodySm.copyWith(
                          color: i == currentIndex
                              ? colors.ink
                              : colors.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.done,
    required this.current,
  });

  final int number;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final filled = done || current;
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? colors.primary : colors.canvas,
        border: Border.all(
          color: filled ? colors.primary : colors.hairlineControl,
        ),
      ),
      child: done
          ? Icon(Icons.check, size: 12, color: colors.onPrimary)
          : Text(
              '$number',
              style: LedgerText.microCap.copyWith(
                color: filled ? colors.onPrimary : colors.inkSecondary,
              ),
            ),
    );
  }
}
