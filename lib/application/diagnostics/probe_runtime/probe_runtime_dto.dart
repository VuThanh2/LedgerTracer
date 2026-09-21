import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';

/// Kết quả đo **độ trễ của nút Huỷ** dưới một cấu hình.
///
/// Chứng minh bằng số câu mà UC-02 và UC-14 chỉ khẳng định: yêu cầu huỷ chỉ được
/// nhìn thấy **tại ranh giới giữa các lô**, nên lô càng to thì huỷ càng trễ và
/// càng nhiều phần tử vẫn bị xử lý sau khi người dùng đã bấm Huỷ.
final class CancelProbeRun {
  const CancelProbeRun({
    required this.strategy,
    required this.effectiveMode,
    required this.latency,
    required this.itemsAtCancel,
    required this.itemsAfterCancel,
  });

  final ConcurrencyStrategy strategy;
  final ExecutionMode effectiveMode;

  /// Từ lúc phát lệnh huỷ tới lúc workload thật sự trả quyền điều khiển.
  final Duration latency;

  /// Số phần tử bên tiêu thụ đã nhận khi lệnh huỷ được phát.
  final int itemsAtCancel;

  /// Số phần tử vẫn tới bên tiêu thụ **sau** lệnh huỷ — phần "trượt quán tính":
  /// lô đang tính dở, cộng các lô đã gửi đi mà chưa kịp nhận.
  final int itemsAfterCancel;

  /// Quy ra số lô cho dễ đọc: thường nằm trong khoảng 0 tới
  /// `maxPendingBatches + 1`.
  double get batchesAfterCancel => itemsAfterCancel / strategy.batchSize;
}

/// Kết quả đo **hàng đợi chờ ghi** dưới một cấu hình.
///
/// Bên tiêu thụ được làm chậm cố ý (giả lập việc ghi vào cơ sở dữ liệu), rồi đo
/// số lô đã được bên phân tích gửi đi nhưng chưa được ghi — tại thời điểm tệ
/// nhất. Đó chính là thứ chiếm bộ nhớ mà giới hạn `maxPendingBatches` giữ lại
/// (UC-02), và cũng là thứ trở nên vô nghĩa trên luồng chính (UC-14).
final class BackpressureProbeRun {
  const BackpressureProbeRun({
    required this.strategy,
    required this.effectiveMode,
    required this.isCapped,
    required this.peakPendingBatches,
    required this.producerFinishedAfter,
    required this.consumerFinishedAfter,
  });

  final ConcurrencyStrategy strategy;
  final ExecutionMode effectiveMode;

  /// Cấu hình có giữ giới hạn số lô chờ ghi hay cố ý bỏ nó đi để so sánh.
  final bool isCapped;

  /// Số lô nằm chờ nhiều nhất cùng một lúc.
  ///
  /// Tính cả lô mà bên phân tích đã tính xong và đang cầm trên tay chờ được
  /// phép gửi — lô đó cũng đang nằm trong bộ nhớ. Vì vậy với giới hạn N thì
  /// con số này có thể là N + 1, còn không giới hạn thì nó tăng theo cỡ
  /// workload.
  final int peakPendingBatches;

  /// Bên phân tích gửi xong lô cuối sau bao lâu. Không có giới hạn thì con số
  /// này nhỏ hơn hẳn thời gian ghi — nghĩa là mọi thứ đã dồn vào bộ nhớ chờ.
  final Duration producerFinishedAfter;

  /// Bên ghi xử lý xong lô cuối sau bao lâu.
  final Duration consumerFinishedAfter;

  int get peakPendingItems => peakPendingBatches * strategy.batchSize;
}
