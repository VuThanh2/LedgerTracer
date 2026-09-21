import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/presentation/diagnostics/bloc/diagnostics_state.dart';
import 'package:ledger_tracer/presentation/diagnostics/view_models/probe_view_models.dart';
import 'package:ledger_tracer/presentation/diagnostics/widgets/probe_result_tables.dart';
import 'package:ledger_tracer/presentation/diagnostics/widgets/workload_controls.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.diagnostics(LedgerTheme.light()),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
  }

  WorkloadControls controls(DiagnosticsTest test) => WorkloadControls(
    state: DiagnosticsState(test: test),
    onWorkloadSelected: (_) {},
    onBatchSizeSelected: (_) {},
    onSampleSizeSelected: (_) {},
    onRun: () {},
    onTestSelected: (_) {},
    onRepeatsSelected: (_) {},
  );

  testWidgets('bảng hiệu năng: đủ núm cũ, thêm Test và Repeats', (
    tester,
  ) async {
    await pump(tester, controls(DiagnosticsTest.throughput));
    expect(tester.takeException(), isNull);
    for (final label in <String>[
      'TEST',
      'WORKLOAD',
      'BATCH SIZE',
      'ITEM COUNT',
      'REPEATS',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('độ trễ huỷ tự quét cỡ lô nên ẩn núm cỡ lô', (tester) async {
    await pump(tester, controls(DiagnosticsTest.cancellation));
    expect(find.text('BATCH SIZE'), findsNothing);
    expect(find.text('WORKLOAD'), findsNothing);
    expect(find.text('REPEATS'), findsNothing);
  });

  testWidgets('hai bảng mới dựng được ở bề ngang điện thoại', (tester) async {
    await pump(
      tester,
      const Column(
        children: <Widget>[
          CancelProbeTable(
            runs: <CancelProbeViewModel>[
              CancelProbeViewModel(
                modeLabel: 'Background isolate',
                batchSize: 8000,
                latencyText: '12.4 ms',
                itemsAfterText: '16.000',
                batchesAfterText: '2.0',
              ),
            ],
          ),
          BackpressureProbeTable(
            runs: <BackpressureProbeViewModel>[
              BackpressureProbeViewModel(
                modeLabel: 'Background isolate',
                batchSize: 500,
                isCapped: false,
                limitText: 'no limit',
                peakBatchesText: '398',
                peakItemsText: '199.000',
                producerText: '85.2 ms',
                consumerText: '1.912.0 ms',
              ),
            ],
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('PEAK BATCHES WAITING'), findsOneWidget);
    expect(find.text('CANCEL → STOPPED'), findsOneWidget);
  });
}
