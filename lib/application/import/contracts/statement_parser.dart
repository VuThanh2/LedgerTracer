import 'dart:typed_data';

import '../../../domain/value_objects/statement_format.dart';
import 'parse_error.dart';
import 'parsed_row.dart';

/// Kết cục của **một dòng** trong file: hoặc đọc được, hoặc không.
///
/// Lỗi từng dòng đi về như **dữ liệu**, không phải exception ném qua ranh giới
/// isolate: exception làm chết cả tác vụ, trong khi UC-02 yêu cầu một dòng hỏng
/// không được làm dừng các dòng còn lại.
sealed class ParseLineResult {
  const ParseLineResult();

  const factory ParseLineResult.parsed(ParsedRow row) = ParsedLine;

  const factory ParseLineResult.failed(ParseError error) = RejectedLine;
}

final class ParsedLine extends ParseLineResult {
  const ParsedLine(this.row);

  final ParsedRow row;
}

final class RejectedLine extends ParseLineResult {
  const RejectedLine(this.error);

  final ParseError error;
}

/// Bộ phân tích của **một** định dạng sao kê.
///
/// **Ràng buộc bắt buộc — object này đi qua ranh giới isolate.** Nó được gửi kèm
/// đầu vào của workload phân tích, nghĩa là nó bị **sao chép** sang isolate. Vì
/// vậy một cài đặt phải:
///
/// - **bất biến và không giữ trạng thái** giữa hai lần gọi;
/// - **không** giữ tài nguyên gắn với luồng gốc (`File`, `RandomAccessFile`,
///   `SendPort`, kết nối cơ sở dữ liệu) và **không** đóng gói closure bắt biến
///   ngoài — những thứ đó không sao chép được và sẽ ném ngay lúc gửi;
/// - **không** phụ thuộc repository, cấu hình toàn cục hay bất cứ thứ gì trong
///   container DI. Mọi thứ nó cần phải đến qua tham số.
///
/// Đây là ràng buộc của chính mô hình bộ nhớ Dart, không phải của một thư viện
/// nào có thể thay thế, và vi phạm nó chỉ đổ vỡ lúc chạy chứ không lúc biên dịch.
abstract interface class StatementParser {
  StatementFormat get format;

  /// Duyệt toàn bộ file, trả kết quả **lười** theo từng dòng.
  ///
  /// Trả `Iterable` chứ không trả `List`: workload gom kết quả thành lô và nhả
  /// từng lô đi, nên không bao giờ có nhu cầu giữ cả file trong bộ nhớ một lúc.
  Iterable<ParseLineResult> parseLines(Uint8List bytes);

  /// Ước lượng tổng số dòng dữ liệu, hoặc `null` nếu định dạng không cho biết
  /// điều đó **một cách rẻ tiền**.
  ///
  /// Chỉ dùng để thanh tiến trình xác định được tỷ lệ (UC-02 bước 5); sai số là
  /// chấp nhận được, còn quét trước cả file để đếm cho chính xác thì không —
  /// như vậy là trả gấp đôi chi phí đọc để lấy một con số trang trí.
  int? estimateRowCount(Uint8List bytes);

  /// Số tài khoản nhúng trong chính file, đọc từ [head] — **phần đầu file**, chứ
  /// không phải toàn bộ (ví dụ tag `:25:` của MT940). Trả `null` khi định dạng
  /// không mang thông tin này hoặc phần đầu chưa đủ để kết luận.
  ///
  /// Chỉ đọc phần đầu là có chủ đích: cảnh báo gán nhầm tài khoản phải hiện ra
  /// **trước khi** bắt đầu xử lý nền, để việc chờ người dùng quyết định không
  /// làm nghẽn hàng đợi ghi tuần tự (UC-02 bước 4).
  String? peekAccountNumber(Uint8List head);
}

/// Nguồn cấp parser theo định dạng. Tách khỏi [StatementParser] vì bản thân
/// factory **không** đi qua ranh giới isolate — chỉ parser nó trả về mới đi.
abstract interface class StatementParserFactory {
  StatementParser parserFor(StatementFormat format);
}

/// Nhận diện định dạng của một file người dùng vừa chọn (UC-02 bước 2).
///
/// Người dùng chỉ chọn file mình đang có; việc biết đó là CSV, Excel, MT940 hay
/// JSON là việc của ứng dụng. Nhận diện dựa trên [head] trước, tên file chỉ là
/// gợi ý phụ — phần mở rộng có thể sai hoặc không có.
abstract interface class StatementFormatDetector {
  /// Trả `null` khi không định dạng nào trong bốn định dạng được hỗ trợ khớp.
  StatementFormat? detect({required String fileName, required Uint8List head});
}
