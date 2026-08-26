/// Kết cục của một lượt nhập — nhóm file người dùng chọn cùng lúc (UC-02,
/// UC-03).
enum ImportSessionStatus {
  inProgress,

  /// Mọi file trong lượt đều đã đi tới trạng thái cuối.
  completed,

  /// Người dùng huỷ giữa chừng; phần đã ghi vẫn giữ nguyên, và lượt nhập vẫn
  /// hiện trong lịch sử với trạng thái chưa hoàn tất (UC-03).
  cancelled,

  /// Tiến trình chết giữa lượt nhập — bị hệ điều hành kết liễu, hoặc tab trình
  /// duyệt bị đóng — nên không có dòng lệnh nào chạy để chốt trạng thái. Phát
  /// hiện ở lần khởi động sau (Rule – A Dead Process Leaves Honest Records).
  ///
  /// Tách khỏi [cancelled] vì hai bên cần nói với người dùng hai điều khác nhau:
  /// huỷ là phán quyết của chính họ và họ biết mình dừng ở đâu, còn gián đoạn
  /// thì họ không biết gì cả nên giao diện phải nói rõ đã ghi được bao nhiêu và
  /// rằng nhập lại nguyên file sẽ bổ sung đúng phần còn thiếu.
  interrupted,
}
