import '../../shared/bloc/load_status.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/navigation_intent.dart';

/// Trạng thái khung điều hướng.
final class AppShellState {
  const AppShellState({
    this.status = LoadStatus.initial,
    this.destination = NavDestination.transactions,
    this.pendingNavigation,
    this.recoveryNotice,
    this.supportsIsolates = true,
  });

  final LoadStatus status;

  /// Ô đang chọn. Mặc định là Giao dịch — màn hình chính của ứng dụng.
  final NavDestination destination;

  /// Yêu cầu điều hướng chưa được màn hình đích tiêu thụ.
  final PendingNavigation? pendingNavigation;

  /// Thông báo về các lượt nhập bị gián đoạn ở lần chạy trước.
  ///
  /// Đây là điều người dùng **phải** được báo: lần trước ứng dụng biến mất mà
  /// không kịp nói gì, nên họ không biết lượt nhập ấy đã ghi được tới đâu. Lượt
  /// rỗng bị dọn đi không được tính vào đây — không có dữ liệu nào của họ dính
  /// tới nó, và báo về nó chỉ là tiếng ồn (UC-03).
  final FeedbackMessage? recoveryNotice;

  /// Nền tảng có isolate thật không (UC-14).
  final bool supportsIsolates;

  AppShellState copyWith({
    LoadStatus? status,
    NavDestination? destination,
    PendingNavigation? pendingNavigation,
    bool clearPendingNavigation = false,
    FeedbackMessage? recoveryNotice,
    bool clearRecoveryNotice = false,
    bool? supportsIsolates,
  }) => AppShellState(
    status: status ?? this.status,
    destination: destination ?? this.destination,
    pendingNavigation: clearPendingNavigation
        ? null
        : (pendingNavigation ?? this.pendingNavigation),
    recoveryNotice: clearRecoveryNotice
        ? null
        : (recoveryNotice ?? this.recoveryNotice),
    supportsIsolates: supportsIsolates ?? this.supportsIsolates,
  );
}
