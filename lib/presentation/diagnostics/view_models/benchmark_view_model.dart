import '../../../application/diagnostics/run_benchmark/run_benchmark_dto.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../shared/formatting/number_formatter.dart';
import '../frame_timing_recorder.dart';

/// Hình dạng workload đem ra đo (UC-02 và UC-08 là hai hình dạng khác nhau).
///
/// Hai luồng nặng của ứng dụng có hình dạng concurrency khác hẳn nhau, nên đo
/// chúng bằng một bộ cấu hình duy nhất là đo sai: nhập sao kê là **nhiều file
/// song song**, còn quét đối soát là **một lượt duyệt CPU-bound trên toàn bảng**.
enum BenchmarkWorkload {
  /// Nhập sao kê: nhiều isolate cùng lúc, lô nhỏ để nút Huỷ còn nhạy (UC-02).
  statementImport,

  /// Quét đối soát: một isolate, lô thưa hơn vì kết quả trả về rất nhỏ (UC-08).
  reconciliationScan;

  String get label => switch (this) {
    BenchmarkWorkload.statementImport => 'Nhập sao kê (UC-02)',
    BenchmarkWorkload.reconciliationScan => 'Quét đối soát (UC-08)',
  };

  int get defaultBatchSize => switch (this) {
    BenchmarkWorkload.statementImport =>
      ConcurrencyStrategy.defaultImportBatchSize,
    BenchmarkWorkload.reconciliationScan =>
      ConcurrencyStrategy.defaultScanBatchSize,
  };

  /// Bộ cấu hình đem ra so sánh cho hình dạng này.
  ///
  /// Luôn có **cả cấu hình luồng chính**, kể cả trên native nơi isolate chạy
  /// được: đó chính là mốc so sánh: nó cho thấy Web đang trả cái giá gì, đo ngay
  /// trên cùng một thiết bị thay vì phải tin một con số từ máy khác (UC-14).
  ///
  /// Cố ý cho phép cả cấu hình tệ — parallelism cao hơn số nhân hữu ích, lô quá
  /// nhỏ. Đo một lựa chọn kém chính là mục đích của phần thực nghiệm; một danh
  /// sách chỉ toàn cấu hình tốt thì không chứng minh được điều gì.
  List<ConcurrencyStrategy> strategiesFor({
    required PlatformCapabilities capabilities,
    required int batchSize,
  }) {
    final mainThread = ConcurrencyStrategy.mainThread(batchSize: batchSize);
    if (!capabilities.supportsIsolates) {
      // Trên Web chỉ có một lựa chọn thật. Bày ra ba dòng rồi để cả ba bị hạ
      // xuống cùng một chế độ là dựng một bảng so sánh giả.
      return <ConcurrencyStrategy>[mainThread];
    }
    return switch (this) {
      BenchmarkWorkload.statementImport => <ConcurrencyStrategy>[
        mainThread,
        ConcurrencyStrategy.singleIsolate(batchSize: batchSize),
        ConcurrencyStrategy.parallelIsolates(
          parallelism: capabilities.recommendedParallelism,
          batchSize: batchSize,
        ),
      ],
      BenchmarkWorkload.reconciliationScan => <ConcurrencyStrategy>[
        mainThread,
        ConcurrencyStrategy.singleIsolate(batchSize: batchSize),
      ],
    };
  }
}

/// Một dòng kết quả đo.
final class BenchmarkRunViewModel {
  const BenchmarkRunViewModel({
    required this.modeLabel,
    required this.parallelism,
    required this.batchSize,
    required this.elapsedText,
    required this.throughputText,
    required this.batchCountText,
    required this.itemsProcessedText,
    required this.degraded,
    required this.frames,
  });

  factory BenchmarkRunViewModel.of(
    BenchmarkRun run, {
    required FrameTimingStats frames,
  }) => BenchmarkRunViewModel(
    modeLabel: _modeLabelOf(run.effectiveMode),
    parallelism: run.strategy.parallelism,
    batchSize: run.strategy.batchSize,
    elapsedText: '${run.elapsed.inMilliseconds} ms',
    throughputText:
        '${NumberFormatter.count(run.itemsPerSecond.round())} mục/giây',
    // Số lô suy ra từ cấu hình chứ không lấy từ kết quả: `BenchmarkRun` không
    // mang nó, và nó là một phép chia chính xác chứ không phải một ước lượng —
    // workload giao đúng một lô mỗi [batchSize] phần tử.
    batchCountText: NumberFormatter.count(
      (run.itemsProcessed / run.strategy.batchSize).ceil(),
    ),
    itemsProcessedText: NumberFormatter.count(run.itemsProcessed),
    // Xin isolate mà nhận về luồng chính: nói thẳng ra thay vì giấu (UC-14).
    degraded: run.strategy.mode == ExecutionMode.isolate &&
        run.effectiveMode == ExecutionMode.mainThread,
    frames: frames,
  );

  final String modeLabel;
  final int parallelism;
  final int batchSize;
  final String elapsedText;
  final String throughputText;
  final String batchCountText;
  final String itemsProcessedText;

  /// Cấu hình xin isolate nhưng nền tảng chỉ cho luồng chính.
  final bool degraded;

  /// Thống kê khung hình đo được **trong lúc** lượt này chạy — hệ quả thứ hai
  /// của việc mất isolate, thứ mà tổng thời gian không nói ra được.
  final FrameTimingStats frames;

  static String _modeLabelOf(ExecutionMode mode) => switch (mode) {
    ExecutionMode.isolate => 'Isolate nền',
    ExecutionMode.mainThread => 'Luồng giao diện',
  };
}
