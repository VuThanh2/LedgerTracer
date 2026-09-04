import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../transactions/view_models/filter_chip_view_model.dart';

/// Dải chip mô tả **mọi** tiêu chí đang thu hẹp danh sách.
///
/// Hai loại chip nằm chung một dải nhưng khác màu: chip lọc bình thường là viền
/// trên nền trắng, còn Context Chip — thứ do màn hình nguồn sinh ra khi điều
/// hướng sang đây — là pill indigo dịu. Cả hai đều xoá được, vì một ngữ cảnh mà
/// người dùng không gỡ được là một bộ lọc ẩn.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    required this.chips,
    required this.onRemove,
    this.trailing,
    super.key,
  });

  final List<FilterChipViewModel> chips;

  final ValueChanged<FilterChipKind> onRemove;

  /// Nội dung căn phải cùng dòng, ví dụ số dòng và tổng tiền.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty && trailing == null) return const SizedBox.shrink();
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        for (final chip in chips)
          _RemovableChip(chip: chip, onRemove: () => onRemove(chip.kind)),
        ?trailing,
      ],
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.chip, required this.onRemove});

  final FilterChipViewModel chip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final isContext = chip.isContext;
    final background = isContext ? colors.primarySubdued : colors.canvas;
    final foreground = isContext ? colors.primaryPress : colors.inkSecondary;
    final border = isContext ? colors.primarySubdued : colors.hairlineControl;

    return Container(
      padding: const EdgeInsets.only(
        left: Gap.sm,
        right: Gap.xs,
        top: Gap.xs,
        bottom: Gap.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Corner.pill,
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: Text(
              chip.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerText.micro.copyWith(color: foreground),
            ),
          ),
          const SizedBox(width: Gap.xs),
          InkWell(
            onTap: onRemove,
            borderRadius: Corner.pill,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chip bật/tắt của Filter Panel: nền trắng viền `hairline-control`, và khi bật
/// thì nền `primary-wash` viền `primary`.
class ToggleChip extends StatelessWidget {
  const ToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.pill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primaryWash : colors.canvas,
          borderRadius: Corner.pill,
          border: Border.all(
            color: selected ? colors.primary : colors.hairlineControl,
          ),
        ),
        child: Text(
          label,
          style: LedgerText.micro.copyWith(
            color: selected ? colors.primaryDeep : colors.inkSecondary,
          ),
        ),
      ),
    );
  }
}
