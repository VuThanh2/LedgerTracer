import '../entities/bank_account.dart';

/// Cổng lưu trữ của aggregate BankAccount (UC-01).
///
/// Phần hiện thực nằm ở tầng Infrastructure và ném các lỗi khai báo trong
/// `errors/account_errors.dart`; việc bọc chúng thành `Result` là của tầng
/// Application.
///
/// Xoá tài khoản còn phải xoá giao dịch của nó và các bản ghi nhập của những
/// file gán vào nó. Chuỗi xoá đó trải trên nhiều aggregate nên do tầng
/// Application điều phối tường minh trong một `UnitOfWork` — [deleteById] chỉ
/// xoá đúng dòng tài khoản.
abstract interface class BankAccountRepository {
  /// Toàn bộ tài khoản đã khai báo, sắp theo tên hiển thị.
  Future<List<BankAccount>> findAll();

  Future<BankAccount?> findById(int accountId);

  /// Lưu tài khoản mới và trả về nó kèm định danh cơ sở dữ liệu vừa cấp.
  Future<BankAccount> add(BankAccount account);

  /// Lưu tài khoản vừa đổi tên, hoặc vừa học được số tài khoản trong lúc nhập
  /// (UC-02 bước 4), hoặc vừa được sửa số tài khoản bằng tay (UC-01).
  ///
  /// Ném `AccountNotFoundError` nếu bản ghi không còn tồn tại.
  Future<void> update(BankAccount account);

  Future<void> deleteById(int accountId);
}
