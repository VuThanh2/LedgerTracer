import 'dart:async';

import 'cancellation_signal.dart';
import 'concurrency_strategy.dart';
import 'isolate_runner.dart';
import 'progress_report.dart';

/// Một workload của lượt chạy đã kết thúc như thế nào.
enum WorkloadStatus {
  /// Chạy tới hết.
  completed,

  /// Lượt chạy bị huỷ khi workload này đang dở; những gì nó đã giao thì vẫn giữ.
  ///
  /// Workload vừa kịp làm xong đúng lúc lệnh huỷ tới cũng mang nhãn này — từ bên
  /// ngoài không phân biệt được hai trường hợp. Khi cần phân biệt, cờ báo hết dữ
  /// liệu của chính workload (lô nhập có mang cờ đó) mới là nguồn sự thật.
  cancelled,

  /// Nó ném lỗi. Các workload khác trong cùng lượt không bị ảnh hưởng.
  failed,

  /// Lượt chạy đã bị huỷ trước khi tới lượt nó, nên nó chưa từng khởi chạy.
  skipped,
}

/// Chuyện gì đã xảy ra với một đầu vào của lượt chạy.
final class WorkloadOutcome<I> {
  const WorkloadOutcome({
    required this.index,
    required this.input,
    required this.status,
    this.error,
    this.stackTrace,
  });

  /// Vị trí trong danh sách đưa cho scheduler — với một lượt nhập, đó là thứ tự
  /// người dùng chọn file.
  final int index;

  final I input;

  final WorkloadStatus status;

  /// Chỉ có giá trị khi [status] là [WorkloadStatus.failed].
  final Object? error;

  final StackTrace? stackTrace;

  @override
  String toString() =>
      'WorkloadOutcome($index, ${status.name}${error == null ? '' : ', $error'})';
}

/// Chạy cùng một workload trên nhiều đầu vào: **sản xuất song song**, **tiêu thụ
/// đúng thứ tự đầu vào**.
///
/// Cặp tính chất đó không phải xa xỉ, nó là thứ giữ cho hai luật của luồng nhập
/// cùng đúng một lúc (UC-02):
///
/// * các file phải được phân tích song song, vì phân tích là phần tốn kém;
/// * kết quả phải được *ghi* theo đúng thứ tự người dùng chọn file, vì chống
///   trùng phụ thuộc vào những gì đã có trong cơ sở dữ liệu — để thứ tự ghi chạy
///   theo isolate nào xong trước thì hai lần nhập cùng một tập file sẽ cho hai
///   kết quả khác nhau, và loại lỗi đó không bao giờ tái hiện được để mà gỡ
///   (Rule – Write Order Is Deterministic).
///
/// Giữ được cả hai là nhờ chính việc giao hàng mới cấp chỗ cho bên sản xuất chạy
/// tiếp: workload chưa tới lượt sẽ tự chặn sau [ConcurrencyStrategy.maxPendingBatches]
/// lô thay vì gom cả file vào bộ nhớ.
///
/// Scheduler cũng gánh hai luật cấp-lượt-chạy rất dễ làm sai: workload chưa khởi
/// chạy lúc người dùng huỷ thì bị bỏ qua hoàn toàn, và một workload hỏng không
/// kéo cả lượt chết theo — mỗi đầu vào có [WorkloadOutcome] riêng.
final class WorkloadScheduler {
  const WorkloadScheduler(this.runner);

  final IsolateRunner runner;

  /// Chạy [entryPoint] trên từng phần tử của [inputs].
  ///
  /// Nhiều nhất [ConcurrencyStrategy.parallelism] workload chạy cùng lúc. Kết
  /// quả tới [onOutput] mỗi lần một lô, theo thứ tự đầu vào, và danh sách trả về
  /// cũng theo thứ tự đầu vào.
  Future<List<WorkloadOutcome<I>>> runAll<I, O>({
    required WorkloadEntryPoint<I, O> entryPoint,
    required List<I> inputs,
    required ConcurrencyStrategy strategy,
    required Future<void> Function(int index, I input, O output) onOutput,
    void Function(int index, I input, ProgressReport progress)? onProgress,
    CancellationSignal? cancellation,
  }) async {
    if (inputs.isEmpty) return const [];

    final outcomes = List<WorkloadOutcome<I>?>.filled(inputs.length, null);
    final turnstile = _DeliveryTurnstile();
    var nextIndex = 0;

    Future<void> runAt(int index) async {
      final input = inputs[index];
      if (cancellation?.isCancelled ?? false) {
        outcomes[index] = WorkloadOutcome<I>(
          index: index,
          input: input,
          status: WorkloadStatus.skipped,
        );
        return;
      }
      try {
        await runner.runWorkload<I, O>(
          entryPoint: entryPoint,
          input: input,
          strategy: strategy,
          onOutput: (output) async {
            await turnstile.awaitTurn(index);
            await onOutput(index, input, output);
          },
          onProgress: onProgress == null
              ? null
              : (progress) => onProgress(index, input, progress),
          cancellation: cancellation,
        );
        outcomes[index] = WorkloadOutcome<I>(
          index: index,
          input: input,
          // Workload trả về bình thường dù nó chạy hết hay dừng theo yêu cầu;
          // tín hiệu huỷ là thứ phân biệt hai trường hợp.
          status: (cancellation?.isCancelled ?? false)
              ? WorkloadStatus.cancelled
              : WorkloadStatus.completed,
        );
      } catch (error, stackTrace) {
        outcomes[index] = WorkloadOutcome<I>(
          index: index,
          input: input,
          status: WorkloadStatus.failed,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    // Dùng worker pool thay vì từng đợt `Future.wait`: worker xong việc nhận
    // ngay đầu vào kế tiếp chứ không đứng chờ kẻ chậm nhất trong đợt của mình.
    // Chỉ số luôn được lấy tăng dần, nên đầu vào đang tới lượt giao hàng luôn là
    // một đầu vào đã khởi chạy — thứ tự giao hàng không thể làm kẹt pool.
    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= inputs.length) return;
        try {
          await runAt(index);
        } finally {
          turnstile.finish(index);
        }
      }
    }

    final workerCount = strategy.parallelism < inputs.length
        ? strategy.parallelism
        : inputs.length;
    await Future.wait<void>([
      for (var slot = 0; slot < workerCount; slot++) worker(),
    ]);

    return <WorkloadOutcome<I>>[for (final outcome in outcomes) outcome!];
  }
}

/// Chỉ cho lô của workload thứ `n` đi qua khi mọi workload trước nó đã giao hàng
/// xong.
final class _DeliveryTurnstile {
  int _current = 0;
  final Set<int> _finished = <int>{};
  final Map<int, Completer<void>> _waiting = <int, Completer<void>>{};

  Future<void> awaitTurn(int index) async {
    while (_current != index) {
      await (_waiting[index] ??= Completer<void>()).future;
    }
  }

  /// Đánh dấu một workload đã giao hàng xong và trao lượt cho workload kế tiếp
  /// còn đang chờ. Các workload có thể kết thúc không theo thứ tự — một workload
  /// không có lô nào sẽ xong từ rất lâu trước lượt của nó — nên con trỏ nhảy qua
  /// tất cả những gì đã xong.
  void finish(int index) {
    _finished.add(index);
    while (_finished.contains(_current)) {
      _current++;
      final waiter = _waiting.remove(_current);
      if (waiter != null && !waiter.isCompleted) waiter.complete();
    }
  }
}
