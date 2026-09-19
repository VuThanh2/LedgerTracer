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
      child: showLabels
          ? _labeledRow(colors, steps, currentIndex)
          : _dotsRow(colors, steps, currentIndex),
    );
  }

  /// Chỉ có chấm: chấm và đoạn nối xen kẽ trong một hàng phẳng, nên bốn chấm
  /// cách đều nhau — chấm 1 ở mép trái, chấm 4 ở mép phải.
  Widget _dotsRow(LedgerColors colors, List<ImportStep> steps, int current) =>
      Row(
        children: <Widget>[
          for (var i = 0; i < steps.length; i++) ...<Widget>[
            if (i > 0) Expanded(child: _connector(colors, i <= current)),
            _StepDot(number: i + 1, done: i < current, current: i == current),
          ],
        ],
      );

  static Widget _connector(LedgerColors colors, bool reached) => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(horizontal: Gap.sm),
    color: reached ? colors.primary : colors.hairline,
  );

  /// Có nhãn: mỗi bước là "chấm · nhãn · đoạn nối **phía sau**". Ba bước đầu
  /// chia đều bề rộng còn bước cuối chỉ chiếm đúng cỡ của nó, nên mọi chấm cách
  /// nhau đúng một ô — không còn cảnh bước 1 đứng lẻ loi vì đoạn nối nằm trước
  /// chấm ở ba bước sau.
  Widget _labeledRow(
    LedgerColors colors,
    List<ImportStep> steps,
    int currentIndex,
  ) {
    Widget label(int i) => Text(
      labelOf(steps[i]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: LedgerText.bodySm.copyWith(
        color: i == currentIndex ? colors.ink : colors.inkSecondary,
      ),
    );

    final last = steps.length - 1;
    return Row(
      children: <Widget>[
        for (var i = 0; i < last; i++)
          Expanded(
            child: Row(
              children: <Widget>[
                _StepDot(
                  number: i + 1,
                  done: i < currentIndex,
                  current: i == currentIndex,
                ),
                const SizedBox(width: Gap.sm),
                // Nhãn được ưu tiên chỗ hơn đoạn nối để cửa sổ cỡ vừa ít bị cắt chữ.
                Flexible(flex: 3, child: label(i)),
                Expanded(child: _connector(colors, i + 1 <= currentIndex)),
              ],
            ),
          ),
        _StepDot(
          number: last + 1,
          done: last < currentIndex,
          current: last == currentIndex,
        ),
        const SizedBox(width: Gap.sm),
        label(last),
      ],
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
