import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';

/// Trạng thái màn hình Thiết lập (UC-12).
final class SettingsState {
  const SettingsState({
    this.status = LoadStatus.initial,
    this.appLockEnabled = false,
    this.biometricEnabled = false,
    this.biometricAvailable = false,
    this.isSubmitting = false,
    this.pinError,
    this.diagnosticsUnlocked = false,
    this.hiddenTapCount = 0,
    this.notice,
    this.loadError,
  });

  final LoadStatus status;

  final bool appLockEnabled;

  final bool biometricEnabled;

  /// Nền tảng có hỗ trợ sinh trắc học không. Giao diện **ẩn hẳn** công tắc khi
  /// không, thay vì hiện rồi báo lỗi sau khi người dùng đã bấm (UC-12).
  final bool biometricAvailable;

  final bool isSubmitting;

  /// Lỗi gắn với ô nhập PIN: sai PIN hiện tại, hai ô không khớp, PIN không hợp
  /// lệ. Tách khỏi [notice] vì nó thuộc về biểu mẫu, không phải về màn hình.
  final String? pinError;

  /// Mục vào màn hình chẩn đoán đã hiện ra chưa.
  final bool diagnosticsUnlocked;

  final int hiddenTapCount;

  final TransientNotice? notice;

  final FeedbackMessage? loadError;

  SettingsState copyWith({
    LoadStatus? status,
    bool? appLockEnabled,
    bool? biometricEnabled,
    bool? biometricAvailable,
    bool? isSubmitting,
    String? pinError,
    bool clearPinError = false,
    bool? diagnosticsUnlocked,
    int? hiddenTapCount,
    TransientNotice? notice,
    FeedbackMessage? loadError,
    bool clearLoadError = false,
  }) => SettingsState(
    status: status ?? this.status,
    appLockEnabled: appLockEnabled ?? this.appLockEnabled,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    biometricAvailable: biometricAvailable ?? this.biometricAvailable,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    pinError: clearPinError ? null : (pinError ?? this.pinError),
    diagnosticsUnlocked: diagnosticsUnlocked ?? this.diagnosticsUnlocked,
    hiddenTapCount: hiddenTapCount ?? this.hiddenTapCount,
    notice: notice ?? this.notice,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}
