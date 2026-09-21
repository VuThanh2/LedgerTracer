import '../../../application/diagnostics/probe_runtime/probe_runtime_dto.dart';
import '../../../application/diagnostics/probe_runtime/probe_runtime_use_case.dart';
import '../../../core/concurrency/execution_mode.dart';
import '../../shared/formatting/number_formatter.dart';

/// Phép đo nào đang được chọn trên màn Diagnostics.
///
/// Ba phép đo trả lời ba câu hỏi khác nhau về cùng một bộ chạy, nên chúng có ba
/// bảng kết quả riêng thay vì dồn chung một bảng nhiều cột trống.
enum DiagnosticsTest {
  /// Bảng hiệu năng có sẵn: tổng thời gian, thông lượng, khung hình.
  throughput,

  /// Nút Huỷ phản hồi sau bao lâu, theo từng cỡ lô (UC-02, UC-14).
  cancellation,

  /// Hàng đợi chờ ghi dồn tới đâu khi có và không có giới hạn (UC-02, UC-14).
  backpressure;

  String get label => switch (this) {
    DiagnosticsTest.throughput => 'Throughput',
    DiagnosticsTest.cancellation => 'Cancel latency',
    DiagnosticsTest.backpressure => 'Write backlog',
  };

  /// Một câu nói phép đo này chứng minh điều gì — in ngay dưới bảng điều khiển
  /// để con số không bị đọc tách khỏi câu hỏi của nó.
  String get explanation => switch (this) {
    DiagnosticsTest.throughput =>
      'Runs the workload under each strategy and records total time and '
          'frame time.',
    DiagnosticsTest.cancellation =>
      'Cancels each run once a quarter of the items has arrived, at every '
          'batch size. Cancel is only seen between batches, so bigger batches '
          'stop later and let more items through.',
    DiagnosticsTest.backpressure =>
      'Slows every write down to '
          '${ProbeRuntimeUseCase.simulatedWriteTime.inMilliseconds} ms and counts how many batches pile up waiting, with and '
          'without the pending-batch limit.',
  };
}

String modeLabelOf(ExecutionMode mode) => switch (mode) {
  ExecutionMode.isolate => 'Background isolate',
  ExecutionMode.mainThread => 'Interface thread',
};

/// Một dòng của bảng độ trễ huỷ.
final class CancelProbeViewModel {
  const CancelProbeViewModel({
    required this.modeLabel,
    required this.batchSize,
    required this.latencyText,
    required this.itemsAfterText,
    required this.batchesAfterText,
  });

  factory CancelProbeViewModel.of(CancelProbeRun run) => CancelProbeViewModel(
    modeLabel: modeLabelOf(run.effectiveMode),
    batchSize: run.strategy.batchSize,
    latencyText: _millis(run.latency),
    itemsAfterText: NumberFormatter.count(run.itemsAfterCancel),
    batchesAfterText: run.batchesAfterCancel.toStringAsFixed(1),
  );

  final String modeLabel;
  final int batchSize;
  final String latencyText;
  final String itemsAfterText;
  final String batchesAfterText;
}

/// Một dòng của bảng hàng đợi chờ ghi.
final class BackpressureProbeViewModel {
  const BackpressureProbeViewModel({
    required this.modeLabel,
    required this.batchSize,
    required this.isCapped,
    required this.limitText,
    required this.peakBatchesText,
    required this.peakItemsText,
    required this.producerText,
    required this.consumerText,
  });

  factory BackpressureProbeViewModel.of(BackpressureProbeRun run) =>
      BackpressureProbeViewModel(
        modeLabel: modeLabelOf(run.effectiveMode),
        batchSize: run.strategy.batchSize,
        isCapped: run.isCapped,
        limitText: run.isCapped
            ? 'limit ${run.strategy.maxPendingBatches}'
            : 'no limit',
        peakBatchesText: NumberFormatter.count(run.peakPendingBatches),
        peakItemsText: NumberFormatter.count(run.peakPendingItems),
        producerText: _millis(run.producerFinishedAfter),
        consumerText: _millis(run.consumerFinishedAfter),
      );

  final String modeLabel;
  final int batchSize;
  final bool isCapped;
  final String limitText;
  final String peakBatchesText;
  final String peakItemsText;

  /// Bên phân tích gửi xong sau bao lâu, và bên ghi ghi xong sau bao lâu. Khoảng
  /// cách giữa hai con số là khoảng thời gian mà phần chênh lệch nằm chờ trong
  /// bộ nhớ.
  final String producerText;
  final String consumerText;
}

String _millis(Duration value) =>
    '${(value.inMicroseconds / 1000).toStringAsFixed(1)} ms';
