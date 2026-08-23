/// Kết cục của **một file** trong một lượt nhập (UC-02 bước 8).
///
/// File — chứ không phải cả lượt — mới là đơn vị được ghi nhận và hoàn tác, vì
/// một lượt có thể gán nhiều tài khoản khác nhau (UC-01, UC-03).
enum ImportFileStatus {
  /// Mọi dòng đọc được đều đã ghi, không có dòng nào bị loại.
  completed,

  /// File đã ghi nhưng có dòng không đọc được và thành dòng lỗi — một dòng hỏng
  /// không bao giờ làm dừng các dòng còn lại (UC-02).
  partiallyFailed,

  /// Bị huỷ khi đang ghi file này; phần đã ghi được giữ lại, và nhập lại file đó
  /// về sau chỉ bổ sung phần còn thiếu.
  cancelled,

  /// Người dùng chọn "bỏ qua file này" ở cảnh báo lệch số tài khoản (UC-02 bước
  /// 4). Không đọc gì cả — đây là một quyết định, không phải lỗi đọc file.
  skipped,
}
