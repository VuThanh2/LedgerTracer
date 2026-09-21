import 'package:bloc/bloc.dart';

import '../../../application/diagnostics/probe_runtime/probe_runtime_dto.dart';
import '../../../application/diagnostics/probe_runtime/probe_runtime_use_case.dart';
import '../../../application/diagnostics/run_benchmark/run_benchmark_dto.dart';
import '../../../application/diagnostics/run_benchmark/run_benchmark_use_case.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/failures/failure_presenter.dart';
import '../frame_timing_recorder.dart';
import '../view_models/benchmark_view_model.dart';
import '../view_models/probe_view_models.dart';
import 'diagnostics_event.dart';
import 'diagnostics_state.dart';

/// Màn hình chẩn đoán: chạy một workload tổng hợp dưới từng chiến lược
/// concurrency và đo kết quả.
///
/// Nằm **ngoài Domain** một cách có chủ đích — nó không sinh ra khái niệm nghiệp
/// vụ nào. Nó tồn tại để phần thực nghiệm có số liệu thay vì khẳng định suông về
/// hai hệ quả của việc mất isolate trên Web (UC-14):
///
/// * **tổng thời gian hoàn tất** dài hơn vì mất song song — `RunBenchmarkUseCase`
///   đo trực tiếp;
/// * **giao diện giật** vì công việc chạy ngay trên luồng đang vẽ — chỉ đo được
///   ở tầng này, bằng `FrameTimingRecorder`.
///
/// Vì hệ quả thứ hai, BLoC gọi use case **một lần cho mỗi chiến lược** thay vì
/// đưa cả danh sách vào một lời gọi: khung hình phải được gán cho đúng cấu hình
/// đã gây ra chúng, và một lời gọi gộp thì mọi khung hình của cả bảng dồn vào
/// một rổ.
final class DiagnosticsBloc extends Bloc<DiagnosticsEvent, DiagnosticsState> {
  DiagnosticsBloc({
    required RunBenchmarkUseCase runBenchmark,
    required ProbeRuntimeUseCase probeRuntime,
    required this.capabilities,
    FrameTimingRecorder? frameRecorder,
  }) : _benchmark = runBenchmark,
       _probe = probeRuntime,
       _frames = frameRecorder ?? FrameTimingRecorder(),
       super(const DiagnosticsState()) {
    on<DiagnosticsStarted>(_onStarted);
    on<DiagnosticsWorkloadSelected>(_onWorkloadSelected);
    on<DiagnosticsSampleSizeChanged>(_onSampleSizeChanged);
    on<DiagnosticsBatchSizeChanged>(_onBatchSizeChanged);
    // Một lượt đo đang chạy chiếm trọn thiết bị; bấm lần nữa phải rơi, không
    // được xếp hàng — kết quả của lượt thứ hai sẽ nhiễu vì lượt đầu còn dư âm.
    on<DiagnosticsRunRequested>(
      _onRunRequested,
      transformer: EventTransformers.droppable(),
    );
    on<DiagnosticsCleared>(_onCleared);
    on<DiagnosticsTestSelected>(_onTestSelected);
    on<DiagnosticsRepeatsChanged>(_onRepeatsChanged);
  }

  /// Các cỡ lô mà phép đo độ trễ huỷ quét qua — đúng ba cỡ của bảng điều khiển,
  /// để bảng huỷ và bảng hiệu năng nói về cùng một bộ cấu hình.
  static const List<int> cancelProbeBatchSizes = <int>[500, 2000, 8000];

  final RunBenchmarkUseCase _benchmark;
  final ProbeRuntimeUseCase _probe;
  final FrameTimingRecorder _frames;

  final PlatformCapabilities capabilities;

  void _onStarted(DiagnosticsStarted event, Emitter<DiagnosticsState> emit) =>
      emit(
        state.copyWith(
          supportsIsolates: capabilities.supportsIsolates,
          processorCount: capabilities.processorCount,
          batchSize: state.workload.defaultBatchSize,
        ),
      );

  void _onWorkloadSelected(
    DiagnosticsWorkloadSelected event,
    Emitter<DiagnosticsState> emit,
  ) {
    if (state.isRunning) return;
    emit(
      state.copyWith(
        workload: event.workload,
        // Kích thước lô mặc định đi theo hình dạng workload: lô của lần quét
        // thưa hơn hẳn lô của lần nhập vì kết quả trả về nhỏ hơn nhiều.
        batchSize: event.workload.defaultBatchSize,
        runs: const <BenchmarkRunViewModel>[],
      ),
    );
  }

  void _onSampleSizeChanged(
    DiagnosticsSampleSizeChanged event,
    Emitter<DiagnosticsState> emit,
  ) {
    if (state.isRunning || event.sampleSize < 1) return;
    emit(state.copyWith(sampleSize: event.sampleSize));
  }

  void _onBatchSizeChanged(
    DiagnosticsBatchSizeChanged event,
    Emitter<DiagnosticsState> emit,
  ) {
    if (state.isRunning || event.batchSize < 1) return;
    emit(state.copyWith(batchSize: event.batchSize));
  }

  Future<void> _onRunRequested(
    DiagnosticsRunRequested event,
    Emitter<DiagnosticsState> emit,
  ) async {
    if (state.isRunning) return;
    switch (state.test) {
      case DiagnosticsTest.cancellation:
        return _runCancellation(emit);
      case DiagnosticsTest.backpressure:
        return _runBackpressure(emit);
      case DiagnosticsTest.throughput:
        break;
    }

    final strategies = state.workload.strategiesFor(
      capabilities: capabilities,
      batchSize: state.batchSize,
    );
    emit(
      state.copyWith(
        isRunning: true,
        runningStrategyIndex: 0,
        strategyCount: strategies.length,
        runs: const <BenchmarkRunViewModel>[],
        clearError: true,
      ),
    );

    final results = <BenchmarkRunViewModel>[];
    for (var index = 0; index < strategies.length; index++) {
      emit(state.copyWith(runningStrategyIndex: index));
      final measured = state.repeats <= 1
          ? await _measure(strategies[index])
          : await _measureRepeated(strategies[index], state.repeats);
      switch (measured) {
        case Err<BenchmarkRunViewModel>(:final failure):
          emit(
            state.copyWith(
              isRunning: false,
              runs: results,
              error: FailurePresenter.of(failure, context: 'benchmark run'),
            ),
          );
          return;
        case Ok<BenchmarkRunViewModel>(:final value):
          results.add(value);
          // Đổ ra sau **mỗi** cấu hình chứ không đợi hết bảng: một lượt đo có
          // thể mất hàng chục giây, và bảng điền dần cho thấy nó đang chạy chứ
          // không phải đang treo.
          emit(state.copyWith(runs: <BenchmarkRunViewModel>[...results]));
      }
    }

    emit(
      state.copyWith(
        isRunning: false,
        runningStrategyIndex: strategies.length,
        runs: results,
      ),
    );
  }

  void _onCleared(DiagnosticsCleared event, Emitter<DiagnosticsState> emit) {
    if (state.isRunning) return;
    emit(
      state.copyWith(
        runs: const <BenchmarkRunViewModel>[],
        cancelRuns: const <CancelProbeViewModel>[],
        backpressureRuns: const <BackpressureProbeViewModel>[],
        runningStrategyIndex: 0,
        strategyCount: 0,
        clearError: true,
      ),
    );
  }

  void _onTestSelected(
    DiagnosticsTestSelected event,
    Emitter<DiagnosticsState> emit,
  ) {
    if (state.isRunning) return;
    emit(state.copyWith(test: event.test, clearError: true));
  }

  void _onRepeatsChanged(
    DiagnosticsRepeatsChanged event,
    Emitter<DiagnosticsState> emit,
  ) {
    if (state.isRunning || event.repeats < 1) return;
    emit(state.copyWith(repeats: event.repeats));
  }

  /// Đo cùng một cấu hình [repeats] lần, mỗi lần một bộ ghi khung hình riêng,
  /// rồi gộp về lần đo trung vị.
  ///
  /// Không đi qua [_measure] để giữ nguyên nó đúng như cũ: lượt đo một lần của
  /// bảng hiệu năng vẫn chạy đúng con đường đã được kiểm chứng.
  Future<Result<BenchmarkRunViewModel>> _measureRepeated(
    ConcurrencyStrategy strategy,
    int repeats,
  ) async {
    final measured = <(BenchmarkRun, FrameTimingStats)>[];
    for (var i = 0; i < repeats; i++) {
      _frames.start();
      final result = await _benchmark.execute(
        RunBenchmarkRequest(
          sampleSize: state.sampleSize,
          strategies: <ConcurrencyStrategy>[strategy],
        ),
      );
      final frames = _frames.stop();
      switch (result) {
        case Err<RunBenchmarkResult>(:final failure):
          return Err<BenchmarkRunViewModel>(failure);
        case Ok<RunBenchmarkResult>(:final value):
          measured.add((value.runs.first, frames));
      }
    }
    return Ok<BenchmarkRunViewModel>(BenchmarkRunViewModel.medianOf(measured));
  }

  /// Độ trễ huỷ: mỗi cỡ lô × mỗi chế độ chạy có thật trên nền tảng này.
  ///
  /// Chỉ luồng chính và **một** isolate: huỷ là chuyện của một workload, và
  /// "nhiều isolate song song" chỉ khác ở số workload chạy cùng lúc chứ không
  /// khác ở cách một workload nhìn thấy lệnh huỷ.
  Future<void> _runCancellation(Emitter<DiagnosticsState> emit) async {
    final strategies = <ConcurrencyStrategy>[
      for (final size in cancelProbeBatchSizes) ...<ConcurrencyStrategy>[
        ConcurrencyStrategy.mainThread(batchSize: size),
        if (capabilities.supportsIsolates)
          ConcurrencyStrategy.singleIsolate(batchSize: size),
      ],
    ];
    emit(
      state.copyWith(
        isRunning: true,
        runningStrategyIndex: 0,
        strategyCount: strategies.length,
        cancelRuns: const <CancelProbeViewModel>[],
        clearError: true,
      ),
    );

    final results = <CancelProbeViewModel>[];
    for (var index = 0; index < strategies.length; index++) {
      emit(state.copyWith(runningStrategyIndex: index));
      final measured = await _probe.measureCancellation(
        sampleSize: state.sampleSize,
        strategy: strategies[index],
      );
      switch (measured) {
        case Err<CancelProbeRun>(:final failure):
          emit(
            state.copyWith(
              isRunning: false,
              cancelRuns: results,
              error: FailurePresenter.of(failure, context: 'cancel probe'),
            ),
          );
          return;
        case Ok<CancelProbeRun>(:final value):
          results.add(CancelProbeViewModel.of(value));
          emit(state.copyWith(cancelRuns: <CancelProbeViewModel>[...results]));
      }
    }
    emit(
      state.copyWith(
        isRunning: false,
        runningStrategyIndex: strategies.length,
        cancelRuns: results,
      ),
    );
  }

  /// Hàng đợi chờ ghi ở cỡ lô đang chọn: isolate có giới hạn, isolate bỏ giới
  /// hạn, và luồng chính — ba dòng đủ để thấy giới hạn giữ được gì, và vì sao
  /// trên Web nó không còn gì để giữ (UC-14).
  Future<void> _runBackpressure(Emitter<DiagnosticsState> emit) async {
    final isolate = ConcurrencyStrategy.singleIsolate(
      batchSize: state.batchSize,
    );
    final configs = <(ConcurrencyStrategy, bool)>[
      if (capabilities.supportsIsolates) ...<(ConcurrencyStrategy, bool)>[
        (isolate, true),
        (isolate, false),
      ],
      (ConcurrencyStrategy.mainThread(batchSize: state.batchSize), true),
    ];
    emit(
      state.copyWith(
        isRunning: true,
        runningStrategyIndex: 0,
        strategyCount: configs.length,
        backpressureRuns: const <BackpressureProbeViewModel>[],
        clearError: true,
      ),
    );

    final results = <BackpressureProbeViewModel>[];
    for (var index = 0; index < configs.length; index++) {
      emit(state.copyWith(runningStrategyIndex: index));
      final (strategy, capped) = configs[index];
      final measured = await _probe.measureBackpressure(
        sampleSize: state.sampleSize,
        strategy: strategy,
        capped: capped,
      );
      switch (measured) {
        case Err<BackpressureProbeRun>(:final failure):
          emit(
            state.copyWith(
              isRunning: false,
              backpressureRuns: results,
              error: FailurePresenter.of(failure, context: 'backlog probe'),
            ),
          );
          return;
        case Ok<BackpressureProbeRun>(:final value):
          results.add(BackpressureProbeViewModel.of(value));
          emit(
            state.copyWith(
              backpressureRuns: <BackpressureProbeViewModel>[...results],
            ),
          );
      }
    }
    emit(
      state.copyWith(
        isRunning: false,
        runningStrategyIndex: configs.length,
        backpressureRuns: results,
      ),
    );
  }

  /// Đo đúng một cấu hình, có ghi khung hình bao quanh.
  ///
  /// Bộ ghi khung hình được bật **ngay trước** và tắt **ngay sau** lời gọi, nên
  /// mọi khung hình rơi vào quãng đó là khung hình mà chính cấu hình này đã ảnh
  /// hưởng tới. Đó là toàn bộ lý do vòng lặp gọi use case từng cấu hình một.
  Future<Result<BenchmarkRunViewModel>> _measure(
    ConcurrencyStrategy strategy,
  ) async {
    _frames.start();
    final result = await _benchmark.execute(
      RunBenchmarkRequest(
        sampleSize: state.sampleSize,
        strategies: <ConcurrencyStrategy>[strategy],
      ),
    );
    final frames = _frames.stop();

    return result.map(
      (value) => BenchmarkRunViewModel.of(value.runs.first, frames: frames),
    );
  }
}
