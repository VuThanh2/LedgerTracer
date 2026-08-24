import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/concurrency_strategy.dart';
import '../../../core/concurrency/execution_mode.dart';

/// Một lần chạy đối soát, kèm chiến lược concurrency đã chọn (UC-08).
final class RunReconciliationRequest {
  const RunReconciliationRequest({required this.strategy, this.cancellation});

  final ConcurrencyStrategy strategy;

  final CancellationSignal? cancellation;
}

/// Kết quả một lần chạy: số cặp gợi ý tìm được và số gợi ý cũ đã bị xoá để tính
/// lại từ đầu (UC-08).
final class RunReconciliationResult {
  const RunReconciliationResult({
    required this.suggestedPairsFound,
    required this.clearedSuggestions,
    required this.wasCancelled,
    required this.mode,
  });

  final int suggestedPairsFound;

  /// Gợi ý **chưa xác nhận** của lần trước, bị xoá trước khi quét lại; cặp đã xác
  /// nhận thì được giữ nguyên vì chúng mang phán quyết của người dùng (UC-08).
  final int clearedSuggestions;

  final bool wasCancelled;

  /// Chạy trong isolate (native) hay suy biến đồng bộ trên luồng chính (Web),
  /// để màn hình nói thẳng giới hạn thay vì giấu (UC-14).
  final ExecutionMode mode;
}
