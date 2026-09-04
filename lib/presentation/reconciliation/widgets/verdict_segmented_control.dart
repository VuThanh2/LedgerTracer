import 'package:flutter/material.dart';

import '../../shared/formatting/number_formatter.dart';
import '../../shared/widgets/currency_tab_bar.dart';
import '../bloc/reconciliation_state.dart';
import '../view_models/reconciliation_group.dart';

/// Ba nhóm phán quyết, **luôn nhìn thấy cả ba** kèm số đếm.
///
/// Nhóm *Đã từ chối* hiện cả khi bằng 0. Nó không phải một tab có điều kiện mà
/// là lưới an toàn không hết hạn: phán quyết từ chối được nhớ vĩnh viễn, nên
/// người dùng phải luôn có một chỗ để xem lại và gỡ những gì mình đã loại — kể
/// cả khi hôm nay chưa loại gì.
class VerdictSegmentedControl extends StatelessWidget {
  const VerdictSegmentedControl({
    required this.state,
    required this.onSelected,
    this.expand = false,
    super.key,
  });

  final ReconciliationState state;
  final ValueChanged<ReconciliationGroup> onSelected;
  final bool expand;

  @override
  Widget build(BuildContext context) => SegmentedControl<ReconciliationGroup>(
    expand: expand,
    selected: state.group,
    onSelected: onSelected,
    segments: <SegmentOption<ReconciliationGroup>>[
      for (final group in ReconciliationGroup.values)
        SegmentOption<ReconciliationGroup>(
          value: group,
          label: '${group.label} (${_countLabelOf(state, group)})',
        ),
    ],
  );

  /// Số đếm của nhóm từ chối có thể bị chặn trần khi sổ quá dài; dấu `+` nói ra
  /// điều đó thay vì trưng một con số tròn mà sai.
  static String _countLabelOf(
    ReconciliationState state,
    ReconciliationGroup group,
  ) {
    final count = NumberFormatter.count(state.countOf(group));
    final capped =
        group == ReconciliationGroup.rejected && state.rejectedCountIsCapped;
    return capped ? '$count+' : count;
  }
}
