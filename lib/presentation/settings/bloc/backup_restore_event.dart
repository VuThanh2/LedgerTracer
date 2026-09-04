/// Những gì xảy ra trên màn hình Sao lưu & Khôi phục (UC-13).
sealed class BackupRestoreEvent {
  const BackupRestoreEvent();
}

final class BackupRestoreStarted extends BackupRestoreEvent {
  const BackupRestoreStarted();
}

/// Gõ mật khẩu cho file sao lưu sắp tạo.
///
/// Mật khẩu này **độc lập hoàn toàn với mã PIN khoá ứng dụng**, và đó là điều
/// kiện để lối thoát "quên PIN → xoá sạch → khôi phục" đi được: sao lưu mã hoá
/// bằng chính mã PIN đã quên thì hai use case triệt tiêu nhau (UC-12, UC-13).
final class BackupPasswordChanged extends BackupRestoreEvent {
  const BackupPasswordChanged({required this.password, required this.confirm});

  final String password;

  /// Ô nhập lại. Mất mật khẩu là mất luôn file đó, không có đường khôi phục —
  /// nên một mật khẩu gõ nhầm phải bị chặn ở đây, không phải phát hiện ra vào
  /// ngày cần dùng tới bản sao lưu.
  final String confirm;
}

final class BackupRequested extends BackupRestoreEvent {
  const BackupRequested();
}

/// Chọn file sao lưu để khôi phục (UC-13 bước 2).
final class RestoreFilePicked extends BackupRestoreEvent {
  const RestoreFilePicked();
}

final class RestorePasswordChanged extends BackupRestoreEvent {
  const RestorePasswordChanged(this.password);

  final String password;
}

/// Giải mã và kiểm tra file, **không** ghi gì (UC-13 bước 3).
///
/// Bước riêng chứ không gộp vào lúc ghi đè: sai mật khẩu hay file hỏng phải dừng
/// lại ở đây, khi dữ liệu hiện có còn nguyên vẹn. Gộp lại thì hộp thoại cảnh báo
/// hoặc hiện trước khi biết file có đọc được không — một cảnh báo hão — hoặc
/// hiện sau khi dữ liệu đã bị ghi đè, lúc đã quá muộn để hỏi.
final class RestorePrepared extends BackupRestoreEvent {
  const RestorePrepared();
}

/// Đóng cảnh báo "toàn bộ dữ liệu hiện có sẽ bị thay thế" mà không khôi phục.
final class RestoreDismissed extends BackupRestoreEvent {
  const RestoreDismissed();
}

/// Đồng ý ghi đè (UC-13 bước 4).
final class RestoreCommitted extends BackupRestoreEvent {
  const RestoreCommitted();
}
