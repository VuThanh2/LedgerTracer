import '../../shared/bloc/load_status.dart';
import '../../shared/failures/feedback_message.dart';

/// Cổng khoá đang ở đâu (UC-12).
enum AppLockGate {
  /// Chưa biết — đang đọc thiết lập. Giao diện **phải** vẽ một màn hình chờ ở
  /// trạng thái này chứ không vẽ nội dung ứng dụng: đoán sai theo hướng "chưa
  /// khoá" nghĩa là dữ liệu hiện ra trong một nhịp trước khi màn hình khoá kịp
  /// đè lên.
  unknown,

  /// Khoá đang bật và chưa mở.
  locked,

  /// Vào được: khoá tắt, hoặc đã mở khoá thành công.
  unlocked,
}

/// Trạng thái màn hình khoá.
final class AppLockState {
  const AppLockState({
    this.status = LoadStatus.initial,
    this.gate = AppLockGate.unknown,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.isVerifying = false,
    this.pinError,
    this.isResetPending = false,
    this.resetConfirmationText = '',
    this.isResetting = false,
    this.error,
  });

  final LoadStatus status;

  final AppLockGate gate;

  final bool biometricEnabled;

  final bool biometricAvailable;

  final bool isVerifying;

  final String? pinError;

  /// Hộp thoại xoá toàn bộ dữ liệu đang mở.
  final bool isResetPending;

  /// Chuỗi người dùng đang gõ trong hộp thoại đó.
  final String resetConfirmationText;

  final bool isResetting;

  final FeedbackMessage? error;

  /// Nút mở khoá bằng sinh trắc học chỉ hiện khi **cả hai** điều kiện đúng.
  ///
  /// Hai cờ riêng biệt chứ không một: người dùng có thể đã bật nó rồi tháo hết
  /// vân tay khỏi thiết bị, và khi đó nút phải biến mất chứ không phải hiện ra
  /// để báo lỗi sau khi bấm.
  bool get canUseBiometric => biometricEnabled && biometricAvailable;

  /// Chuỗi phải gõ đúng để nút xoá sáng lên.
  static const String resetConfirmationPhrase = 'XOA TOAN BO';

  bool get canConfirmReset =>
      resetConfirmationText.trim().toUpperCase() == resetConfirmationPhrase;

  AppLockState copyWith({
    LoadStatus? status,
    AppLockGate? gate,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? isVerifying,
    String? pinError,
    bool clearPinError = false,
    bool? isResetPending,
    String? resetConfirmationText,
    bool? isResetting,
    FeedbackMessage? error,
    bool clearError = false,
  }) => AppLockState(
    status: status ?? this.status,
    gate: gate ?? this.gate,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    isVerifying: isVerifying ?? this.isVerifying,
    pinError: clearPinError ? null : (pinError ?? this.pinError),
    isResetPending: isResetPending ?? this.isResetPending,
    resetConfirmationText:
        resetConfirmationText ?? this.resetConfirmationText,
    isResetting: isResetting ?? this.isResetting,
    error: clearError ? null : (error ?? this.error),
  );
}
