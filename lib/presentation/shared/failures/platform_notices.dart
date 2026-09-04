import 'feedback_message.dart';

/// Những gì nền tảng đang chạy **không** làm được, nói bằng chữ cho người dùng.
///
/// Tách khỏi `FailurePresenter` vì đây không phải phản ứng với một thất bại: nó
/// là một sự thật thường trực của môi trường, hiện ra **trước** khi người dùng
/// bấm gì, không phải sau khi có gì hỏng.
abstract final class PlatformNotices {
  /// Web Degradation Indicator (UC-14).
  ///
  /// Nhúng vào **hai** chỗ có tác vụ nền: bước 3 của luồng nhập và màn hình đối
  /// soát. Một hằng số dùng chung chứ không hai câu chép tay, vì hai chỗ ấy phải
  /// nói **cùng một điều** — và điều đó có hai vế mà bỏ vế nào cũng làm người
  /// đọc hiểu sai:
  ///
  /// * mất isolate ⇒ công việc chạy ngay trên luồng đang vẽ, nên **giao diện có
  ///   thể giật**;
  /// * mất song song nhiều file ⇒ các file phân tích nối tiếp nhau, nên **tổng
  ///   thời gian dài hơn**.
  ///
  /// Chỉ nói vế đầu thì người dùng tưởng chờ lâu là do máy yếu; chỉ nói vế sau
  /// thì họ tưởng ứng dụng bị treo.
  static const FeedbackMessage webDegradation = FeedbackMessage.info(
    'Trình duyệt không cho chạy nền thật, nên tác vụ này chạy ngay trên luồng '
    'giao diện: màn hình có thể giật trong lúc xử lý, và nhiều file phải làm '
    'lần lượt nên tổng thời gian dài hơn trên ứng dụng cài đặt.',
  );

  /// Kèm ở mọi luồng xuất báo cáo (UC-11).
  ///
  /// Phải hiện **ngay trong dialog**, không chỉ nằm ở đầu file: người dùng quyết
  /// định gửi file đó cho ai *trước khi* mở nó ra đọc. File sao lưu ở UC-13 thì
  /// ngược lại — nó luôn được mã hoá.
  static const FeedbackMessage exportNotEncrypted = FeedbackMessage.warning(
    'File xuất không được mã hoá. Bất kỳ ai mở được file cũng đọc được toàn bộ '
    'nội dung.',
  );
}
