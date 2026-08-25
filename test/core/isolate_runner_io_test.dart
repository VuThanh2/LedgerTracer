@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/progress_report.dart';

/// Đầu vào phải **sao chép được** để đi qua ranh giới isolate.
final class CountInput {
  const CountInput({
    required this.batches,
    this.failAtBatch,
    this.spinForever = false,
  });

  final int batches;
  final int? failAtBatch;

  /// Chạy không dừng cho tới khi có yêu cầu huỷ — để kiểm rằng tín hiệu huỷ
  /// thật sự tới được bên trong isolate.
  final bool spinForever;
}

/// **Hàm top-level, không đóng gói trạng thái nào bên ngoài** — ràng buộc cứng
/// của `Isolate.spawn`.
Future<void> countingWorkload(
  CountInput input,
  WorkloadContext<int> context,
) async {
  if (input.spinForever) {
    var i = 0;
    while (!context.isCancelled) {
      await context.emit(i++);
    }
    return;
  }
  for (var i = 0; i < input.batches; i++) {
    if (input.failAtBatch == i) throw StateError('nổ ở lô $i');
    if (context.isCancelled) return;
    await context.emit(i);
    context.reportProgress(
      ProgressReport(processed: i + 1, total: input.batches),
    );
  }
}

int doubleIt(int value) => value * 2;

/// Đây là chỗ duy nhất trong bộ test chạm tới isolate **thật**. Mọi test khác
/// dùng `MainThreadRunner` vì chúng kiểm nghiệp vụ, không kiểm cơ chế; còn ở đây
/// thứ được kiểm chính là giao thức giữa hai luồng — tín hiệu huỷ đi vào, kết
/// quả và lỗi đi ra, và hạn mức lô chờ ghi không làm hai bên kẹt nhau.
void main() {
  final runner = createIsolateRunner();

  ConcurrencyStrategy isolateStrategy({int maxPendingBatches = 2}) =>
      ConcurrencyStrategy.singleIsolate(maxPendingBatches: maxPendingBatches);

  test('nền tảng native báo có isolate và biết số nhân', () {
    expect(runner.capabilities.supportsIsolates, isTrue);
    expect(runner.capabilities.processorCount, greaterThanOrEqualTo(1));
    expect(runner.effectiveMode(isolateStrategy()), ExecutionMode.isolate);
  });

  test('kết quả từ isolate về đủ và đúng thứ tự', () async {
    final received = <int>[];
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 5),
      strategy: isolateStrategy(),
      onOutput: (output) async => received.add(output),
    );
    expect(received, <int>[0, 1, 2, 3, 4]);
  });

  test('tiến trình từ isolate về tới luồng chính', () async {
    final reports = <ProgressReport>[];
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 3),
      strategy: isolateStrategy(),
      onOutput: (output) async {},
      onProgress: reports.add,
    );
    expect(reports.map((r) => r.processed).toList(), <int>[1, 2, 3]);
    expect(reports.last.fraction, 1.0);
  });

  test('hạn mức lô chờ ghi không làm hai bên kẹt nhau', () async {
    // Isolate nhả ra nhiều lô hơn hẳn số hạn mức ban đầu. Nếu giao thức trả
    // hạn mức hỏng, chỗ này treo vĩnh viễn thay vì fail — nên nó cũng là chốt
    // chặn phát hiện deadlock.
    final received = <int>[];
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 30),
      strategy: isolateStrategy(maxPendingBatches: 1),
      onOutput: (output) async {
        // Luồng chính ghi chậm hơn isolate phân tích — đúng tình huống mà
        // backpressure sinh ra để xử lý.
        await Future<void>.delayed(Duration.zero);
        received.add(output);
      },
    );
    expect(received.length, 30);
    expect(received.first, 0);
    expect(received.last, 29);
  });

  test('lỗi bên trong isolate về như một exception có thông điệp', () async {
    // Exception qua ranh giới isolate mất stack trace, nên nó được gói lại kèm
    // stack trace dạng chuỗi thay vì để mất trắng.
    await expectLater(
      runner.runWorkload<CountInput, int>(
        entryPoint: countingWorkload,
        input: const CountInput(batches: 5, failAtBatch: 2),
        strategy: isolateStrategy(),
        onOutput: (output) async {},
      ),
      throwsA(
        isA<IsolateWorkloadException>()
            .having((e) => e.message, 'message', contains('nổ ở lô 2'))
            .having((e) => e.workloadStackTrace, 'stack', isNotNull),
      ),
    );
  });

  test('những lô nhả được trước khi hỏng vẫn tới nơi', () async {
    final received = <int>[];
    try {
      await runner.runWorkload<CountInput, int>(
        entryPoint: countingWorkload,
        input: const CountInput(batches: 5, failAtBatch: 3),
        strategy: isolateStrategy(),
        onOutput: (output) async => received.add(output),
      );
    } on IsolateWorkloadException {
      // mong đợi
    }
    expect(received, <int>[0, 1, 2]);
  });

  test('tín hiệu huỷ đi được vào bên trong isolate', () async {
    // Isolate không bị ngắt được từ bên ngoài; nó chỉ đọc tín hiệu tại ranh
    // giới giữa các lô. Test này kiểm đúng đường đi đó — nếu tín hiệu không tới
    // nơi, workload quay vô hạn và test hết giờ.
    final cancellation = CancellationSignal();
    var received = 0;
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 0, spinForever: true),
      strategy: isolateStrategy(),
      onOutput: (output) async {
        received++;
        if (received >= 3) cancellation.cancel();
      },
      cancellation: cancellation,
    );
    expect(received, greaterThanOrEqualTo(3));
  }, timeout: const Timeout(Duration(seconds: 30)));

  test('huỷ trước khi chạy thì không sinh isolate nào', () async {
    var received = 0;
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 5),
      strategy: isolateStrategy(),
      onOutput: (output) async => received++,
      cancellation: CancellationSignal.cancelled(),
    );
    expect(received, 0);
  });

  test('chiến lược luồng chính thì không đi qua isolate', () async {
    final received = <int>[];
    await runner.runWorkload<CountInput, int>(
      entryPoint: countingWorkload,
      input: const CountInput(batches: 3),
      strategy: ConcurrencyStrategy.mainThread(),
      onOutput: (output) async => received.add(output),
    );
    expect(received, <int>[0, 1, 2]);
    expect(
      runner.effectiveMode(ConcurrencyStrategy.mainThread()),
      ExecutionMode.mainThread,
    );
  });

  group('runOnce — tác vụ CPU chạy đúng một lần', () {
    test('chạy được trong isolate và trả kết quả về', () async {
      final result = await runner.runOnce<int, int>(
        task: doubleIt,
        input: 21,
        strategy: isolateStrategy(),
      );
      expect(result, 42);
    });

    test('chạy được trên luồng chính khi nền tảng không có isolate', () async {
      final result = await runner.runOnce<int, int>(
        task: doubleIt,
        input: 21,
        strategy: ConcurrencyStrategy.mainThread(),
      );
      expect(result, 42);
    });
  });
}
