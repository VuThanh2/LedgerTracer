import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/bank_account.dart';
import '../../../domain/errors/account_errors.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../../domain/repositories/import_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/domain_failures.dart';

/// Những gì việc xoá một tài khoản sẽ động tới, để hộp thoại xác nhận nêu rõ con
/// số trước khi người dùng đồng ý (UC-01).
final class AccountDeletionImpact {
  const AccountDeletionImpact({
    required this.transactionCount,
    required this.reconciledPairCount,
  });

  final int transactionCount;

  /// Số cặp đối soát sẽ bị huỷ vì một trong hai vế thuộc tài khoản này (UC-09).
  final int reconciledPairCount;
}

/// Quản lý danh sách tài khoản ngân hàng: thêm, đổi tên, sửa/xoá số tài khoản đã
/// ghi nhận, và xoá tài khoản (UC-01).
///
/// Tài khoản là nhãn tự đặt, không có kết nối hay xác thực với ngân hàng thật. Số
/// tài khoản **không phải trường người dùng tự khai khi tạo**: nó được học từ file
/// sao kê đầu tiên có mang nó (UC-02 bước 4); màn hình này chỉ hiển thị số đã học
/// và cho sửa/xoá phòng khi học nhầm.
///
/// Xoá một tài khoản kéo theo cả một chuỗi trải trên nhiều aggregate — giao dịch,
/// bản ghi nhập của các file gán vào nó, các cặp và phán quyết từ chối dính tới
/// các giao dịch đó. Domain cố ý không lồng các aggregate ấy vào nhau (một tài
/// khoản có thể chứa hàng trăm nghìn giao dịch), nên chuỗi này được thi hành
/// **tường minh** trong một [UnitOfWork].
final class ManageAccountsUseCase {
  ManageAccountsUseCase({
    required this._accounts,
    required this._transactions,
    required this._reconciliation,
    required this._imports,
    required this._unitOfWork,
    required this._now,
  });

  final BankAccountRepository _accounts;
  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final ImportRepository _imports;
  final UnitOfWork _unitOfWork;
  final DateTime Function() _now;

  Future<Result<List<BankAccount>>> list() =>
      Result.guardAsync(_accounts.findAll, onError: failureFromError);

  /// Thêm tài khoản mới bằng tên hiển thị. Ném [EmptyAccountNameError] nếu tên
  /// rỗng.
  Future<Result<BankAccount>> add(String displayName) => Result.guardAsync(
    () => _accounts.add(
      BankAccount.create(displayName: displayName, createdAt: _now()),
    ),
    onError: failureFromError,
  );

  Future<Result<BankAccount>> rename(int accountId, String displayName) =>
      _mutate(accountId, (account) => account.renamedTo(displayName));

  /// Sửa số tài khoản đã ghi nhận, phòng khi lần nhập đầu học sai (UC-01).
  Future<Result<BankAccount>> setAccountNumber(int accountId, String number) =>
      _mutate(accountId, (account) => account.withAccountNumber(number));

  Future<Result<BankAccount>> clearAccountNumber(int accountId) =>
      _mutate(accountId, (account) => account.withoutAccountNumber());

  /// Số liệu cho hộp thoại xác nhận xoá (UC-01).
  ///
  /// Đếm bằng truy vấn có phạm vi chứ không nạp danh sách định danh: một tài
  /// khoản có thể chứa hàng trăm nghìn giao dịch, và kéo từng ấy id lên luồng
  /// chính chỉ để lấy hai con số là việc vừa chậm vừa sẽ vỡ ở trần tham số của
  /// SQLite.
  Future<Result<AccountDeletionImpact>> previewDeletion(int accountId) =>
      Result.guardAsync(() async {
        final transactionCount = await _transactions.countByAccountId(
          accountId,
        );
        final pairs = await _reconciliation.countPairsByAccountId(accountId);
        return AccountDeletionImpact(
          transactionCount: transactionCount,
          reconciledPairCount: pairs,
        );
      }, onError: failureFromError);

  /// Xoá tài khoản cùng toàn bộ dữ liệu dây chuyền. Đơn vị bị xoá theo là **bản
  /// ghi của từng file** có tài khoản đích là tài khoản này, không phải cả lượt:
  /// một lượt nhiều file có thể gán nhiều tài khoản khác nhau (UC-01, UC-03).
  Future<Result<void>> delete(int accountId) => Result.guardAsync(() async {
    final account = await _accounts.findById(accountId);
    if (account == null) throw AccountNotFoundError(accountId);
    await _unitOfWork.transaction(() async {
      // Thứ tự bắt buộc: cặp và phán quyết trỏ tới giao dịch, giao dịch trỏ tới
      // tài khoản — gỡ từ ngoài vào trong.
      await _reconciliation.deletePairsByAccountId(accountId);
      await _reconciliation.deleteRejectionsByAccountId(accountId);
      await _transactions.deleteByAccountId(accountId);
      final fileRecords = await _imports.findFileRecordsByAccountId(accountId);
      for (final record in fileRecords) {
        await _imports.deleteFileRecordById(record.recordId!);
      }
      // Lượt nhập chỉ biến mất khi không còn bản ghi con nào.
      await _imports.deleteEmptySessions();
      await _accounts.deleteById(accountId);
    });
  }, onError: failureFromError);

  Future<Result<BankAccount>> _mutate(
    int accountId,
    BankAccount Function(BankAccount account) change,
  ) => Result.guardAsync(() async {
    final account = await _accounts.findById(accountId);
    if (account == null) throw AccountNotFoundError(accountId);
    final updated = change(account);
    await _accounts.update(updated);
    return updated;
  }, onError: failureFromError);
}
