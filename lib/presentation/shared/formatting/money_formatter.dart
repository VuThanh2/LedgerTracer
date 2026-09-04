import '../../../domain/value_objects/money.dart';
import 'number_formatter.dart';

/// Đưa [Money] về chuỗi hiển thị.
///
/// Hệ thiết kế đặt ra hai ràng buộc cứng mà mọi ô tiền phải theo, nên chúng nằm
/// ở đây chứ không rải trong từng widget:
///
/// * **Luôn hiện dấu `+` / `−`**. Chiều tiền là một kênh ngữ nghĩa riêng, và nó
///   được thể hiện bằng dấu cộng màu chữ — không bằng nền dòng. Một số tiền
///   không dấu buộc người đọc phải suy ra chiều từ màu, thứ mà người mù màu
///   không có.
/// * **Số tiền không bao giờ đứng một mình**. Danh sách gộp mọi tài khoản nên
///   một ô `1.000` trống trơn sẽ bị mặc định hiểu là VND
///   (Rule – Currency Belongs to the Transaction and Never Mixes, UC-04).
///
/// Dấu trừ dùng ký tự U+2212 (`−`) chứ không phải dấu gạch nối: nó có cùng bề
/// rộng với dấu `+` trong font có tabular figures, nên cột số vẫn thẳng hàng.
abstract final class MoneyFormatter {
  static const String minusSign = '\u2212';

  /// Dạng chuẩn của một ô tiền trong bảng: có dấu, có phân nhóm, **không** kèm
  /// mã loại tiền — cột loại tiền đứng riêng ở bảng và ở file xuất.
  static String signed(Money amount) =>
      '${_signOf(amount)}${_groupedMagnitude(amount)}';

  /// Có dấu **và** kèm mã loại tiền. Dạng dùng ở mọi chỗ số tiền đứng lẻ: dòng
  /// danh sách, màn hình chi tiết, hai vế của một cặp đối soát.
  static String signedWithCurrency(Money amount) =>
      '${signed(amount)} ${amount.currency.code}';

  /// Giá trị tuyệt đối kèm mã loại tiền, cho những chỗ chiều tiền đã được nói ở
  /// nơi khác — số tiền của một cặp đối soát là ví dụ: hai vế của nó luôn đối
  /// dấu nhau, nên in dấu ở đây chỉ đặt ra câu hỏi "dấu của vế nào".
  static String absoluteWithCurrency(Money amount) =>
      '${_groupedMagnitude(amount)} ${amount.currency.code}';

  /// Không dấu, không mã tiền — chỉ dùng để đổ ngược vào ô nhập của bộ lọc, nơi
  /// dấu và loại tiền là hai điều khiển riêng.
  static String plain(Money amount) => _groupedMagnitude(amount);

  static String _signOf(Money amount) => amount.isOutgoing ? minusSign : '+';

  /// Phân nhóm phần nguyên, giữ nguyên phần thập phân theo độ chính xác của
  /// chính loại tiền — VND không có phần thập phân, USD có hai chữ số.
  static String _groupedMagnitude(Money amount) {
    final decimal = amount.absolute.toDecimalString();
    final dotAt = decimal.indexOf('.');
    if (dotAt < 0) return NumberFormatter.groupDigits(decimal);
    return '${NumberFormatter.groupDigits(decimal.substring(0, dotAt))}'
        '${NumberFormatter.decimalSeparator}'
        '${decimal.substring(dotAt + 1)}';
  }
}
