import '../errors/transaction_errors.dart';
import 'currency.dart';
import 'money.dart';

/// Khoảng số tiền để lọc, hai đầu đều tính vào (UC-07).
///
/// Luôn mang theo [currency]: so sánh hai con số khác đơn vị là vô nghĩa, và một
/// khoảng "1 đến 5 triệu" sẽ âm thầm loại mất giao dịch 1.000 USD
/// (Rule – Currency Belongs to the Transaction and Never Mixes).
///
/// Hai cận **có dấu**, đúng như số tiền mà nó lọc: `[1tr, 5tr]` giữ giao dịch
/// tiền vào, `[-5tr, -1tr]` giữ tiền ra, `[-5tr, 5tr]` giữ cả hai. Dấu đã là
/// chiều tiền nên không cần thêm tiêu chí "chiều" nào nữa
/// (Rule – The Sign Carries the Direction).
final class AmountRange {
  const AmountRange._(this.min, this.max);

  /// Ném [CurrencyMismatchError] nếu hai cận khác loại tiền, và
  /// [InvalidAmountRangeError] nếu chúng ngược thứ tự.
  factory AmountRange({required Money min, required Money max}) {
    if (min.currency != max.currency) {
      throw CurrencyMismatchError(min.currency.code, max.currency.code);
    }
    if (min.minorUnits > max.minorUnits) {
      throw InvalidAmountRangeError(min.toString(), max.toString());
    }
    return AmountRange._(min, max);
  }

  /// `amount >= min`, không phải bịa ra một cận trên.
  factory AmountRange.atLeast(Money min) =>
      AmountRange(min: min, max: Money(_maxMinorUnits, min.currency));

  /// `amount <= max`, không phải bịa ra một cận dưới.
  factory AmountRange.atMost(Money max) =>
      AmountRange(min: Money(-_maxMinorUnits, max.currency), max: max);

  final Money min;
  final Money max;

  Currency get currency => min.currency;

  /// Giao dịch khác loại tiền đơn giản là không nằm trong khoảng — bộ lọc thu
  /// hẹp kết quả chứ không báo lỗi.
  bool contains(Money amount) =>
      amount.currency == currency &&
      amount.minorUnits >= min.minorUnits &&
      amount.minorUnits <= max.minorUnits;

  /// Giá trị canh cho cận mở, để nó vẫn là một phép so sánh có chỉ mục thay vì
  /// một nhánh đặc biệt trong mọi truy vấn. Lấy 2^53-1 — số nguyên lớn nhất còn
  /// chính xác trên cả native lẫn Web — vẫn xa hơn mọi số tiền thực tế.
  static const int _maxMinorUnits = 9007199254740991;

  @override
  bool operator ==(Object other) =>
      other is AmountRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() =>
      '${min.toDecimalString()}'
      '..${max.toDecimalString()} ${currency.code}';
}
