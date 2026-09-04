import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';

/// Một lượt đo so sánh các chiến lược concurrency trên cùng một thiết bị.
///
/// Màn hình benchmark cố ý **nằm ngoài Domain**: nó chạy một workload CPU thuần
/// dưới nhiều cấu hình để đo đánh đổi, không sinh ra khái niệm nghiệp vụ nào. Đây
/// là chỗ báo cáo lấy số liệu so sánh isolate với luồng chính, và cho thấy chiều
/// suy biến trên Web (UC-14).
final class RunBenchmarkRequest {
  const RunBenchmarkRequest({
    required this.sampleSize,
    required this.strategies,
  }) : assert(sampleSize > 0, 'benchmark needs something to chew on');

  /// Số phần tử của workload tổng hợp — càng lớn chênh lệch càng rõ.
  final int sampleSize;

  /// Các cấu hình đem ra đo. Cố ý cho phép cả cấu hình tệ: đo một lựa chọn kém
  /// chính là mục đích của phần thực nghiệm.
  final List<ConcurrencyStrategy> strategies;
}

/// Kết quả đo một chiến lược.
final class BenchmarkRun {
  const BenchmarkRun({
    required this.strategy,
    required this.effectiveMode,
    required this.elapsed,
    required this.itemsProcessed,
  });

  final ConcurrencyStrategy strategy;

  /// Chế độ **thực sự** được dùng — xin isolate trên Web thì nhận về luồng chính,
  /// và con số này là thứ nói thẳng điều đó thay vì giấu (UC-14).
  final ExecutionMode effectiveMode;

  final Duration elapsed;

  final int itemsProcessed;

  double get itemsPerSecond {
    final micros = elapsed.inMicroseconds;
    return micros == 0 ? 0 : itemsProcessed * 1000000 / micros;
  }
}

final class RunBenchmarkResult {
  const RunBenchmarkResult({required this.sampleSize, required this.runs});

  final int sampleSize;
  final List<BenchmarkRun> runs;
}
