/// Kết cục của một lượt nhập — nhóm file người dùng chọn cùng lúc (UC-02,
/// UC-03).
enum ImportSessionStatus {
  inProgress,

  /// Mọi file trong lượt đều đã đi tới trạng thái cuối.
  completed,

  /// Người dùng huỷ giữa chừng; phần đã ghi vẫn giữ nguyên, và lượt nhập vẫn
  /// hiện trong lịch sử với trạng thái chưa hoàn tất (UC-03).
  cancelled,
}
