import 'dart:typed_data';

import '../../../domain/value_objects/statement_format.dart';
import 'parse_error.dart';
import 'parsed_row.dart';

/// Kết quả phân tích **một dòng** nguồn: hoặc một [ParsedRow] đọc được, hoặc một
/// [ParseError]. Là kiểu tổng đóng nên nơi tiêu thụ `switch` được vét cạn.
///
/// Lỗi là dữ liệu, không phải exception — một dòng hỏng không được làm dừng các
/// dòng còn lại (UC-02).
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

/// Đọc một định dạng sao kê cụ thể (UC-02).
///
/// Bốn phần hiện thực (CSV, Excel, MT940, JSON) sống ở tầng Infrastructure và
/// **không giữ trạng thái**: chúng chạy bên trong isolate phân tích, nơi không
/// với tới được repository, cấu hình toàn cục hay DI container — mọi thứ cần thiết
/// phải đến qua tham số. Chính vì thế [parseLines] chỉ nhận [bytes]: parser được
/// đưa sẵn nội dung file chứ không tự mở file.
///
/// Trả về một [Iterable] chạy lười (`sync*`) để workload gom lô, báo tiến trình
/// và kiểm huỷ tại ranh giới giữa các lô mà không phải nạp cả file thành các đối
/// tượng trung gian một lúc.
abstract interface class StatementParser {
  StatementFormat get format;

  /// Sinh lần lượt từng kết quả dòng từ nội dung file. Việc quy đổi số tiền, áp
  /// mặc định VND khi nguồn không nêu, và chuẩn hoá chiều tiền về dấu đều xảy ra
  /// tại đây — bốn định dạng khác nhau đổ chung vào một mô hình ngay ở bước phân
  /// tích (Rule – The Sign Carries the Direction).
  Iterable<ParseLineResult> parseLines(Uint8List bytes);
}

/// Chọn parser theo định dạng đã nhận diện.
///
/// Là cổng do Infrastructure hiện thực: use case nhập không được biết bốn parser
/// cụ thể (ngược chiều phụ thuộc), nó chỉ hỏi factory này một [StatementParser]
/// không trạng thái rồi đặt vào đầu vào của workload — thứ sẽ được sao chép qua
/// ranh giới isolate.
abstract interface class StatementParserFactory {
  StatementParser parserFor(StatementFormat format);
}
