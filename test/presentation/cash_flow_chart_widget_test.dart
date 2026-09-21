import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import 'package:ledger_tracer/presentation/statistics/view_models/cash_flow_view_model.dart';
import 'package:ledger_tracer/presentation/statistics/widgets/cash_flow_chart.dart';

void main() {
  CashFlowBarViewModel bar(String label, int inflow, int outflow) =>
      CashFlowBarViewModel(
        label: label,
        inflowText: '+$inflow',
        outflowText: '−${outflow.abs()}',
        netText: '${inflow + outflow}',
        inflowMinorUnits: inflow,
        outflowMinorUnits: outflow,
        netMinorUnits: inflow + outflow,
      );

  CashFlowChartViewModel chart(
    CashFlowGrouping grouping,
    List<CashFlowBarViewModel> bars,
  ) {
    var max = 0;
    for (final b in bars) {
      if (b.magnitude > max) max = b.magnitude;
    }
    return CashFlowChartViewModel(
      grouping: grouping,
      currencyCode: 'VND',
      bars: bars,
      maxMagnitude: max,
      totalInflowText: '',
      totalOutflowText: '',
      totalNetText: '',
    );
  }

  Future<void> pump(
    WidgetTester tester,
    CashFlowChartViewModel model, {
    double width = 550,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: CashFlowChart(chart: model, onBarTapped: (_) {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Bề rộng thật của từng cột đã vẽ.
  List<double> columnWidths(WidgetTester tester) => <double>[
    for (final element in find
        .descendant(
          of: find.byType(FractionallySizedBox),
          matching: find.byType(Container),
        )
        .evaluate())
      tester.getSize(find.byWidget(element.widget)).width,
  ];

  testWidgets(
    'nhiều kỳ trong một card vẫn thấy cột, không bóp về 0',
    (tester) async {
      // 60 kỳ (5 năm theo tháng) trong 550px là 9px mỗi kỳ — trước đây trừ
      // khoảng đệm 16px thì cột còn 0px: hover vẫn ra tooltip nhưng không
      // nhìn thấy gì.
      await pump(
        tester,
        chart(CashFlowGrouping.byPeriod, <CashFlowBarViewModel>[
          for (var i = 0; i < 60; i++)
            bar(
              '${(i % 12 + 1).toString().padLeft(2, '0')}/${2022 + i ~/ 12}',
              (i + 1) * 1000,
              -500,
            ),
        ]),
      );

      final widths = columnWidths(tester);
      expect(widths, hasLength(120));
      expect(widths.every((w) => w >= 4), isTrue, reason: '$widths');
      // Không chứa nổi thì cuộn ngang thay vì bóp.
      expect(find.byType(Scrollbar), findsOneWidget);
    },
  );

  testWidgets('chỉ một kỳ: nhãn nằm giữa, ngay dưới cột', (tester) async {
    await pump(
      tester,
      chart(CashFlowGrouping.byPeriod, <CashFlowBarViewModel>[
        bar('2026', 1000, -500),
      ]),
    );
    final label = tester.getCenter(find.text('2026')).dx;
    final plot = tester.getCenter(find.byType(CashFlowChart)).dx;
    expect((label - plot).abs(), lessThan(1));
  });

  testWidgets('12 tháng trên khổ mobile: vừa một hàng, không cần cuộn', (
    tester,
  ) async {
    await pump(
      tester,
      chart(CashFlowGrouping.byPeriod, <CashFlowBarViewModel>[
        for (var month = 1; month <= 12; month++)
          bar('${month.toString().padLeft(2, '0')}/2026', month * 1000, -500),
      ]),
      width: 320,
    );

    expect(columnWidths(tester).every((w) => w >= 4), isTrue);
    expect(find.byType(Scrollbar), findsNothing);
  });

  testWidgets('không có kỳ nào thì báo trống thay vì để vùng trắng', (
    tester,
  ) async {
    await pump(tester, chart(CashFlowGrouping.byPeriod, const []));
    expect(find.text('No money moved in or out in these dates.'), findsOneWidget);
  });

  testWidgets('có kỳ nhưng mọi con số bằng 0 cũng là trống', (tester) async {
    await pump(
      tester,
      chart(CashFlowGrouping.byAccount, <CashFlowBarViewModel>[bar('vu', 0, 0)]),
    );
    expect(find.text('No account moved money in these dates.'), findsOneWidget);
  });

  testWidgets('trạng thái trống giữ đúng chiều cao của biểu đồ có số liệu', (
    tester,
  ) async {
    await pump(
      tester,
      chart(CashFlowGrouping.byPeriod, <CashFlowBarViewModel>[
        bar('2026', 1000, -500),
      ]),
    );
    final full = tester.getSize(find.byType(CashFlowChart)).height;

    await pump(tester, chart(CashFlowGrouping.byPeriod, const []));
    expect(tester.getSize(find.byType(CashFlowChart)).height, full);
  });

  testWidgets('tooltip của cột dùng một ngôn ngữ và kèm mã tiền', (
    tester,
  ) async {
    await pump(
      tester,
      chart(CashFlowGrouping.byPeriod, <CashFlowBarViewModel>[
        bar('2026', 1000, -500),
      ]),
    );
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tooltip.message, '2026\nIn +1000 VND\nOut −500 VND');
  });
}
