import '../errors/account_errors.dart';

/// Nhãn do người dùng tự khai báo để nhóm giao dịch (UC-01). Không có kết nối và
/// không xác thực gì với ngân hàng thật.
///
/// Là aggregate root độc lập: giao dịch **không** nằm trong nó, vì một tài khoản
/// có thể chứa hàng trăm nghìn giao dịch mà ranh giới aggregate lại là ranh giới
/// nạp-và-ghi. Luật "xoá tài khoản thì xoá giao dịch" vì thế được tầng
/// Application thi hành tường minh trong một transaction.
final class BankAccount {
  const BankAccount({
    this.accountId,
    required this.displayName,
    this.accountNumber,
    required this.createdAt,
  });

  /// Tạo tài khoản chưa được lưu. Ném [EmptyAccountNameError] nếu nhãn rỗng.
  factory BankAccount.create({
    required String displayName,
    required DateTime createdAt,
  }) =>
      BankAccount(displayName: _requireName(displayName), createdAt: createdAt);

  /// `null` cho tới khi bản ghi được ghi xuống; cơ sở dữ liệu cấp giá trị này.
  final int? accountId;

  /// Nhãn tự đặt, ví dụ "Tài khoản vận hành - Vietinbank". Không bắt buộc duy
  /// nhất, nhưng phân biệt được thì đỡ chọn nhầm tài khoản đích (UC-02 bước 3).
  final String displayName;

  /// Được **học** từ file sao kê đầu tiên có mang nó (UC-02 bước 4), người dùng
  /// không gõ tay. Nó chỉ là mốc đối chiếu để phát hiện gán nhầm file.
  final String? accountNumber;

  final DateTime createdAt;

  bool get isPersisted => accountId != null;

  bool get hasAccountNumber => accountNumber != null;

  BankAccount withIdentity(int id) => BankAccount(
    accountId: id,
    displayName: displayName,
    accountNumber: accountNumber,
    createdAt: createdAt,
  );

  BankAccount renamedTo(String newDisplayName) => BankAccount(
    accountId: accountId,
    displayName: _requireName(newDisplayName),
    accountNumber: accountNumber,
    createdAt: createdAt,
  );

  /// Ghi nhận số tài khoản, khi học được từ file (UC-02 bước 4) hoặc khi người
  /// dùng sửa lại vì lần nhập đầu đã học sai (UC-01).
  BankAccount withAccountNumber(String number) => BankAccount(
    accountId: accountId,
    displayName: displayName,
    accountNumber: normalizeAccountNumber(number),
    createdAt: createdAt,
  );

  BankAccount withoutAccountNumber() => BankAccount(
    accountId: accountId,
    displayName: displayName,
    createdAt: createdAt,
  );

  /// Số tài khoản nhúng trong file (ví dụ tag `:25:` của MT940) có đúng là số đã
  /// ghi nhận ở đây không.
  ///
  /// Trả `false` khi chưa ghi nhận gì — phép kiểm chỉ có nghĩa từ lần nhập thứ
  /// hai, và lệch cũng không bao giờ chặn cứng, chỉ cảnh báo (UC-02 bước 4).
  /// Chuỗi không đọc được cũng chỉ là không khớp, hàm này không bao giờ ném.
  bool matchesAccountNumber(String candidate) {
    final recorded = accountNumber;
    if (recorded == null) return false;
    return recorded == _tryNormalizeAccountNumber(candidate);
  }

  /// Sao kê ghi cùng một số theo nhiều kiểu (`0011 0004 1234`,
  /// `VN-001100041234`), muốn so sánh thì phải có một dạng chính tắc.
  ///
  /// Ném [InvalidAccountNumberError] khi không còn ký tự chữ/số nào.
  static String normalizeAccountNumber(String raw) {
    final normalized = _tryNormalizeAccountNumber(raw);
    if (normalized == null) throw InvalidAccountNumberError(raw);
    return normalized;
  }

  static String? _tryNormalizeAccountNumber(String raw) {
    final normalized = raw.replaceAll(_separators, '').toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }

  static String _requireName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) throw const EmptyAccountNameError();
    return trimmed;
  }

  static final RegExp _separators = RegExp('[^0-9A-Za-z]');

  /// So sánh theo định danh (entity): hai lần nạp cùng một bản ghi là cùng một
  /// tài khoản. Thực thể chưa có định danh chỉ bằng chính nó.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BankAccount &&
          other.accountId != null &&
          other.accountId == accountId);

  @override
  int get hashCode => accountId?.hashCode ?? identityHashCode(this);

  @override
  String toString() => 'BankAccount($accountId, $displayName)';
}
