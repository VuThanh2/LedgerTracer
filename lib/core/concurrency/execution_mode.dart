/// Một workload nặng thực sự chạy ở đâu.
///
/// Hai giá trị này không phải "nhanh" và "chậm": chúng khác nhau ở **cái giá
/// phải trả**. [isolate] giữ cho luồng giao diện rảnh; [mainThread] làm đúng
/// khối việc đó ngay trên luồng đang vẽ, nên giao diện có thể giật dù tổng thời
/// gian có khi tương đương. Đây chính là điểm phân tích mà báo cáo xoay quanh
/// (UC-14).
enum ExecutionMode {
  /// Isolate nền thật sự: bộ nhớ tách rời, không chia sẻ trạng thái, mọi thứ đi
  /// qua ranh giới đều bị sao chép. Chỉ có trên native.
  isolate,

  /// Chính luồng đang gọi, có nhường lượt về event loop giữa các lô.
  ///
  /// Đây là thứ Web nhận được — trình duyệt không có `dart:isolate` — và cũng là
  /// thứ màn hình benchmark chọn trên native để đo chênh lệch ngay trên cùng một
  /// thiết bị.
  mainThread;

  /// Luồng giao diện có được rảnh trong lúc chạy hay không.
  bool get isBackground => this == ExecutionMode.isolate;
}
