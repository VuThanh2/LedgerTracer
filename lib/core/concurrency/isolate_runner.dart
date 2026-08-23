import 'dart:async';

import 'cancellation_signal.dart';
import 'concurrency_strategy.dart';
import 'execution_mode.dart';
import 'platform_capabilities.dart';
import 'progress_report.dart';
// Platform binding: isolate thật ở nơi có `dart:isolate`, còn lại thì chạy trên
// luồng chính.
import 'isolate_runner_stub.dart'
    if (dart.library.io) 'isolate_runner_io.dart'
    if (dart.library.js_interop) 'isolate_runner_web.dart'
    as platform;

/// Một workload, nhìn từ bên trong.
///
/// Hàm workload nhận toàn bộ đầu vào qua tham số và báo ra ngoài qua context
/// này; nó không được đọc thêm bất cứ thứ gì khác. Đó là ràng buộc cứng của
/// `Isolate.spawn`, và nó kéo theo một hệ quả kiến trúc thật: workload không với
/// tới được repository, biến toàn cục hay DI container — parser được đưa sẵn
/// bytes chứ không tự mở file.
///
/// Cả hai phương thức đều là ranh giới lô. [emit] là chỗ bên sản xuất đứng chờ
/// khi bên tiêu thụ còn bận, và việc `await` nó cũng chính là điều kiện để một
/// yêu cầu huỷ được nhìn thấy — isolate chỉ biết chuyện bên ngoài giữa hai lượt
/// event loop của chính nó.
abstract interface class WorkloadContext<O> {
  /// Giao diện đã yêu cầu dừng hay chưa. Kiểm mỗi lô một lần; workload nào phớt
  /// lờ thì đơn giản là chạy tới hết.
  bool get isCancelled;

  /// Giao một lô kết quả cho bên tiêu thụ.
  ///
  /// Future trả về chỉ hoàn tất khi đã có chỗ cho lô tiếp theo, nên `await` nó
  /// **chính là** backpressure: phân tích tạm dừng cho tới khi việc ghi bắt kịp
  /// (UC-02).
  Future<void> emit(O output);

  /// Báo tiến trình. Rẻ, nhưng vẫn là một lần sao chép qua ranh giới, nên thuộc
  /// về ranh giới lô chứ không phải từng dòng.
  void reportProgress(ProgressReport progress);
}

/// Dạng hàm mà một workload phải được viết ra.
///
/// **Bắt buộc là hàm top-level hoặc static**: `Isolate.spawn` không gửi được
/// closure có bắt trạng thái bên ngoài.
typedef WorkloadEntryPoint<I, O> = Future<void> Function(
  I input,
  WorkloadContext<O> context,
);

/// Chạy một workload ngoài luồng giao diện khi nền tảng cho phép.
///
/// Abstraction này tồn tại vì hai lý do đều hiện ra trong báo cáo: Web không có
/// isolate nên phải suy biến, và màn hình benchmark cần chạy đúng một workload
/// dưới nhiều strategy khác nhau trên cùng một thiết bị.
abstract interface class IsolateRunner {
  PlatformCapabilities get capabilities;

  /// Chế độ **thực sự** được dùng cho [strategy] ở đây — xin
  /// [ExecutionMode.isolate] trên Web thì nhận về [ExecutionMode.mainThread].
  /// Giao diện đọc giá trị này để nói thẳng giới hạn thay vì giấu nó (UC-14).
  ExecutionMode effectiveMode(ConcurrencyStrategy strategy);

  /// Chạy [entryPoint] trên [input], giao từng lô cho [onOutput] **đúng thứ
  /// tự** và chờ nó trước khi để số lô đang bay vượt quá
  /// [ConcurrencyStrategy.maxPendingBatches].
  ///
  /// Hoàn tất bình thường khi workload trả về, kể cả khi nó trả về sớm vì
  /// [cancellation] đã bật — huỷ thì phần đã ghi vẫn giữ, nên người gọi đọc tín
  /// hiệu chứ không bắt exception (UC-02 bước 7). Nếu [cancellation] đã bật ngay
  /// lúc gọi thì workload không hề khởi chạy: spawn ra rồi mới bảo dừng vẫn tốn
  /// một hai lô, vì yêu cầu huỷ không thể vượt qua các thông điệp đang bay.
  ///
  /// Ném [IsolateWorkloadException] khi chính workload hỏng, và ném lại nguyên
  /// vẹn thứ mà [onOutput] ném ra sau khi đã dừng workload.
  Future<void> runWorkload<I, O>({
    required WorkloadEntryPoint<I, O> entryPoint,
    required I input,
    required ConcurrencyStrategy strategy,
    required Future<void> Function(O output) onOutput,
    void Function(ProgressReport progress)? onProgress,
    CancellationSignal? cancellation,
  });

  /// Việc một phát ăn ngay, một kết quả, không có tiến trình: sinh file xuất
  /// (UC-11) hoặc mã hoá file sao lưu (UC-13).
  ///
  /// [task] phải là hàm top-level hoặc static, còn [input] và kết quả phải sao
  /// chép được qua ranh giới.
  Future<R> runOnce<I, R>({
    required FutureOr<R> Function(I input) task,
    required I input,
    required ConcurrencyStrategy strategy,
  });
}

/// Runner của nền tảng hiện tại: dùng isolate trên native, luồng chính trên Web.
IsolateRunner createIsolateRunner() => platform.createPlatformRunner();

/// Chạy workload ngay trên luồng đang gọi, nhường lượt về event loop giữa các
/// lô.
///
/// Đây là toàn bộ phần hiện thực cho Web, và cũng là thứ runner native uỷ thác
/// tới khi strategy cố ý yêu cầu [ExecutionMode.mainThread] — cách để benchmark
/// đo cả hai chế độ trên cùng một thiết bị.
///
/// Suy biến có hai hệ quả khác nhau mà báo cáo phải tách bạch: mất isolate làm
/// giảm **độ mượt giao diện**, còn mất song song nhiều file làm tăng **tổng thời
/// gian hoàn tất**.
final class MainThreadRunner implements IsolateRunner {
  const MainThreadRunner(this.capabilities);

  @override
  final PlatformCapabilities capabilities;

  @override
  ExecutionMode effectiveMode(ConcurrencyStrategy strategy) =>
      ExecutionMode.mainThread;

  @override
  Future<void> runWorkload<I, O>({
    required WorkloadEntryPoint<I, O> entryPoint,
    required I input,
    required ConcurrencyStrategy strategy,
    required Future<void> Function(O output) onOutput,
    void Function(ProgressReport progress)? onProgress,
    CancellationSignal? cancellation,
  }) async {
    if (cancellation?.isCancelled ?? false) return;
    final context = _MainThreadContext<O>(
      onOutput: onOutput,
      onProgress: onProgress,
      cancellation: cancellation,
    );
    await entryPoint(input, context);
  }

  @override
  Future<R> runOnce<I, R>({
    required FutureOr<R> Function(I input) task,
    required I input,
    required ConcurrencyStrategy strategy,
  }) async {
    // Để khung hình vừa khởi động công việc được vẽ xong rồi mới chặn nó.
    await yieldToEventLoop();
    return task(input);
  }
}

/// Trả luồng về cho event loop để khung hình, cú chạm và timer đang chờ được tới
/// lượt. Một microtask thì không đủ — chúng chạy trước khi event loop kịp nhận
/// bất kỳ sự kiện mới nào.
Future<void> yieldToEventLoop() => Future<void>.delayed(Duration.zero);

/// Một workload hỏng bên trong isolate của nó.
///
/// Lỗi gốc không ném lại nguyên vẹn được: exception đi qua ranh giới isolate thì
/// mất kiểu và mất stack trace, nên cả hai về đây dưới dạng chuỗi.
final class IsolateWorkloadException implements Exception {
  const IsolateWorkloadException(this.message, [this.workloadStackTrace]);

  final String message;

  /// Stack trace đúng như nó được in ra bên trong isolate.
  final String? workloadStackTrace;

  @override
  String toString() => 'IsolateWorkloadException: $message';
}

final class _MainThreadContext<O> implements WorkloadContext<O> {
  _MainThreadContext({
    required this.onOutput,
    required this.onProgress,
    required this.cancellation,
  });

  final Future<void> Function(O output) onOutput;
  final void Function(ProgressReport progress)? onProgress;
  final CancellationSignal? cancellation;

  @override
  bool get isCancelled => cancellation?.isCancelled ?? false;

  @override
  Future<void> emit(O output) async {
    await onOutput(output);
    // Không có gì để điều tiết ở đây — sản xuất và tiêu thụ chung một luồng nên
    // không bên nào chạy nhanh hơn bên kia. Lần nhường lượt này là dành cho giao
    // diện, không phải cho bộ nhớ.
    await yieldToEventLoop();
  }

  @override
  void reportProgress(ProgressReport progress) => onProgress?.call(progress);
}
