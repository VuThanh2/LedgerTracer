import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/diagnostics/probe_runtime/probe_runtime_use_case.dart';
import 'package:ledger_tracer/application/diagnostics/run_benchmark/run_benchmark_dto.dart';
import 'package:ledger_tracer/application/diagnostics/run_benchmark/run_benchmark_use_case.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/presentation/diagnostics/bloc/diagnostics_bloc.dart';
import 'package:ledger_tracer/presentation/diagnostics/bloc/diagnostics_event.dart';
import 'package:ledger_tracer/presentation/diagnostics/bloc/diagnostics_state.dart';
import 'package:ledger_tracer/presentation/diagnostics/frame_timing_recorder.dart';
import 'package:ledger_tracer/presentation/diagnostics/view_models/benchmark_view_model.dart';
import 'package:ledger_tracer/presentation/diagnostics/view_models/probe_view_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Cấu hình của Web: chỉ có luồng chính, nên mọi lượt đo chạy ngay trong
  // test mà không cần spawn isolate.
  const capabilities = PlatformCapabilities.web();
  const runner = MainThreadRunner(capabilities);

  late DiagnosticsBloc bloc;

  setUp(() {
    bloc =
        DiagnosticsBloc(
            runBenchmark: RunBenchmarkUseCase(runner: runner),
            probeRuntime: ProbeRuntimeUseCase(runner: runner),
            capabilities: capabilities,
          )
          ..add(const DiagnosticsStarted())
          ..add(const DiagnosticsSampleSizeChanged(20000));
  });

  tearDown(() => bloc.close());

  Future<DiagnosticsState> finished() => bloc.stream.firstWhere(
    (state) =>
        !state.isRunning && state.strategyCount > 0 && state.error == null,
  );

  test('mặc định vẫn là bảng hiệu năng, một lần đo, như trước', () async {
    await pumpEventQueue();
    expect(bloc.state.test, DiagnosticsTest.throughput);
    expect(bloc.state.repeats, 1);

    bloc.add(const DiagnosticsRunRequested());
    final state = await finished();
    expect(state.runs, hasLength(1));
    expect(state.runs.single.repeatCount, 1);
    expect(state.runs.single.rangeText, isNull);
  });

  test('lặp ×3 gộp về một dòng trung vị kèm khoảng', () async {
    bloc
      ..add(const DiagnosticsRepeatsChanged(3))
      ..add(const DiagnosticsRunRequested());
    final state = await finished();
    expect(state.runs, hasLength(1));
    expect(state.runs.single.repeatCount, 3);
    expect(state.runs.single.rangeText, isNotNull);
  });

  test('độ trễ huỷ quét đủ ba cỡ lô', () async {
    bloc
      ..add(const DiagnosticsTestSelected(DiagnosticsTest.cancellation))
      ..add(const DiagnosticsRunRequested());
    final state = await finished();
    expect(
      state.cancelRuns.map((run) => run.batchSize),
      DiagnosticsBloc.cancelProbeBatchSizes,
    );
    // Bảng hiệu năng không bị đụng tới.
    expect(state.runs, isEmpty);
  });

  test('hàng đợi trên Web chỉ có một dòng: luồng chính', () async {
    bloc
      ..add(const DiagnosticsTestSelected(DiagnosticsTest.backpressure))
      ..add(const DiagnosticsRunRequested());
    final state = await finished();
    expect(state.backpressureRuns, hasLength(1));
    expect(state.backpressureRuns.single.modeLabel, 'Interface thread');
    expect(state.backpressureRuns.single.peakBatchesText, '1');
  });

  test('Clear xoá kết quả của cả ba phép đo', () async {
    bloc
      ..add(const DiagnosticsTestSelected(DiagnosticsTest.cancellation))
      ..add(const DiagnosticsRunRequested());
    await finished();
    bloc.add(const DiagnosticsCleared());
    await pumpEventQueue();
    expect(bloc.state.hasResults, isFalse);
  });

  test('trung vị lấy đúng lần đo giữa, không lấy trung bình', () {
    BenchmarkRun run(int millis) => BenchmarkRun(
      strategy: ConcurrencyStrategy.mainThread(),
      effectiveMode: ExecutionMode.mainThread,
      elapsed: Duration(milliseconds: millis),
      itemsProcessed: 1000,
    );
    final model = BenchmarkRunViewModel.medianOf(
      <(BenchmarkRun, FrameTimingStats)>[
        (run(30), FrameTimingStats.empty),
        (run(10), FrameTimingStats.empty),
        // Một lần bị hệ điều hành chen ngang: trung bình sẽ là 70ms.
        (run(170), FrameTimingStats.empty),
      ],
    );
    expect(model.elapsedText, '30 ms');
    expect(model.rangeText, '10–170 ms');
    expect(model.repeatCount, 3);
  });
}
