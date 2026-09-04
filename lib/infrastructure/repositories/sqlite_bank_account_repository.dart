import '../../domain/entities/bank_account.dart';
import '../../domain/errors/account_errors.dart';
import '../../domain/repositories/bank_account_repository.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../database/sql_codec.dart';

/// Hiện thực SQLite của [BankAccountRepository] (UC-01).
///
/// [deleteById] chỉ xoá đúng dòng tài khoản. Việc xoá theo giao dịch, bản ghi
/// nhập, cặp đối soát và phán quyết từ chối là chuỗi trải trên nhiều aggregate,
/// do tầng Application điều phối tường minh trong một `UnitOfWork` — và khoá
/// ngoại của lược đồ sẽ chặn ồn ào nếu chuỗi đó bỏ sót một bước.
final class SqliteBankAccountRepository implements BankAccountRepository {
  const SqliteBankAccountRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<BankAccount>> findAll() async {
    final rows = await _db.executor.query(
      LedgerSchema.bankAccount,
      orderBy: 'display_name COLLATE NOCASE, account_id',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  @override
  Future<BankAccount?> findById(int accountId) async {
    final rows = await _db.executor.query(
      LedgerSchema.bankAccount,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  @override
  Future<BankAccount> add(BankAccount account) async {
    final id = await _db.executor.insert(
      LedgerSchema.bankAccount,
      _toRow(account),
    );
    return account.withIdentity(id);
  }

  @override
  Future<void> update(BankAccount account) async {
    final changed = await _db.executor.update(
      LedgerSchema.bankAccount,
      _toRow(account),
      where: 'account_id = ?',
      whereArgs: <Object?>[account.accountId],
    );
    // Không dòng nào đổi nghĩa là bản ghi đã biến mất giữa lúc màn hình đọc nó
    // và lúc người dùng bấm lưu. Báo ra thay vì để lệnh trôi qua trong im lặng:
    // tầng Application dịch nó thành `NotFoundFailure` và giao diện làm mới.
    if (changed == 0) throw AccountNotFoundError(account.accountId!);
  }

  @override
  Future<void> deleteById(int accountId) async {
    await _db.executor.delete(
      LedgerSchema.bankAccount,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
    );
  }

  static Map<String, Object?> _toRow(BankAccount account) => <String, Object?>{
    'display_name': account.displayName,
    'account_number': account.accountNumber,
    'created_at': SqlCodec.timestamp(account.createdAt),
  };

  static BankAccount _fromRow(Map<String, Object?> row) => BankAccount(
    accountId: row['account_id'] as int,
    displayName: row['display_name'] as String,
    accountNumber: row['account_number'] as String?,
    createdAt: SqlCodec.parseTimestamp(row['created_at'] as int),
  );
}
