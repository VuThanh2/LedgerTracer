import '../errors/transaction_errors.dart';
import 'currency.dart';

/// Số tiền có dấu, lưu bằng **số nguyên đơn vị nhỏ nhất** của [currency].
///
/// Không bao giờ dùng `double`: chống trùng (UC-02) và đối soát (UC-08) đều so
/// sánh bằng nhau tuyệt đối, còn thống kê (UC-10) cộng dồn hàng trăm nghìn dòng
/// — số thực phá cả ba (Rule – Money Is a Signed Integer, Never a
/// Floating-Point Number).
///
/// Dấu mang chiều tiền: dương là tiền vào, âm là tiền ra
/// (Rule – The Sign Carries the Direction).
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, this.currency);

  const Money.zero(this.currency) : minorUnits = 0;

  /// Đổi chuỗi số thập phân (parser đã bỏ dấu phân nhóm) sang đơn vị nhỏ nhất.
  ///
  /// Phần thập phân dư chỉ được chấp nhận khi toàn số 0 — `1000000.00` VND vẫn
  /// là một triệu đồng. Còn khi có chữ số khác 0 vượt quá độ chính xác của loại
  /// tiền thì giá trị không biểu diễn được nếu không làm tròn, nên dòng đó thành
  /// dòng lỗi ([AmountPrecisionError]) thay vì bị làm tròn âm thầm.
  factory Money.fromDecimalString(String value, Currency currency) {
    final match = _decimalPattern.firstMatch(value.trim());
    if (match == null) {
      throw MalformedAmountError(value);
    }

    var fraction = match.group(3) ?? '';
    if (fraction.length > currency.decimalDigits) {
      final dropped = fraction.substring(currency.decimalDigits);
      if (dropped.contains(_nonZeroDigit)) {
        throw AmountPrecisionError(value, currency.code);
      }
      fraction = fraction.substring(0, currency.decimalDigits);
    }

    final digits =
        '${match.group(2)}'
        '${fraction.padRight(currency.decimalDigits, '0')}';
    final magnitude = int.parse(digits);
    return Money(match.group(1) == '-' ? -magnitude : magnitude, currency);
  }

  /// Giá trị có dấu, tính bằng đơn vị nhỏ nhất (đồng với VND, cent với USD).
  final int minorUnits;

  final Currency currency;

  bool get isIncoming => minorUnits > 0;

  bool get isOutgoing => minorUnits < 0;

  bool get isZero => minorUnits == 0;

  Money get absolute => Money(minorUnits.abs(), currency);

  Money operator -() => Money(-minorUnits, currency);

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currency);
  }

  bool operator <(Money other) => compareTo(other) < 0;

  bool operator <=(Money other) => compareTo(other) <= 0;

  bool operator >(Money other) => compareTo(other) > 0;

  bool operator >=(Money other) => compareTo(other) >= 0;

  /// Hai vế của một giao dịch chuyển tiền nội bộ: cùng loại tiền, giá trị đối
  /// nhau và khác 0 (UC-08 bước 3).
  bool isOppositeOf(Money other) =>
      currency == other.currency &&
      minorUnits != 0 &&
      minorUnits == -other.minorUnits;

  /// Dạng thập phân trần (`-1234.56`), không phân nhóm, không kèm mã tiền —
  /// định dạng theo locale là việc của Presentation, ở đây chỉ cần đúng chữ số
  /// (file xuất ở UC-11 dùng dạng này).
  String toDecimalString() {
    if (currency.decimalDigits == 0) return minorUnits.toString();
    final sign = minorUnits < 0 ? '-' : '';
    final digits = minorUnits.abs().toString().padLeft(
      currency.decimalDigits + 1,
      '0',
    );
    final splitAt = digits.length - currency.decimalDigits;
    return '$sign${digits.substring(0, splitAt)}.${digits.substring(splitAt)}';
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  void _requireSameCurrency(Money other) {
    if (currency != other.currency) {
      throw CurrencyMismatchError(currency.code, other.currency.code);
    }
  }

  static final RegExp _decimalPattern = RegExp(r'^([+-]?)(\d+)(?:[.](\d+))?$');
  static final RegExp _nonZeroDigit = RegExp(r'[^0]');

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${toDecimalString()} ${currency.code}';
}
