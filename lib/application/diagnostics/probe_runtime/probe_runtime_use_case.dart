import 'dart:async';

import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/result/result.dart';
import '../../shared/domain_failures.dart';
import '../run_benchmark/run_benchmark_use_case.dart';
import 'probe_runtime_dto.dart';

/// Hai phép đo hành vi của bộ chạy workload mà `RunBenchmarkUseCase` không đo
/// được: huỷ phản hồi nhanh tới đâu, và hàng đợi chờ ghi phình tới đâu.
///
/// ## Chỉ đứng ngoài quan sát
///
/// Cả hai phép đo đi qua **đúng API công khai** mà luồng nhập và luồng đối soát
/// thật đang dùng — `IsolateRunner.runWorkload` với một `CancellationSignal`
/// và một `onOutput` bất đồng bộ. Không có móc đo nào được cài vào bộ chạy: một
/// phép đo phải sửa chính thứ nó đo thì không còn đo thứ đang chạy thật nữa.
///
/// Phép đo huỷ dùng lại nguyên [benchmarkWorkload], workload của bảng hiệu năng
/// — cùng một khối CPU, chỉ khác là bị huỷ giữa chừng.
final class ProbeRuntimeUseCase {
  ProbeRuntimeUseCase({required this._runner});

  final IsolateRunner _runner;

  /// Lệnh huỷ được phát khi bên tiêu thụ đã nhận được phần này của workload.
  /// Một phần tư: đủ xa điểm khởi động để isolate đã chạy đều, đủ xa điểm kết
  /// thúc để workload không tự xong trước khi kịp thấy lệnh.
  static const double cancelAtFraction = 0.25;

  /// Thời gian giả lập cho việc ghi một lô vào cơ sở dữ liệu. Chỉ cần chậm hơn
  /// việc phân tích một lô là đủ để hàng đợi có cơ hội dồn lại.
  static const Duration simulatedWriteTime = Duration(milliseconds: 4);

  /// "Không giới hạn" trong thực tế: lớn hơn mọi số lô mà một lượt đo sinh ra.
  static const int uncappedPendingBatches = 1 << 30;

  Future<Result<CancelProbeRun>> measureCancellation({
    required int sampleSize,
    required ConcurrencyStrategy strategy,
  }) => Result.guardAsync(() async {
    final signal = CancellationSignal();
    final cancelAt = (sampleSize * cancelAtFraction).ceil();
    var received = 0;
    int? receivedAtCancel;
    final sinceCancel = Stopwatch();

    await _runner.runWorkload<BenchmarkInput, int>(
      entryPoint: benchmarkWorkload,
      input: BenchmarkInput(
        itemCount: sampleSize,
        batchSize: strategy.batchSize,
      ),
      strategy: strategy,
      cancellation: signal,
      onOutput: (count) async {
        received += count;
        if (receivedAtCancel == null && received >= cancelAt) {
          receivedAtCancel = received;
          sinceCancel.start();
          signal.cancel();
        }
      },
    );
    sinceCancel.stop();

    final atCancel = receivedAtCancel ?? received;
    return CancelProbeRun(
      strategy: strategy,
      effectiveMode: _runner.effectiveMode(strategy),
      latency: sinceCancel.elapsed,
      itemsAtCancel: atCancel,
      itemsAfterCancel: received - atCancel,
    );
  }, onError: failureFromError);

  /// Đo hàng đợi dưới [strategy], giữ nguyên giới hạn của nó nếu [capped], hoặc
  /// thay bằng [uncappedPendingBatches] để thấy chuyện gì xảy ra khi không có.
  Future<Result<BackpressureProbeRun>> measureBackpressure({
    required int sampleSize,
    required ConcurrencyStrategy strategy,
    required bool capped,
  }) => Result.guardAsync(() async {
    final measured = capped
        ? strategy
        : ConcurrencyStrategy(
            mode: strategy.mode,
            parallelism: strategy.parallelism,
            batchSize: strategy.batchSize,
            maxPendingBatches: uncappedPendingBatches,
          );

    // Mốc thời gian dùng đồng hồ tường vì nó là đồng hồ duy nhất mà isolate
    // phân tích và luồng chính cùng đọc được; `Stopwatch` không đi qua ranh
    // giới isolate.
    final startedAt = DateTime.now().microsecondsSinceEpoch;
    final emittedAt = <int>[];
    final consumedAt = <int>[];

    await _runner.runWorkload<TimedBatchInput, List<int>>(
      entryPoint: timedBatchWorkload,
      input: TimedBatchInput(
        itemCount: sampleSize,
        batchSize: measured.batchSize,
      ),
      strategy: measured,
      onOutput: (batch) async {
        emittedAt.add(batch[1]);
        await Future<void>.delayed(simulatedWriteTime);
        consumedAt.add(DateTime.now().microsecondsSinceEpoch);
      },
    );

    return BackpressureProbeRun(
      strategy: measured,
      effectiveMode: _runner.effectiveMode(measured),
      isCapped: capped,
      peakPendingBatches: peakPending(emittedAt, consumedAt),
      producerFinishedAfter: Duration(
        microseconds: emittedAt.isEmpty ? 0 : emittedAt.last - startedAt,
      ),
      consumerFinishedAfter: Duration(
        microseconds: consumedAt.isEmpty ? 0 : consumedAt.last - startedAt,
      ),
    );
  }, onError: failureFromError);

  /// Số lô đã gửi mà chưa ghi xong, lớn nhất tại một thời điểm.
  ///
  /// Hai dãy mốc thời gian được trộn theo thứ tự; gặp mốc gửi thì cộng, gặp mốc
  /// ghi xong thì trừ. Hai mốc trùng nhau thì trừ trước — một lô ghi xong đúng
  /// lúc lô sau được gửi không phải là hai lô cùng nằm chờ.
  static int peakPending(List<int> emittedAt, List<int> consumedAt) {
    final emitted = <int>[...emittedAt]..sort();
    final consumed = <int>[...consumedAt]..sort();
    var e = 0;
    var c = 0;
    var pending = 0;
    var peak = 0;
    while (e < emitted.length) {
      if (c < consumed.length && consumed[c] <= emitted[e]) {
        pending--;
        c++;
      } else {
        pending++;
        e++;
        if (pending > peak) peak = pending;
      }
    }
    return peak;
  }
}

/// Đầu vào của [timedBatchWorkload]. Sao chép được qua ranh giới isolate.
final class TimedBatchInput {
  const TimedBatchInput({required this.itemCount, required this.batchSize});

  final int itemCount;
  final int batchSize;
}

/// Workload của phép đo hàng đợi: cùng kiểu tải CPU với [benchmarkWorkload],
/// nhưng mỗi lô mang theo **thời điểm nó được gửi đi**.
///
/// Là workload riêng chứ không sửa [benchmarkWorkload] để bảng hiệu năng vẫn đo
/// đúng thứ nó đã đo. Lô là `[số phần tử, mốc gửi tính bằng µs]` — một danh
/// sách số nguyên đi qua ranh giới isolate mà không cần kiểu riêng.
///
/// **Bắt buộc là hàm top-level**: nó chạy trong isolate.
Future<void> timedBatchWorkload(
  TimedBatchInput input,
  WorkloadContext<List<int>> context,
) async {
  var inBatch = 0;
  var checksum = 0;
  Future<void> send() => context.emit(<int>[
    inBatch,
    DateTime.now().microsecondsSinceEpoch,
    // Giao cả checksum để phép tính không bị trình biên dịch lược bỏ.
    checksum,
  ]);

  for (var i = 0; i < input.itemCount; i++) {
    var hash = 2166136261;
    for (final unit in 'row-$i-${checksum & 0xFFFF}'.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0xFFFFFFFF;
    }
    checksum = (checksum ^ hash) & 0x7FFFFFFF;
    inBatch++;
    if (inBatch >= input.batchSize) {
      if (context.isCancelled) return;
      await send();
      inBatch = 0;
    }
  }
  if (inBatch > 0) await send();
}
