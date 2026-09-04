import 'domain_error.dart';

/// Vi phạm quanh giao dịch và các value object dựng nên nó (Money, Currency, và
/// các khoảng lọc ở UC-07).
sealed class TransactionError extends DomainError {
  const TransactionError(super.message);
}

final class TransactionNotFoundError extends TransactionError {
  const TransactionNotFoundError(this.transactionId)
    : super('No transaction with id $transactionId.');

  final int transactionId;
}

/// Mã ISO 4217 luôn là đúng ba chữ cái; khác đi nghĩa là cột nguồn không phải
/// cột loại tiền.
final class InvalidCurrencyCodeError extends TransactionError {
  const InvalidCurrencyCodeError(this.code)
    : super('"$code" is not a valid ISO 4217 currency code.');

  final String code;
}

/// Hai số tiền khác loại tiền thì không so sánh được và không cộng được
/// (Rule – Currency Belongs to the Transaction and Never Mixes).
final class CurrencyMismatchError extends TransactionError {
  const CurrencyMismatchError(this.left, this.right)
    : super('Cannot combine amounts in $left and $right.');

  final String left;
  final String right;
}

/// Chuỗi trong cột nguồn không phải một số thập phân.
final class MalformedAmountError extends TransactionError {
  const MalformedAmountError(this.rawValue)
    : super('"$rawValue" is not a decimal amount.');

  final String rawValue;
}

/// Giá trị nguồn có nhiều chữ số thập phân có nghĩa hơn mức loại tiền cho phép,
/// ví dụ `1000.25` VND. Làm tròn âm thầm sẽ phá cả chống trùng lẫn đối soát, nên
/// dòng đó bị loại thành dòng lỗi (Rule – Money Is a Signed Integer, Never a
/// Floating-Point Number).
final class AmountPrecisionError extends TransactionError {
  const AmountPrecisionError(this.rawValue, this.currencyCode)
    : super(
        '"$rawValue" has more decimals than $currencyCode allows; '
        'rounding it would silently change the amount.',
      );

  final String rawValue;
  final String currencyCode;
}

final class InvalidDateRangeError extends TransactionError {
  const InvalidDateRangeError(this.from, this.to)
    : super('Date range starts at $from which is after $to.');

  final DateTime from;
  final DateTime to;
}

final class InvalidAmountRangeError extends TransactionError {
  const InvalidAmountRangeError(this.min, this.max)
    : super('Amount range lower bound $min is above upper bound $max.');

  final String min;
  final String max;
}
