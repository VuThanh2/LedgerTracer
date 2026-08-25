import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';

/// Yêu cầu chạy một lần đối soát (UC-08 bước 1).
final class RunReconciliationRequest {
  const RunReconciliationRequest({this.strategy, this.cancellation});

  /// Chiến lược concurrency, hoặc `null` để use case tự chọn theo nền tảng —
  /// đường đi bình thường. Giá trị truyền vào tường minh vẫn đi qua
  /// `StrategySelector.adapt`, vì một chiến lược dùng isolate không chạy được
  /// trên Web (UC-14).
  final ConcurrencyStrategy? strategy;

  /// Huỷ chỉ được đọc tại ranh giới giữa các lô, nên nút Huỷ phản hồi trong vòng
  /// một lô chứ không tức thì — hành vi có chủ đích (UC-14).
  final CancellationSignal? cancellation;
}

/// Ảnh chụp tiến trình của một lần quét (UC-08 bước 4).
///
/// Đơn giản hơn hẳn `ImportProgress` vì lần quét chỉ có **một** workload: không
/// có nhiều nguồn báo về xen kẽ nhau, nên [processed] và [total] là con số thật
/// của cả lượt chứ không phải của một trong nhiều file.
final class ReconciliationProgress {
  const ReconciliationProgress({
    required this.processed,
    required this.total,
    required this.pairsFound,
    required this.mode,
  });

  /// Số giao dịch đã duyệt qua.
  final int processed;

  /// Tổng số giao dịch chưa ghép của lần chạy này.
  final int total;

  /// Số cặp đã ghi được tới lúc này — cặp được ghi dần theo lô, nên con số này
  /// là thật chứ không phải ước lượng.
  final int pairsFound;

  final ExecutionMode mode;

  bool get isBackground => mode.isBackground;

  double? get fraction {
    if (total <= 0) return null;
    final ratio = processed / total;
    return ratio > 1 ? 1 : ratio;
  }

  @override
  String toString() =>
      'ReconciliationProgress($processed/$total, $pairsFound pair(s))';
}

/// Kết quả một lần chạy đối soát, hiển thị khi hoàn tất (UC-08 bước 4).
final class RunReconciliationResult {
  const RunReconciliationResult({
    required this.suggestedPairsFound,
    required this.clearedSuggestions,
    required this.scannedTransactionCount,
    required this.wasCancelled,
    required this.mode,
  });

  final int suggestedPairsFound;

  /// Số gợi ý cũ đã bị xoá trước khi tính lại — cặp đã xác nhận không nằm trong
  /// đây, chúng sống sót qua mọi lần chạy lại (UC-08).
  final int clearedSuggestions;

  final int scannedTransactionCount;

  final bool wasCancelled;

  /// Chế độ chạy thực tế, để giao diện nói đúng giới hạn trên Web (UC-14).
  final ExecutionMode mode;
}
