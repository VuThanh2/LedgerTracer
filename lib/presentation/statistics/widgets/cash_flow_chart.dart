import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    this.fill = false,
    super.key,
  });

  final CashFlowChartViewModel chart;

  /// Giãn theo chiều cao được cấp thay vì giữ chiều cao tự nhiên.
  ///
  /// Dùng khi hai biểu đồ đứng cạnh nhau trong hai card cao bằng nhau: cột dọc
  /// cao thêm (không thấp hơn [columnHeight]), còn thanh ngang đẩy chú thích
  /// xuống đáy — để hai chú thích nằm trên cùng một đường thay vì một card bị
  /// hụt hẳn một khúc.
  final bool fill;

  /// Khoan xuống danh sách giao dịch của đúng cột vừa bấm.
  final ValueChanged<CashFlowBarViewModel> onBarTapped;

  static const double columnHeight = 200;

  /// Bề rộng tối đa của một cột. Khi chỉ có vài kỳ (theo năm thường chỉ một),
  /// không giới hạn thì mỗi cột phình ra chiếm nửa card và biểu đồ đọc như hai
  /// khối màu thay vì hai cột.
  static const double maxColumnWidth = 48;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    // Không có kỳ nào, hoặc có kỳ nhưng mọi con số đều bằng 0 (ví dụ khoảng
    // ngày chỉ chứa chuyển khoản nội bộ mà công tắc đang loại trừ): cả hai đều
    // là "không có gì để vẽ", và một vùng trắng không lời giải thích trông như
    // biểu đồ hỏng.
    if (chart.isEmpty || chart.maxMagnitude == 0) {
      body = _EmptyPlot(
        key: const ValueKey<String>('empty'),
        grouping: chart.grouping,
        fill: fill,
      );
    } else if (chart.grouping == CashFlowGrouping.byAccount) {
      // Khoá cố định: số liệu đổi thì từng thanh tự chuyển sang độ dài mới.
      body = _HorizontalBars(
        key: const ValueKey<String>('accounts'),
        chart: chart,
        onBarTapped: onBarTapped,
        fill: fill,
      );
    } else {
      // Tập kỳ đổi (ngày ↔ tháng ↔ năm) thì các cột không tương ứng một-một
      // với cột cũ: mờ sang biểu đồ mới, và cột của biểu đồ mới mọc lên từ 0.
      // Tập kỳ giữ nguyên (ví dụ bật tắt lọc chuyển khoản nội bộ) thì khoá
      // không đổi, biểu đồ không bị dựng lại và từng cột tự chuyển sang chiều
      // cao mới.
      body = _VerticalBars(
        key: ValueKey<String>(chart.bars.map((bar) => bar.label).join('|')),
        chart: chart,
        onBarTapped: onBarTapped,
        fill: fill,
      );
    }
    return AnimatedSwitcher(
      duration: Motion.of(context, Motion.medium),
      switchInCurve: Motion.curve,
      switchOutCurve: Motion.curve,
      child: body,
    );
  }
}

/// Chỗ của biểu đồ khi không có gì để vẽ — theo `empty-state` của DESIGN.md,
/// thu nhỏ lại cho vừa trong một card.
///
/// Giữ đúng chiều cao của vùng vẽ (và chừa chỗ cho chú thích) để đổi qua lại
/// giữa một tab có số liệu và một tab trống không làm card co giật.
class _EmptyPlot extends StatelessWidget {
  const _EmptyPlot({required this.grouping, required this.fill, super.key});

  final CashFlowGrouping grouping;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusMd,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                grouping == CashFlowGrouping.byAccount
                    ? Icons.account_balance_outlined
                    : Icons.bar_chart,
                size: 32,
                color: colors.hairlineStructure,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                grouping == CashFlowGrouping.byAccount
                    ? 'No account moved money in these dates.'
                    : 'No money moved in or out in these dates.',
                textAlign: TextAlign.center,
                // `ink-mute` không đạt 4.5:1 trên `canvas-soft`.
                style: LedgerText.bodyMd.copyWith(color: colors.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (fill)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CashFlowChart.columnHeight,
              ),
              child: panel,
            ),
          )
        else
          SizedBox(height: CashFlowChart.columnHeight, child: panel),
        const SizedBox(height: Gap.md),
        // Chú thích không có gì để giải thích, nhưng chỗ của nó vẫn được giữ.
        const Visibility.maintain(visible: false, child: _Legend()),
      ],
    );
  }
}

class _VerticalBars extends StatefulWidget {
  const _VerticalBars({
    required this.chart,
    super.key,
    required this.onBarTapped,
    required this.fill,
  });

  final CashFlowChartViewModel chart;
  final ValueChanged<CashFlowBarViewModel> onBarTapped;
  final bool fill;

  @override
  State<_VerticalBars> createState() => _VerticalBarsState();
}

class _VerticalBarsState extends State<_VerticalBars> {
  /// Một kỳ không hẹp hơn mức này. Theo ngày thì một tháng đã là 30 kỳ; chia
  /// đều bề rộng card cho chừng ấy kỳ rồi trừ khoảng đệm thì cột còn 0px — vẫn
  /// hover được (tooltip phủ cả ô) nhưng không nhìn thấy gì. Không đủ chỗ cho
  /// mức này thì biểu đồ cuộn ngang thay vì bóp cột về 0.
  static const double _minSlotWidth = 24;

  /// Chiều cao cố định của dòng nhãn, để nhãn thưa (chỉ hiện cách quãng) không
  /// làm các cột nhảy lên xuống.
  static const double _labelHeight = 18;

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plot = _FixedIntrinsicHeight(
      height: CashFlowChart.columnHeight,
      child: LayoutBuilder(builder: _buildPlot),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.fill)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: CashFlowChart.columnHeight,
              ),
              child: plot,
            ),
          )
        else
          SizedBox(height: CashFlowChart.columnHeight, child: plot),
        const SizedBox(height: Gap.md),
        const _Legend(),
      ],
    );
  }

  Widget _buildPlot(BuildContext context, BoxConstraints constraints) {
    final colors = context.ledger;
    final chart = widget.chart;
    final bars = chart.bars;
    final max = chart.maxMagnitude == 0 ? 1 : chart.maxMagnitude;
    final labelStyle = LedgerText.micro.copyWith(color: colors.inkSecondary);

    final natural = constraints.maxWidth / bars.length;
    final scrolls = natural < _minSlotWidth;
    final slotWidth = scrolls ? _minSlotWidth : natural;

    // Khoảng đệm và khe giữa cặp cột co theo bề rộng ô: 8px + 4px là hợp lý
    // cho vài kỳ, nhưng ở ô 24px thì chúng ăn hết chỗ của chính các cột.
    final padding = (slotWidth * 0.15).clamp(1.0, Gap.sm);
    final pairGap = slotWidth < 40 ? 2.0 : Gap.xs;

    // Nhãn chỉ hiện cách quãng khi ô hẹp hơn nhãn, đếm ngược từ kỳ mới nhất
    // để kỳ cuối luôn có nhãn. Đo bằng nhãn dài nhất thay vì đoán theo số ký tự.
    final painter = TextPainter(
      text: TextSpan(
        text: bars.map((bar) => bar.label).reduce(
          (a, b) => a.length >= b.length ? a : b,
        ),
        style: labelStyle,
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final labelWidth = painter.width + Gap.sm;
    painter.dispose();
    final labelStep = (labelWidth / slotWidth).ceil().clamp(1, bars.length);

    final slots = <Widget>[
      for (final (index, bar) in bars.indexed)
        Tooltip(
          // Mỗi số một dòng và kèm mã tiền: tooltip là chỗ duy nhất đọc được
          // con số chính xác của một cột, không được để nó lẫn đơn vị.
          message:
              '${bar.label}\n'
              'In ${bar.inflowText} ${chart.currencyCode}\n'
              'Out ${bar.outflowText} ${chart.currencyCode}',
          child: InkWell(
            onTap: () => widget.onBarTapped(bar),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: padding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        _column(bar.inflowMinorUnits, max, colors.moneyIn),
                        SizedBox(width: pairGap),
                        _column(
                          bar.outflowMinorUnits,
                          max,
                          colors.moneyOutGraphic,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  SizedBox(
                    height: _labelHeight,
                    // Nhãn được tràn ra hai ô bên cạnh (vốn không có nhãn)
                    // thay vì bị cắt thành "…" trong ô hẹp của chính nó.
                    child: (bars.length - 1 - index) % labelStep == 0
                        ? OverflowBox(
                            maxWidth: labelWidth,
                            // Nhãn rộng hơn ô thì hai ô ở mép bám vào phía
                            // trong, không tràn ra ngoài vùng vẽ rồi bị cắt.
                            // Vừa ô thì luôn căn giữa dưới cột.
                            alignment: labelWidth <= slotWidth
                                ? Alignment.center
                                : index == bars.length - 1
                                ? Alignment.centerRight
                                : index == 0
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: Text(
                              bar.label,
                              maxLines: 1,
                              softWrap: false,
                              textAlign: TextAlign.center,
                              style: labelStyle,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
    ];

    if (!scrolls) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final slot in slots) Expanded(child: slot),
        ],
      );
    }

    // Quá nhiều kỳ cho bề rộng này: cuộn ngang, mở ra ở kỳ mới nhất (bên
    // phải) vì đó là thứ người dùng thường muốn xem. Chuột kéo được như chạm,
    // và thanh cuộn luôn hiện để nói rằng còn dữ liệu ở bên trái.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: <PointerDeviceKind>{...PointerDeviceKind.values},
      ),
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          reverse: true,
          // Chừa chỗ cho thanh cuộn để nó không đè lên dòng nhãn.
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: SizedBox(
            width: slotWidth * bars.length,
            height: constraints.maxHeight - Gap.md,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final slot in slots)
                  SizedBox(width: slotWidth, child: slot),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Một cột: co theo phần bề rộng của kỳ nhưng không quá
  /// [CashFlowChart.maxColumnWidth]; cặp vào/ra căn giữa trong kỳ của nó.
  static Widget _column(int minorUnits, int max, Color color) => Flexible(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: CashFlowChart.maxColumnWidth,
      ),
      child: _Bar(fraction: minorUnits.abs() / max, color: color),
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  /// Mọc lên từ 0 ở lần dựng đầu; về sau đổi giá trị thì chuyển dần từ chiều
  /// cao đang có sang chiều cao mới.
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
    duration: Motion.of(context, Motion.medium),
    curve: Motion.curve,
    builder: (context, value, _) {
      final factor = value.clamp(0.0, 1.0);
      // Cột bằng 0 thì không vẽ gì — và **không** dựng `FractionallySizedBox`
      // với hệ số 0: chiều cao nội tại của nó là chiều cao con chia cho hệ
      // số, tức 0/0 = NaN. Ở bản rộng hai card biểu đồ nằm trong
      // `IntrinsicHeight`, và một kỳ không có tiền vào (hoặc ra) là đủ làm cả
      // vùng biểu đồ gãy. Vẫn giữ bề rộng để cột còn lại không lệch khỏi chỗ.
      if (factor == 0) {
        return const SizedBox(width: double.infinity, height: 0);
      }
      return FractionallySizedBox(
        heightFactor: factor,
        alignment: Alignment.bottomCenter,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Corner.xs),
          ),
        ),
      );
    },
  );
}

class _HorizontalBars extends StatelessWidget {
  const _HorizontalBars({
    required this.chart,
    required this.onBarTapped,
    required this.fill,
    super.key,
  });

  final CashFlowChartViewModel chart;
  final ValueChanged<CashFlowBarViewModel> onBarTapped;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final max = chart.maxMagnitude == 0 ? 1 : chart.maxMagnitude;
    // Đứng cạnh biểu đồ cột (bản rộng), thanh 8px trông như đường kẻ đặt
    // cạnh những cột 48px — hai card không cùng "trọng lượng". Ở đó thanh dày
    // lên và các tài khoản giãn ra; xếp chồng (mobile) thì giữ mảnh để một
    // màn hình chứa được nhiều tài khoản.
    final thickness = fill ? 20.0 : 8.0;
    final rowGap = fill ? Gap.xl : Gap.lg;

    final rows = <Widget>[
      for (final (index, bar) in chart.bars.indexed)
        Padding(
          key: ValueKey<Object>(bar.accountId ?? bar.label),
          padding: EdgeInsets.only(top: index == 0 ? 0 : rowGap),
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
                  SizedBox(height: fill ? Gap.sm : 6),
                  _HorizontalBar(
                    fraction: bar.inflowMinorUnits.abs() / max,
                    color: colors.moneyIn,
                    thickness: thickness,
                  ),
                  SizedBox(height: fill ? 6 : Gap.xs),
                  _HorizontalBar(
                    fraction: bar.outflowMinorUnits.abs() / max,
                    color: colors.moneyOutGraphic,
                    thickness: thickness,
                  ),
                ],
              ),
            ),
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Card bị kéo cao bằng card theo kỳ: cụm thanh ngang nằm giữa phần
        // chiều cao dư thay vì dồn lên đỉnh và để lại một khoảng trống dưới
        // đáy — trọng tâm của hai card nhờ vậy ngang nhau.
        if (fill)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          )
        else
          ...rows,
        const SizedBox(height: Gap.lg),
        const _Legend(),
      ],
    );
  }
}

class _HorizontalBar extends StatelessWidget {
  const _HorizontalBar({
    required this.fraction,
    required this.color,
    required this.thickness,
  });

  final double fraction;
  final Color color;
  final double thickness;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: fraction.clamp(0.0, 1.0)),
    duration: Motion.of(context, Motion.medium),
    curve: Motion.curve,
    builder: (context, value, _) => Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          height: thickness,
          decoration: BoxDecoration(
            color: color,
            borderRadius: Corner.radiusXs,
          ),
        ),
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

/// Báo một chiều cao nội tại cố định mà không hỏi xuống con.
///
/// Ở bản rộng, `IntrinsicHeight` hỏi chiều cao nội tại của cả cây biểu đồ để
/// kéo hai card về bằng nhau, còn [LayoutBuilder] — cần để biết mỗi kỳ được
/// bao nhiêu chỗ — không trả lời được câu hỏi đó mà ném lỗi. Vùng vẽ vốn không
/// có chiều cao "tự nhiên": nó cao bao nhiêu là do card cấp, tối thiểu
/// [CashFlowChart.columnHeight]. Trả lời thay cho con vì vậy là nói đúng sự
/// thật, không phải lách.
class _FixedIntrinsicHeight extends SingleChildRenderObjectWidget {
  const _FixedIntrinsicHeight({required this.height, super.child});

  final double height;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderFixedIntrinsicHeight(height);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFixedIntrinsicHeight renderObject,
  ) => renderObject.height = height;
}

class _RenderFixedIntrinsicHeight extends RenderProxyBox {
  _RenderFixedIntrinsicHeight(this._height);

  double _height;

  set height(double value) {
    if (value == _height) return;
    _height = value;
    markNeedsLayout();
  }

  @override
  double computeMinIntrinsicHeight(double width) => _height;

  @override
  double computeMaxIntrinsicHeight(double width) => _height;

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;
}
