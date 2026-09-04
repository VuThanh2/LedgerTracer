import 'dart:async';
import 'dart:io' show Platform;
import 'dart:isolate';

import 'cancellation_signal.dart';
import 'concurrency_strategy.dart';
import 'execution_mode.dart';
import 'isolate_runner.dart';
import 'platform_capabilities.dart';
import 'progress_report.dart';

/// Binding cho native: isolate thật, số nhân lấy từ máy.
IsolateRunner createPlatformRunner() => IsolateWorkloadRunner(
  PlatformCapabilities.native(processorCount: Platform.numberOfProcessors),
);

/// Chạy workload trong một isolate được spawn và chuyển từng lô kết quả về.
///
/// Giao thức cố ý nhỏ, vì mọi thứ đi qua ranh giới đều bị sao chép:
///
/// * worker gửi ra một control port và nhận lệnh `cancel` / `credit` trên đó;
/// * nó gửi về tiến trình và các lô kết quả;
/// * nó chỉ được gửi một lô khi còn credit, và luồng chính cấp một credit sau
///   mỗi lô nó tiêu thụ xong — toàn bộ cơ chế backpressure nằm ở đó (UC-02);
/// * lỗi về dưới dạng chuỗi, vì exception qua ranh giới thì mất kiểu và mất
///   stack trace.
final class IsolateWorkloadRunner implements IsolateRunner {
  IsolateWorkloadRunner(this.capabilities)
    : _mainThread = MainThreadRunner(capabilities);

  @override
  final PlatformCapabilities capabilities;

  /// Dùng khi strategy cố ý xin chế độ suy biến — màn hình benchmark so hai chế
  /// độ trên cùng một thiết bị.
  final MainThreadRunner _mainThread;

  @override
  ExecutionMode effectiveMode(ConcurrencyStrategy strategy) => strategy.mode;

  @override
  Future<void> runWorkload<I, O>({
    required WorkloadEntryPoint<I, O> entryPoint,
    required I input,
    required ConcurrencyStrategy strategy,
    required Future<void> Function(O output) onOutput,
    void Function(ProgressReport progress)? onProgress,
    CancellationSignal? cancellation,
  }) async {
    // Spawn ra rồi mới gửi lệnh dừng thì worker vẫn kịp làm một hai lô: lệnh huỷ
    // không thể vượt qua các thông điệp đang bay.
    if (cancellation?.isCancelled ?? false) return;
    if (strategy.mode == ExecutionMode.mainThread) {
      return _mainThread.runWorkload(
        entryPoint: entryPoint,
        input: input,
        strategy: strategy,
        onOutput: onOutput,
        onProgress: onProgress,
        cancellation: cancellation,
      );
    }

    final responses = ReceivePort();
    final isolate = await Isolate.spawn<_WorkloadBootstrap>(
      _workloadIsolateMain,
      _WorkloadBootstrap(
        responsePort: responses.sendPort,
        invoker: _TypedInvoker<I, O>(entryPoint, input),
        initialCredits: strategy.maxPendingBatches,
      ),
      // Thông báo thoát về dưới dạng `null` trên cùng cổng đó, nhờ vậy một worker
      // chết mà chưa kịp báo gì cũng không để vòng lặp này chờ mãi.
      onExit: responses.sendPort,
      errorsAreFatal: true,
      debugName: 'ledger-workload',
    );

    SendPort? control;
    StreamSubscription<void>? cancelWatch;
    try {
      await for (final message in responses) {
        switch (message) {
          case _HandshakeMessage(:final controlPort):
            control = controlPort;
            if (cancellation != null) {
              if (cancellation.isCancelled) {
                controlPort.send(_cancelCommand);
              } else {
                cancelWatch = cancellation.whenCancelled.asStream().listen(
                  (_) => controlPort.send(_cancelCommand),
                );
              }
            }
          case _OutputMessage(:final payload):
            // Chờ bên tiêu thụ xong rồi mới cấp credit kế tiếp — đó là thứ giữ
            // cho bên phân tích không chạy trước tới mức phình bộ nhớ.
            await onOutput(payload as O);
            control?.send(_creditCommand);
          case _ProgressMessage(:final report):
            onProgress?.call(report);
          case _FailureMessage(:final error, :final workloadStackTrace):
            throw IsolateWorkloadException(error, workloadStackTrace);
          case _DoneMessage():
            return;
          case null:
            throw const IsolateWorkloadException(
              'The workload isolate exited before reporting a result.',
            );
        }
      }
    } finally {
      await cancelWatch?.cancel();
      responses.close();
      isolate.kill(priority: Isolate.immediate);
    }
  }

  @override
  Future<R> runOnce<I, R>({
    required FutureOr<R> Function(I input) task,
    required I input,
    required ConcurrencyStrategy strategy,
  }) {
    if (strategy.mode == ExecutionMode.mainThread) {
      return _mainThread.runOnce(task: task, input: input, strategy: strategy);
    }
    return Isolate.run<R>(() => task(input), debugName: 'ledger-run-once');
  }
}

/// Điểm vào của isolate được spawn. Bắt buộc top-level: nó không được bắt bất cứ
/// thứ gì ngoài tham số của chính nó.
Future<void> _workloadIsolateMain(_WorkloadBootstrap bootstrap) async {
  final control = ReceivePort();
  final state = _WorkerState(bootstrap.initialCredits);
  final subscription = control.listen((message) {
    switch (message) {
      case _cancelCommand:
        state.cancel();
      case _creditCommand:
        state.grantCredit();
    }
  });
  bootstrap.responsePort.send(_HandshakeMessage(control.sendPort));

  try {
    await bootstrap.invoker.invoke(bootstrap.responsePort, state);
    bootstrap.responsePort.send(const _DoneMessage());
  } catch (error, stackTrace) {
    // Lỗi đi về như dữ liệu: ném qua ranh giới sẽ giết cả tác vụ và mất dấu vết.
    bootstrap.responsePort.send(
      _FailureMessage('$error', stackTrace.toString()),
    );
  } finally {
    await subscription.cancel();
    control.close();
  }
}

/// Mọi thứ isolate cần, gói trong một object sao chép được.
final class _WorkloadBootstrap {
  const _WorkloadBootstrap({
    required this.responsePort,
    required this.invoker,
    required this.initialCredits,
  });

  final SendPort responsePort;
  final _WorkloadInvoker invoker;
  final int initialCredits;
}

/// Xoá kiểu tham số ở ranh giới nhưng vẫn giữ nó ở nơi cần: lớp con cụ thể vẫn
/// biết `I` và `O`, nên entry point được gọi với đúng kiểu context của nó.
abstract class _WorkloadInvoker {
  Future<void> invoke(SendPort responsePort, _WorkerState state);
}

final class _TypedInvoker<I, O> implements _WorkloadInvoker {
  const _TypedInvoker(this.entryPoint, this.input);

  final WorkloadEntryPoint<I, O> entryPoint;
  final I input;

  @override
  Future<void> invoke(SendPort responsePort, _WorkerState state) =>
      entryPoint(input, _IsolateWorkloadContext<O>(responsePort, state));
}

/// Credit và cờ huỷ, nhìn từ bên trong isolate.
final class _WorkerState {
  _WorkerState(this._credits);

  int _credits;
  bool _cancelled = false;
  Completer<void>? _waiting;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    // Đánh thức bên sản xuất đang chờ chỗ trống để nó còn kết thúc gọn ghẽ.
    _wake();
  }

  void grantCredit() {
    _credits++;
    _wake();
  }

  Future<void> takeCredit() async {
    while (_credits <= 0 && !_cancelled) {
      await (_waiting ??= Completer<void>()).future;
    }
    if (_credits > 0) _credits--;
  }

  void _wake() {
    final waiting = _waiting;
    _waiting = null;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }
}

final class _IsolateWorkloadContext<O> implements WorkloadContext<O> {
  const _IsolateWorkloadContext(this._responsePort, this._state);

  final SendPort _responsePort;
  final _WorkerState _state;

  @override
  bool get isCancelled => _state.isCancelled;

  @override
  Future<void> emit(O output) async {
    await _state.takeCredit();
    if (_state.isCancelled) return;
    _responsePort.send(_OutputMessage(output));
    // Lệnh điều khiển là sự kiện chứ không phải microtask: không nhường lượt cho
    // event loop ở đây thì một yêu cầu huỷ sẽ không bao giờ được nhìn thấy. Đây
    // đúng là lý do vì sao huỷ chỉ phản hồi ở mức ranh giới lô.
    await yieldToEventLoop();
  }

  @override
  void reportProgress(ProgressReport progress) =>
      _responsePort.send(_ProgressMessage(progress));
}

const String _cancelCommand = 'cancel';
const String _creditCommand = 'credit';

final class _HandshakeMessage {
  const _HandshakeMessage(this.controlPort);

  final SendPort controlPort;
}

final class _OutputMessage {
  const _OutputMessage(this.payload);

  final Object? payload;
}

final class _ProgressMessage {
  const _ProgressMessage(this.report);

  final ProgressReport report;
}

final class _FailureMessage {
  const _FailureMessage(this.error, this.workloadStackTrace);

  final String error;
  final String workloadStackTrace;
}

final class _DoneMessage {
  const _DoneMessage();
}
