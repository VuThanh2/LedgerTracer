import 'dart:async';

/// Công tắc một chiều mà giao diện bật lên để yêu cầu workload đang chạy dừng
/// lại (UC-02 bước 7, UC-08).
///
/// Nơi xử lý **không thể bị ngắt từ bên ngoài**: một isolate chỉ với tới được
/// giữa hai lượt event loop của chính nó, còn trên Web thì công việc đang chạy
/// ngay trên luồng lẽ ra phải chuyển yêu cầu đó đi. Vì vậy tín hiệu chỉ được
/// **đọc tại ranh giới giữa các lô**, và hệ quả quan sát được là nút Huỷ phản
/// hồi trong vòng một lô chứ không tức thì — hành vi có chủ đích, không phải một
/// cam kết bị phá vỡ (UC-14).
///
/// Huỷ không phải rollback: những gì workload đã ghi vẫn nằm đó. Đó đúng là điều
/// UC-02 yêu cầu, và cũng là thứ làm cho việc nhập lại chính file đó sau khi huỷ
/// trở nên an toàn.
final class CancellationSignal {
  CancellationSignal();

  /// Một tín hiệu đã bật sẵn — tiện làm giá trị mặc định và dùng trong test.
  factory CancellationSignal.cancelled() => CancellationSignal()..cancel();

  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Hoàn tất ngay khi [cancel] được gọi; runner dùng nó để chuyển yêu cầu vào
  /// isolate thay vì phải hỏi vòng.
  Future<void> get whenCancelled => _completer.future;

  /// Gọi nhiều lần cũng như gọi một lần, và một tín hiệu không bao giờ quay lại
  /// trạng thái "đang chạy".
  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }

  /// Lối tắt cho workload nào muốn thoát bằng exception thay vì trả về kết quả
  /// dở dang.
  void throwIfCancelled() {
    if (isCancelled) throw const CancellationException();
  }
}

/// Do [CancellationSignal.throwIfCancelled] ném ra. Tầng Application đổi nó
/// thành `CancelledFailure` — một kết cục, không phải một lỗi.
final class CancellationException implements Exception {
  const CancellationException();

  @override
  String toString() => 'CancellationException: the workload was cancelled.';
}
