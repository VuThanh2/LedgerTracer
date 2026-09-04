import 'package:bloc/bloc.dart';

import '../../../application/diagnostics/run_benchmark/run_benchmark_dto.dart';
import '../../../application/diagnostics/run_benchmark/run_benchmark_use_case.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/failures/failure_presenter.dart';
import '../frame_timing_recorder.dart';
import '../view_models/benchmark_view_model.dart';
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
    required this.capabilities,
    FrameTimingRecorder? frameRecorder,
  }) : _benchmark = runBenchmark,
       _frames = frameRecorder ?? FrameTimingRecorder(),
       super(const DiagnosticsState()) {
    on<DiagnosticsStarted>(_onStarted);
    on<DiagnosticsWorkloadSelected>(_onWorkloadSelected);
    on<DiagnosticsSampleSizeChanged>(_onSampleSizeChanged);
    on<DiagnosticsBatchSizeChanged>(_onBatchSizeChanged);
    // Một lượt đo đang chạy chiếm trọn thiết bị; bấm lần nữa phải rơi, không
    // được xếp hàng — kết quả của lượt thứ hai sẽ nhiễu vì lượt đầu còn dư âm.
    on<DiagnosticsRunRequested>(_onRunRequested, transformer: EventTransformers.droppable());
    on<DiagnosticsCleared>(_onCleared);
  }

  final RunBenchmarkUseCase _benchmark;
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
      final measured = await _measure(strategies[index]);
      switch (measured) {
        case Err<BenchmarkRunViewModel>(:final failure):
          emit(
            state.copyWith(
              isRunning: false,
              runs: results,
              error: FailurePresenter.of(failure, context: 'lượt đo'),
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
        runningStrategyIndex: 0,
        strategyCount: 0,
        clearError: true,
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
      (value) =>
          BenchmarkRunViewModel.of(value.runs.first, frames: frames),
    );
  }
}
