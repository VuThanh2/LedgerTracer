import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/progress_report.dart';
import 'package:ledger_tracer/core/concurrency/workload_scheduler.dart';

/// Đầu vào của workload test: nhả ra vài lô mang nhãn của chính nó.
final class _Job {
  const _Job(this.name, this.batches, {this.failAtBatch});

  final String name;
  final int batches;

  /// Chỉ số lô mà workload sẽ nổ, để kiểm tra một đầu vào hỏng không kéo cả
  /// lượt chết theo.
  final int? failAtBatch;
}

/// **Hàm top-level**, đúng như ràng buộc của mọi workload chạy trong isolate.
Future<void> _emitLabelledBatches(_Job job, WorkloadContext<String> context) async {
  for (var i = 0; i < job.batches; i++) {
    if (job.failAtBatch == i) throw StateError('${job.name} hỏng ở lô $i');
    if (context.isCancelled) return;
    await context.emit('${job.name}#$i');
    context.reportProgress(ProgressReport(processed: i + 1, total: job.batches));
  }
}

void main() {
  const runner = MainThreadRunner(PlatformCapabilities.web());
  const scheduler = WorkloadScheduler(runner);

  // Runner ở đây là loại chạy trên luồng chính, nên `mode` chỉ còn ý nghĩa khai
  // báo; thứ thật sự được test là cách scheduler điều phối theo `parallelism`.
  ConcurrencyStrategy strategy({int parallelism = 3}) => ConcurrencyStrategy(
    mode: ExecutionMode.mainThread,
    parallelism: parallelism,
    batchSize: 10,
    maxPendingBatches: 2,
  );

  group('giao hàng theo thứ tự đầu vào', () {
    test('mọi lô của đầu vào trước đến hết rồi mới tới đầu vào sau', () async {
      // Đây là nền của Rule – Write Order Is Deterministic: phân tích chạy song
      // song, nhưng khâu ghi thấy dữ liệu theo đúng thứ tự người dùng chọn file.
      final delivered = <String>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 3), _Job('b', 3), _Job('c', 3)],
        strategy: strategy(),
        onOutput: (index, input, output) async => delivered.add(output),
      );
      expect(delivered, <String>[
        'a#0', 'a#1', 'a#2',
        'b#0', 'b#1', 'b#2',
        'c#0', 'c#1', 'c#2',
      ]);
    });

    test('đầu vào không nhả lô nào không chặn những đầu vào sau', () async {
      final delivered = <String>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('rong', 0), _Job('b', 2)],
        strategy: strategy(),
        onOutput: (index, input, output) async => delivered.add(output),
      );
      expect(delivered, <String>['b#0', 'b#1']);
    });

    test('chỉ số đi kèm mỗi lô trỏ đúng đầu vào sinh ra nó', () async {
      final pairs = <String>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 1), _Job('b', 1)],
        strategy: strategy(),
        onOutput: (index, input, output) async =>
            pairs.add('$index:${input.name}:$output'),
      );
      expect(pairs, <String>['0:a:a#0', '1:b:b#0']);
    });
  });

  group('kết cục', () {
    test('trả về đúng một kết cục cho mỗi đầu vào, theo thứ tự đầu vào', () async {
      final outcomes = await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 1), _Job('b', 1), _Job('c', 1)],
        strategy: strategy(),
        onOutput: (index, input, output) async {},
      );
      expect(outcomes.length, 3);
      expect(outcomes.map((o) => o.index).toList(), <int>[0, 1, 2]);
      expect(outcomes.map((o) => o.input.name).toList(), <String>['a', 'b', 'c']);
      expect(
        outcomes.every((o) => o.status == WorkloadStatus.completed),
        isTrue,
      );
    });

    test('onOutcome báo ngay khi một đầu vào xong, không đợi cả lượt', () async {
      // Đây là thứ duy nhất đếm được "đã xong bao nhiêu file" trong lúc chạy;
      // danh sách trả về chỉ có sau khi toàn bộ lượt kết thúc.
      final finishedWhileRunning = <String>[];
      final seenBeforeLastOutput = <int>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 2), _Job('b', 2)],
        strategy: strategy(),
        onOutput: (index, input, output) async =>
            seenBeforeLastOutput.add(finishedWhileRunning.length),
        onOutcome: (outcome) => finishedWhileRunning.add(outcome.input.name),
      );
      expect(finishedWhileRunning, <String>['a', 'b']);
      // Hai lô của 'b' được giao sau khi 'a' đã chốt kết cục.
      expect(seenBeforeLastOutput, <int>[0, 0, 1, 1]);
    });

    test('một đầu vào hỏng không kéo những đầu vào khác chết theo', () async {
      final delivered = <String>[];
      final outcomes = await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[
          _Job('a', 2),
          _Job('b', 3, failAtBatch: 1),
          _Job('c', 2),
        ],
        strategy: strategy(),
        onOutput: (index, input, output) async => delivered.add(output),
      );
      expect(outcomes[0].status, WorkloadStatus.completed);
      expect(outcomes[1].status, WorkloadStatus.failed);
      expect(outcomes[1].error, isA<StateError>());
      expect(outcomes[1].stackTrace, isNotNull);
      expect(outcomes[2].status, WorkloadStatus.completed);
      // Phần 'b' đã nhả được trước khi hỏng vẫn tới nơi, và 'c' vẫn chạy đủ.
      expect(delivered, <String>['a#0', 'a#1', 'b#0', 'c#0', 'c#1']);
    });

    test('đầu vào hỏng ngay lô đầu vẫn không chặn cổng giao hàng', () async {
      final delivered = <String>[];
      final outcomes = await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 2, failAtBatch: 0), _Job('b', 2)],
        strategy: strategy(),
        onOutput: (index, input, output) async => delivered.add(output),
      );
      expect(outcomes[0].status, WorkloadStatus.failed);
      expect(delivered, <String>['b#0', 'b#1']);
    });
  });

  group('huỷ', () {
    test('đầu vào chưa bắt đầu bị bỏ qua hoàn toàn', () async {
      // "File đã hoàn tất giữ nguyên, file đang xử lý giữ phần đã xong, file
      // chưa bắt đầu bị bỏ qua hoàn toàn."
      final cancellation = CancellationSignal();
      final delivered = <String>[];
      final outcomes = await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 2), _Job('b', 2), _Job('c', 2)],
        strategy: strategy(parallelism: 1),
        onOutput: (index, input, output) async {
          delivered.add(output);
          if (output == 'a#1') cancellation.cancel();
        },
        cancellation: cancellation,
      );
      expect(delivered, <String>['a#0', 'a#1']);
      expect(outcomes[0].status, WorkloadStatus.cancelled);
      expect(outcomes[1].status, WorkloadStatus.skipped);
      expect(outcomes[2].status, WorkloadStatus.skipped);
    });

    test('huỷ trước khi chạy thì không đầu vào nào được xử lý', () async {
      final delivered = <String>[];
      final outcomes = await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 2), _Job('b', 2)],
        strategy: strategy(),
        onOutput: (index, input, output) async => delivered.add(output),
        cancellation: CancellationSignal.cancelled(),
      );
      expect(delivered, isEmpty);
      expect(
        outcomes.every((o) => o.status == WorkloadStatus.skipped),
        isTrue,
      );
    });

    test('kết cục vẫn được báo cho cả đầu vào bị bỏ qua', () async {
      final reported = <WorkloadStatus>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 1), _Job('b', 1)],
        strategy: strategy(),
        onOutput: (index, input, output) async {},
        onOutcome: (outcome) => reported.add(outcome.status),
        cancellation: CancellationSignal.cancelled(),
      );
      expect(reported, <WorkloadStatus>[
        WorkloadStatus.skipped,
        WorkloadStatus.skipped,
      ]);
    });
  });

  group('tiến trình', () {
    test('báo kèm chỉ số và đầu vào tương ứng', () async {
      final reports = <String>[];
      await scheduler.runAll<_Job, String>(
        entryPoint: _emitLabelledBatches,
        inputs: const <_Job>[_Job('a', 2)],
        strategy: strategy(),
        onOutput: (index, input, output) async {},
        onProgress: (index, input, progress) =>
            reports.add('$index:${input.name}:${progress.processed}'),
      );
      expect(reports, <String>['0:a:1', '0:a:2']);
    });
  });

  test('không có đầu vào nào thì trả danh sách rỗng', () async {
    final outcomes = await scheduler.runAll<_Job, String>(
      entryPoint: _emitLabelledBatches,
      inputs: const <_Job>[],
      strategy: strategy(),
      onOutput: (index, input, output) async {},
    );
    expect(outcomes, isEmpty);
  });

  test('số worker không vượt quá số đầu vào', () async {
    // Yêu cầu 8 worker cho 2 đầu vào không được sinh ra 6 worker chạy không.
    final outcomes = await scheduler.runAll<_Job, String>(
      entryPoint: _emitLabelledBatches,
      inputs: const <_Job>[_Job('a', 1), _Job('b', 1)],
      strategy: strategy(parallelism: 8),
      onOutput: (index, input, output) async {},
    );
    expect(outcomes.length, 2);
  });
}
