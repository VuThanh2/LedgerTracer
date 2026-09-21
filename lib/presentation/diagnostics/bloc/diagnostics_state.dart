import '../../shared/failures/feedback_message.dart';
import '../view_models/benchmark_view_model.dart';
import '../view_models/probe_view_models.dart';

/// Trạng thái màn hình chẩn đoán.
final class DiagnosticsState {
  const DiagnosticsState({
    this.workload = BenchmarkWorkload.statementImport,
    this.sampleSize = defaultSampleSize,
    this.batchSize = 500,
    this.supportsIsolates = true,
    this.processorCount = 1,
    this.isRunning = false,
    this.runningStrategyIndex = 0,
    this.strategyCount = 0,
    this.runs = const <BenchmarkRunViewModel>[],
    this.error,
    this.test = DiagnosticsTest.throughput,
    this.repeats = 1,
    this.cancelRuns = const <CancelProbeViewModel>[],
    this.backpressureRuns = const <BackpressureProbeViewModel>[],
  });

  /// Đủ lớn để chênh lệch giữa các chiến lược vượt hẳn nhiễu đo, đủ nhỏ để một
  /// lượt trên luồng chính không treo giao diện tới mức không bấm được gì nữa.
  static const int defaultSampleSize = 200000;

  final BenchmarkWorkload workload;
  final int sampleSize;
  final int batchSize;

  /// Nền tảng có isolate thật không, và có bao nhiêu nhân. Hai con số này là
  /// phần đầu của mọi bảng kết quả: cùng một cấu hình cho hai con số khác nhau
  /// trên hai thiết bị, và bảng nào không ghi chúng thì không so sánh được với
  /// bảng nào (UC-14).
  final bool supportsIsolates;
  final int processorCount;

  final bool isRunning;

  /// Đang đo cấu hình thứ mấy trong danh sách.
  final int runningStrategyIndex;

  final int strategyCount;

  final List<BenchmarkRunViewModel> runs;

  final FeedbackMessage? error;

  /// Phép đo đang chọn. Mỗi phép đo giữ bảng kết quả riêng, nên đổi qua lại
  /// không xoá số đã đo của phép kia.
  final DiagnosticsTest test;

  /// Đo mỗi cấu hình của bảng hiệu năng bao nhiêu lần rồi lấy trung vị. 1 là
  /// hành vi ban đầu: một lần đo, không gộp.
  final int repeats;

  final List<CancelProbeViewModel> cancelRuns;
  final List<BackpressureProbeViewModel> backpressureRuns;

  bool get hasResults =>
      runs.isNotEmpty || cancelRuns.isNotEmpty || backpressureRuns.isNotEmpty;

  double get progress =>
      strategyCount == 0 ? 0 : runningStrategyIndex / strategyCount;

  DiagnosticsState copyWith({
    BenchmarkWorkload? workload,
    int? sampleSize,
    int? batchSize,
    bool? supportsIsolates,
    int? processorCount,
    bool? isRunning,
    int? runningStrategyIndex,
    int? strategyCount,
    List<BenchmarkRunViewModel>? runs,
    FeedbackMessage? error,
    bool clearError = false,
    DiagnosticsTest? test,
    int? repeats,
    List<CancelProbeViewModel>? cancelRuns,
    List<BackpressureProbeViewModel>? backpressureRuns,
  }) => DiagnosticsState(
    workload: workload ?? this.workload,
    sampleSize: sampleSize ?? this.sampleSize,
    batchSize: batchSize ?? this.batchSize,
    supportsIsolates: supportsIsolates ?? this.supportsIsolates,
    processorCount: processorCount ?? this.processorCount,
    isRunning: isRunning ?? this.isRunning,
    runningStrategyIndex: runningStrategyIndex ?? this.runningStrategyIndex,
    strategyCount: strategyCount ?? this.strategyCount,
    runs: runs ?? this.runs,
    error: clearError ? null : (error ?? this.error),
    test: test ?? this.test,
    repeats: repeats ?? this.repeats,
    cancelRuns: cancelRuns ?? this.cancelRuns,
    backpressureRuns: backpressureRuns ?? this.backpressureRuns,
  );
}
