import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/progress_report.dart';
import '../../../core/result/result.dart';
import '../../shared/domain_failures.dart';
import 'run_benchmark_dto.dart';

/// Chạy một workload CPU thuần dưới từng chiến lược và đo thời gian (màn hình
/// benchmark, ngoài Domain).
///
/// Suy biến trên Web có hai hệ quả khác nhau mà báo cáo phải tách bạch: mất
/// isolate làm giảm **độ mượt giao diện**, còn mất song song nhiều file làm tăng
/// **tổng thời gian hoàn tất**. Con số ở đây đo trực tiếp cái thứ hai; cái thứ
/// nhất quan sát bằng cảm nhận khi chạy chế độ luồng chính. [BenchmarkRun.effectiveMode]
/// cho biết chế độ thật đã dùng (UC-14).
final class RunBenchmarkUseCase {
  RunBenchmarkUseCase({required this._runner});

  final IsolateRunner _runner;

  Future<Result<RunBenchmarkResult>> execute(RunBenchmarkRequest request) =>
      Result.guardAsync(() async {
        final runs = <BenchmarkRun>[];
        for (final strategy in request.strategies) {
          runs.add(await _measure(request.sampleSize, strategy));
        }
        return RunBenchmarkResult(sampleSize: request.sampleSize, runs: runs);
      }, onError: failureFromError);

  Future<BenchmarkRun> _measure(
    int sampleSize,
    ConcurrencyStrategy strategy,
  ) async {
    var processed = 0;
    final stopwatch = Stopwatch()..start();
    await _runner.runWorkload<BenchmarkInput, int>(
      entryPoint: benchmarkWorkload,
      input: BenchmarkInput(
        itemCount: sampleSize,
        batchSize: strategy.batchSize,
      ),
      strategy: strategy,
      onOutput: (count) async => processed += count,
    );
    stopwatch.stop();
    return BenchmarkRun(
      strategy: strategy,
      effectiveMode: _runner.effectiveMode(strategy),
      elapsed: stopwatch.elapsed,
      itemsProcessed: processed,
    );
  }
}

/// Đầu vào của workload benchmark. Sao chép được qua ranh giới isolate.
final class BenchmarkInput {
  const BenchmarkInput({required this.itemCount, required this.batchSize});

  final int itemCount;
  final int batchSize;
}

/// Workload tổng hợp: băm một chuỗi cho mỗi phần tử để đốt CPU một cách đo được,
/// giao kết quả theo lô đúng như hai workload thật (UC-02, UC-08).
///
/// **Bắt buộc là hàm top-level**: nó chạy trong isolate. Kết quả băm được cộng
/// dồn rồi giao đi để phép tính không bị tối ưu hoá bỏ đi.
Future<void> benchmarkWorkload(
  BenchmarkInput input,
  WorkloadContext<int> context,
) async {
  var inBatch = 0;
  var checksum = 0;
  for (var i = 0; i < input.itemCount; i++) {
    checksum = (checksum ^ _hash('row-$i-${checksum & 0xFFFF}')) & 0x7FFFFFFF;
    inBatch++;
    if (inBatch >= input.batchSize) {
      if (context.isCancelled) return;
      await context.emit(inBatch);
      context.reportProgress(
        ProgressReport(processed: i + 1, total: input.itemCount),
      );
      inBatch = 0;
    }
  }
  if (inBatch > 0) await context.emit(inBatch);
}

/// FNV-1a 32-bit, tính bằng số học thuần để nặng đều trên native lẫn Web.
int _hash(String value) {
  var hash = 2166136261;
  for (final unit in value.codeUnits) {
    hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
  }
  return hash;
}
