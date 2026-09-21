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
  const ImportStepper({
    required this.step,
    required this.canJumpTo,
    required this.onStepSelected,
    this.showLabels = true,
    super.key,
  });

  final ImportStep step;
  final bool showLabels;

  /// Bước nào bấm vào được. Luật thuộc về `ImportState`; widget này chỉ vẽ theo
  /// câu trả lời của nó, và BLoC vẫn hỏi lại luật một lần nữa khi nhận sự kiện.
  final bool Function(ImportStep step) canJumpTo;

  final ValueChanged<ImportStep> onStepSelected;

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
      'Choose which bank account each file belongs to.',
    ImportStep.running =>
      'Transactions are saved in batches as they are read. Cancelling keeps '
          'everything saved so far.',
    ImportStep.summary =>
      'All done. Export the rows that could not be read, or move on to '
          'reconciliation.',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final steps = ImportStep.values;
    final currentIndex = steps.indexOf(step);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: Gap.screen,
        // Bản hẹp thấp hơn một nấc vì chấm ở đó được bọc trong một vùng chạm cao
        // hơn hẳn chính nó; giữ nguyên Gap.md sẽ đội chiều cao cả thanh lên.
        vertical: showLabels ? Gap.md : Gap.sm,
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

  /// Bọc một phần của bước thành vùng bấm, khi bước đó tới được.
  ///
  /// Bước không tới được trả về [child] **nguyên vẹn**: không `InkWell` xám,
  /// không con trỏ bàn tay, không gợn nước khi bấm. Một nút trông bấm được mà
  /// không làm gì là lời hứa sai, và ở đây lý do không bấm được luôn hiện thành
  /// chữ ngay dưới chân stepper.
  Widget _tappable(ImportStep target, Widget child, {Size? minimumSize}) {
    if (!canJumpTo(target)) {
      return minimumSize == null
          ? child
          : SizedBox.fromSize(size: minimumSize, child: Center(child: child));
    }
    final button = InkWell(
      onTap: () => onStepSelected(target),
      borderRadius: Corner.pill,
      child: minimumSize == null
          ? child
          : SizedBox.fromSize(size: minimumSize, child: Center(child: child)),
    );
    return Tooltip(message: 'Go to step ${target.index + 1}', child: button);
  }

  /// Chỉ có chấm: chấm và đoạn nối xen kẽ trong một hàng phẳng, nên bốn chấm
  /// cách đều nhau — chấm 1 ở mép trái, chấm 4 ở mép phải.
  ///
  /// Chấm rộng 20dp là quá nhỏ để chạm bằng ngón tay, nên ở đây nó được bọc
  /// trong một ô 44×36 — vùng chạm lớn hơn phần nhìn thấy, đúng cách một nút
  /// nhỏ trên màn hình cảm ứng phải làm. Ô có mặt **cả khi** bước không bấm
  /// được, nếu không thì thanh stepper đổi chiều cao mỗi lần đổi bước.
  Widget _dotsRow(LedgerColors colors, List<ImportStep> steps, int current) =>
      Row(
        children: <Widget>[
          for (var i = 0; i < steps.length; i++) ...<Widget>[
            if (i > 0) Expanded(child: _connector(colors, i <= current)),
            _tappable(
              steps[i],
              _StepDot(
                number: i + 1,
                done: i < current,
                current: i == current,
                // Không có nhãn, không có con trỏ chuột và không có hover: trên
                // màn cảm ứng, vòng sáng này là thứ duy nhất nói rằng chấm bấm
                // được.
                reachable: i != current && canJumpTo(steps[i]),
              ),
              minimumSize: const Size(44, 36),
            ),
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

    Widget dot(int i) => _tappable(
      steps[i],
      _StepDot(
        number: i + 1,
        done: i < currentIndex,
        current: i == currentIndex,
      ),
    );

    final last = steps.length - 1;
    return Row(
      children: <Widget>[
        for (var i = 0; i < last; i++)
          Expanded(
            child: Row(
              children: <Widget>[
                // Chấm và nhãn là **hai** vùng bấm cạnh nhau chứ không phải một
                // khối gộp: gộp lại thì cả hai phải nằm trong cùng một `Flexible`,
                // và tỉ lệ chia chỗ giữa nhãn với đoạn nối — thứ giữ cho cửa sổ
                // cỡ vừa không bị cắt chữ — đổi theo.
                dot(i),
                const SizedBox(width: Gap.sm),
                // Nhãn được ưu tiên chỗ hơn đoạn nối để cửa sổ cỡ vừa ít bị cắt chữ.
                Flexible(flex: 3, child: _tappable(steps[i], label(i))),
                Expanded(child: _connector(colors, i + 1 <= currentIndex)),
              ],
            ),
          ),
        dot(last),
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
    this.reachable = false,
  });

  final int number;
  final bool done;
  final bool current;

  /// Bấm vào được để chuyển tới bước này: viền `primary` và một vòng sáng
  /// `primary-wash` bao quanh. Chỉ bản hẹp bật nó; bản rộng đã có nhãn bấm
  /// được và con trỏ bàn tay làm việc đó.
  final bool reachable;

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
          color: filled || reachable ? colors.primary : colors.hairlineControl,
        ),
        boxShadow: reachable
            ? <BoxShadow>[BoxShadow(color: colors.primaryWash, spreadRadius: 4)]
            : null,
      ),
      child: done
          ? Icon(Icons.check, size: 12, color: colors.onPrimary)
          : Text(
              '$number',
              style: LedgerText.microCap.copyWith(
                color: filled
                    ? colors.onPrimary
                    : reachable
                    ? colors.primary
                    : colors.inkSecondary,
              ),
            ),
    );
  }
}
