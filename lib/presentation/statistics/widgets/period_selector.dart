import 'package:flutter/material.dart';

import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/widgets/currency_tab_bar.dart';

/// Chọn độ mịn thời gian của biểu đồ (UC-10 b2).
///
/// Mặc định là theo tháng: đối soát và báo cáo của người dùng này chạy theo chu
/// kỳ tháng, nên đó là mốc họ đang cầm trên tay khi mở màn hình.
///
/// Chỉ có tháng và năm. Theo ngày từng có mặt, nhưng trên dữ liệu vài tháng nó
/// là hàng trăm cột chi chít phải cuộn ngang mới xem hết — không rút ra được
/// điều gì mà theo tháng chưa cho thấy. Chi tiết từng ngày vẫn còn đó: bấm một
/// cột tháng là mở danh sách giao dịch của đúng tháng ấy. `CashFlowPeriod.day`
/// vẫn nằm ở tầng dưới, chỉ không được đưa ra màn hình này.
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

  /// Các độ mịn người dùng chọn được, theo thứ tự hiển thị.
  static const List<CashFlowPeriod> options = <CashFlowPeriod>[
    CashFlowPeriod.month,
    CashFlowPeriod.year,
  ];

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
      for (final value in options)
        SegmentOption<CashFlowPeriod>(value: value, label: labelOf(value)),
    ],
  );
}
