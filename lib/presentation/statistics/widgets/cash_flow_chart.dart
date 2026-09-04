import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../view_models/cash_flow_view_model.dart';

/// Biểu đồ dòng tiền vào/ra (UC-10).
///
/// Hai hình thái theo cách gom nhóm, không theo kích thước màn: gom theo mốc
/// thời gian là cột dọc vì trục thời gian đọc từ trái sang phải; gom theo tài
/// khoản là thanh ngang vì nhãn ở đó là tên tài khoản, thứ không xoay dọc được.
///
/// Vẽ bằng widget thuần chứ không kéo một thư viện biểu đồ vào: hai dạng ở đây
/// là hình chữ nhật tỉ lệ theo một giá trị lớn nhất, và một thư viện sẽ mang
/// theo bảng màu, animation và tooltip riêng — đúng ba thứ mà hệ thống thiết kế
/// này quy định khác đi.
class CashFlowChart extends StatelessWidget {
  const CashFlowChart({
    required this.chart,
    required this.onBarTapped,
    super.key,
  });

  final CashFlowChartViewModel chart;

  /// Khoan xuống danh sách giao dịch của đúng cột vừa bấm.
  final ValueChanged<CashFlowBarViewModel> onBarTapped;

  static const double columnHeight = 200;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (chart.isEmpty) {
      return Text(
        'No figures for this currency yet.',
        style: LedgerText.caption.copyWith(color: colors.inkMute),
      );
    }
    return chart.grouping == CashFlowGrouping.byAccount
        ? _HorizontalBars(chart: chart, onBarTapped: onBarTapped)
        : _VerticalBars(chart: chart, onBarTapped: onBarTapped);
  }
}

class _VerticalBars extends StatelessWidget {
  const _VerticalBars({required this.chart, required this.onBarTapped});

  final CashFlowChartViewModel chart;
  final ValueChanged<CashFlowBarViewModel> onBarTapped;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final max = chart.maxMagnitude == 0 ? 1 : chart.maxMagnitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: CashFlowChart.columnHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final bar in chart.bars)
                Expanded(
                  child: Tooltip(
                    message:
                        '${bar.label} · in ${bar.inflowText} · '
                        'ra ${bar.outflowText}',
                    child: InkWell(
                      onTap: () => onBarTapped(bar),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: <Widget>[
                                  Expanded(
                                    child: _Bar(
                                      fraction:
                                          bar.inflowMinorUnits.abs() / max,
                                      color: colors.moneyIn,
                                    ),
                                  ),
                                  const SizedBox(width: Gap.xs),
                                  Expanded(
                                    child: _Bar(
                                      fraction:
                                          bar.outflowMinorUnits.abs() / max,
                                      color: colors.moneyOutGraphic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: Gap.sm),
                            Text(
                              bar.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: LedgerText.micro.copyWith(
                                color: colors.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Gap.md),
        const _Legend(),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: fraction.clamp(0.0, 1.0),
    alignment: Alignment.bottomCenter,
    child: Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Corner.xs),
      ),
    ),
  );
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({required this.chart, required this.onBarTapped});

  final CashFlowChartViewModel chart;
  final ValueChanged<CashFlowBarViewModel> onBarTapped;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final max = chart.maxMagnitude == 0 ? 1 : chart.maxMagnitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final bar in chart.bars)
          Padding(
            padding: const EdgeInsets.only(bottom: Gap.lg),
            child: InkWell(
              onTap: () => onBarTapped(bar),
              borderRadius: Corner.radiusSm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          bar.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: LedgerText.bodySm.copyWith(color: colors.ink),
                        ),
                      ),
                      Text(
                        bar.inflowText,
                        style: LedgerText.bodyTabular.copyWith(
                          color: colors.moneyIn,
                        ),
                      ),
                      const SizedBox(width: Gap.md),
                      Text(
                        bar.outflowText,
                        style: LedgerText.bodyTabular.copyWith(
                          color: colors.moneyOut,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _HorizontalBar(
                    fraction: bar.inflowMinorUnits.abs() / max,
                    color: colors.moneyIn,
                  ),
                  const SizedBox(height: Gap.xs),
                  _HorizontalBar(
                    fraction: bar.outflowMinorUnits.abs() / max,
                    color: colors.moneyOutGraphic,
                  ),
                ],
              ),
            ),
          ),
        const _Legend(),
      ],
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  const _HorizontalBar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: fraction.clamp(0.0, 1.0),
      child: Container(
        height: 8,
        decoration: BoxDecoration(color: color, borderRadius: Corner.radiusXs),
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    Widget item(Color color, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: LedgerText.micro.copyWith(color: colors.inkSecondary),
        ),
      ],
    );

    return Row(
      children: <Widget>[
        item(colors.moneyIn, 'In'),
        const SizedBox(width: Gap.lg),
        item(colors.moneyOutGraphic, 'Out'),
      ],
    );
  }
}
