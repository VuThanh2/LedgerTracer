import 'package:flutter/material.dart';

import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/widgets/currency_tab_bar.dart';

/// Chọn độ mịn thời gian của biểu đồ (UC-10 b2).
///
/// Mặc định là theo tháng: đối soát và báo cáo của người dùng này chạy theo chu
/// kỳ tháng, nên đó là mốc họ đang cầm trên tay khi mở màn hình.
class PeriodSelector extends StatelessWidget {
  const PeriodSelector({
    required this.period,
    required this.onSelected,
    this.expand = false,
    super.key,
  });

  final CashFlowPeriod period;
  final ValueChanged<CashFlowPeriod> onSelected;
  final bool expand;

  static String labelOf(CashFlowPeriod period) => switch (period) {
    CashFlowPeriod.day => 'By day',
    CashFlowPeriod.month => 'By month',
    CashFlowPeriod.year => 'By year',
  };

  @override
  Widget build(BuildContext context) => SegmentedControl<CashFlowPeriod>(
    expand: expand,
    selected: period,
    onSelected: onSelected,
    segments: <SegmentOption<CashFlowPeriod>>[
      for (final value in CashFlowPeriod.values)
        SegmentOption<CashFlowPeriod>(value: value, label: labelOf(value)),
    ],
  );
}
