import 'domain_error.dart';

/// Vi phạm của aggregate BankAccount (UC-01).
sealed class AccountError extends DomainError {
  const AccountError(super.message);
}

/// Tài khoản luôn cần một nhãn để nhận ra được trong danh sách chọn tài khoản
/// đích lúc nhập file (UC-02 bước 3).
final class EmptyAccountNameError extends AccountError {
  const EmptyAccountNameError()
    : super('Bank account display name must not be blank.');
}

/// Số tài khoản được học từ file sao kê (UC-02 bước 4) hoặc sửa tay (UC-01);
/// kiểu gì cũng phải còn ít nhất một ký tự chữ hoặc số.
final class InvalidAccountNumberError extends AccountError {
  const InvalidAccountNumberError(this.rawValue)
    : super('Account number "$rawValue" contains no usable characters.');

  final String rawValue;
}

final class AccountNotFoundError extends AccountError {
  const AccountNotFoundError(this.accountId)
    : super('No bank account with id $accountId.');

  final int accountId;
}
