import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/backup_manifest_view_model.dart';

/// Trạng thái màn hình Sao lưu & Khôi phục (UC-13).
///
/// **Không** giữ khối bytes đã giải mã: nó nằm trong `RestorePlan`, và
/// `RestorePlan` ở lại bên trong BLoC. State là thứ giao diện đọc được và là thứ
/// bị chụp lại trong log lúc gỡ lỗi; toàn bộ dữ liệu tài chính của người dùng
/// không có việc gì ở đó.
final class BackupRestoreState {
  const BackupRestoreState({
    this.backupPassword = '',
    this.backupPasswordConfirm = '',
    this.isBackingUp = false,
    this.backupPasswordError,
    this.savedLocationText,
    this.pickedFileName,
    this.restorePassword = '',
    this.isPreparing = false,
    this.restoreError,
    this.manifest,
    this.isRestoring = false,
    this.isRestored = false,
    this.notice,
  });

  final String backupPassword;
  final String backupPasswordConfirm;
  final bool isBackingUp;

  /// Lỗi gắn với ô mật khẩu sao lưu.
  final String? backupPasswordError;

  /// Nơi file vừa được lưu; `null` khi chưa sao lưu lần nào trong phiên này.
  ///
  /// Trên Web nó là câu mô tả cơ chế tải xuống chứ không phải đường dẫn — trình
  /// duyệt không cho chọn nơi lưu, và nói "đã lưu vào ..." ở đó là bịa.
  final String? savedLocationText;

  final String? pickedFileName;
  final String restorePassword;
  final bool isPreparing;

  /// Lỗi của bước giải mã/kiểm tra: sai mật khẩu, hoặc file hỏng. Hai thứ khác
  /// nhau về việc người dùng phải làm tiếp — gõ lại, hay đi tìm bản sao lưu khác
  /// — nên câu chữ do `FailurePresenter` phân nhánh theo loại failure.
  final FeedbackMessage? restoreError;

  /// Có giá trị nghĩa là file đã giải mã và kiểm xong; hộp thoại cảnh báo ghi đè
  /// hiện lên từ đây (UC-13 bước 4).
  final BackupManifestViewModel? manifest;

  final bool isRestoring;

  /// Đã ghi đè xong. Giao diện dùng nó để buộc phần còn lại của ứng dụng đọc
  /// lại: mọi màn hình đang mở đều đang hiển thị dữ liệu vừa bị thay thế.
  final bool isRestored;

  final TransientNotice? notice;

  bool get canBackup =>
      backupPassword.isNotEmpty &&
      backupPassword == backupPasswordConfirm &&
      !isBackingUp;

  bool get canPrepareRestore =>
      pickedFileName != null && restorePassword.isNotEmpty && !isPreparing;

  bool get isAwaitingOverwriteConfirmation => manifest != null && !isRestored;

  BackupRestoreState copyWith({
    String? backupPassword,
    String? backupPasswordConfirm,
    bool? isBackingUp,
    String? backupPasswordError,
    bool clearBackupPasswordError = false,
    String? savedLocationText,
    String? pickedFileName,
    String? restorePassword,
    bool? isPreparing,
    FeedbackMessage? restoreError,
    bool clearRestoreError = false,
    BackupManifestViewModel? manifest,
    bool clearManifest = false,
    bool? isRestoring,
    bool? isRestored,
    TransientNotice? notice,
  }) => BackupRestoreState(
    backupPassword: backupPassword ?? this.backupPassword,
    backupPasswordConfirm:
        backupPasswordConfirm ?? this.backupPasswordConfirm,
    isBackingUp: isBackingUp ?? this.isBackingUp,
    backupPasswordError: clearBackupPasswordError
        ? null
        : (backupPasswordError ?? this.backupPasswordError),
    savedLocationText: savedLocationText ?? this.savedLocationText,
    pickedFileName: pickedFileName ?? this.pickedFileName,
    restorePassword: restorePassword ?? this.restorePassword,
    isPreparing: isPreparing ?? this.isPreparing,
    restoreError: clearRestoreError ? null : (restoreError ?? this.restoreError),
    manifest: clearManifest ? null : (manifest ?? this.manifest),
    isRestoring: isRestoring ?? this.isRestoring,
    isRestored: isRestored ?? this.isRestored,
    notice: notice ?? this.notice,
  );
}
