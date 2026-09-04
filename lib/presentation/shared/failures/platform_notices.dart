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
  ///
  /// Mức **cảnh báo**, không phải thông tin: bảng ngữ nghĩa của DESIGN.md xếp
  /// "giới hạn xử lý trên Web" vào banner cảnh báo, và mức đó là đúng — đây là
  /// điều kiện làm giao diện giật ngay trước mắt người dùng, không phải một ghi
  /// chú trung tính.
  static const FeedbackMessage webDegradation = FeedbackMessage.warning(
    'Running on the web build. No isolates: heavy parsing shares the interface '
    'thread, so the interface may stutter. No file-level parallelism either, '
    'so the whole run takes longer than on the installed app.',
  );

  /// Kèm ở mọi luồng xuất báo cáo (UC-11).
  ///
  /// Phải hiện **ngay trong dialog**, không chỉ nằm ở đầu file: người dùng quyết
  /// định gửi file đó cho ai *trước khi* mở nó ra đọc. File sao lưu ở UC-13 thì
  /// ngược lại — nó luôn được mã hoá.
  static const FeedbackMessage exportNotEncrypted = FeedbackMessage.warning(
    'The exported file is not encrypted. Anyone who opens it can read every '
    'row.',
  );
}
