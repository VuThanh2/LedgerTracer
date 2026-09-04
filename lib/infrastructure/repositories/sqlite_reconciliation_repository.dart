// `sqflite` cũng có một kiểu tên `Transaction` (transaction của cơ sở dữ liệu);
// ẩn nó đi để `Transaction` trong file này luôn là entity của Domain.
import 'package:sqflite_common/sqlite_api.dart' hide Transaction;

import '../../domain/entities/reconciliation_pair.dart';
import '../../domain/entities/rejected_match.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/reconciliation_repository.dart';
import '../../domain/value_objects/match_window.dart';
import '../../domain/value_objects/pair_status.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../database/sql_codec.dart';
import '../database/sql_query.dart';
import 'mappers/reconciliation_mapper.dart';
import 'mappers/transaction_mapper.dart';

/// Hiện thực SQLite của [ReconciliationRepository] (UC-08, UC-09).
///
/// Các phương thức nhận **khoá phạm vi** (`accountId`, `importFileRecordId`)
/// dịch thành một câu lệnh có điều kiện lồng và dùng được ở mọi quy mô; chỉ các
/// phương thức nhận `Iterable<int>` mới đi vào mệnh đề `IN`, và chúng chỉ được
/// gọi với **một trang** dữ liệu. Ranh giới đó là có chủ đích: một tài khoản có
/// thể mang hàng trăm nghìn giao dịch, và nạp từng ấy định danh lên luồng chính
/// chỉ để xoá là việc vừa chậm vừa sẽ vỡ.
final class SqliteReconciliationRepository
    implements ReconciliationRepository {
  const SqliteReconciliationRepository(this._db);

  final AppDatabase _db;

  /// Điều kiện "giao dịch [alias] chưa thuộc cặp nào".
  ///
  /// Viết một lần rồi dùng lại cho cả tập ứng viên của lần quét lẫn danh sách
  /// ứng viên tính lại lúc hiển thị — hai bản chép tay của cùng điều kiện sẽ
  /// lệch nhau, và người dùng sẽ thấy một ứng viên ở màn hình này mà không thấy
  /// ở màn hình kia (Rule – Suggested Is Not Confirmed).
  static String _unpaired(String alias) =>
      'NOT EXISTS (SELECT 1 FROM ${LedgerSchema.reconciliationPair} pair '
      'WHERE pair.outgoing_transaction_id = $alias.transaction_id '
      'OR pair.incoming_transaction_id = $alias.transaction_id)';

  /// Điều kiện "cặp `pair` có ít nhất một vế thoả [transactionWhere]".
  static String _pairTouches(String transactionWhere) =>
      'EXISTS (SELECT 1 FROM ${LedgerSchema.transaction} txn '
      'WHERE $transactionWhere AND (txn.transaction_id = '
      '${LedgerSchema.reconciliationPair}.outgoing_transaction_id '
      'OR txn.transaction_id = '
      '${LedgerSchema.reconciliationPair}.incoming_transaction_id))';

  /// Điều kiện "phán quyết có ít nhất một vế thoả [transactionWhere]".
  static String _rejectionTouches(String transactionWhere) =>
      'EXISTS (SELECT 1 FROM ${LedgerSchema.transaction} txn '
      'WHERE $transactionWhere AND (txn.transaction_id = '
      '${LedgerSchema.rejectedMatch}.transaction_a_id '
      'OR txn.transaction_id = '
      '${LedgerSchema.rejectedMatch}.transaction_b_id))';

  @override
  Future<List<ReconciliationPair>> findPairs({
    PairStatus? status,
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.executor.query(
      LedgerSchema.reconciliationPair,
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : <Object?>[status.name],
      orderBy: 'created_at DESC, pair_id DESC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(ReconciliationMapper.pairFromRow)
        .toList(growable: false);
  }

  @override
  Future<int> countPairs({PairStatus? status}) => _db.executor.countRows(
    'SELECT COUNT(*) FROM ${LedgerSchema.reconciliationPair}'
    '${status == null ? '' : ' WHERE status = ?'}',
    status == null ? null : <Object?>[status.name],
  );

  @override
  Future<ReconciliationPair?> findPairById(int pairId) async {
    final rows = await _db.executor.query(
      LedgerSchema.reconciliationPair,
      where: 'pair_id = ?',
      whereArgs: <Object?>[pairId],
      limit: 1,
    );
    return rows.isEmpty ? null : ReconciliationMapper.pairFromRow(rows.first);
  }

  @override
  Future<ReconciliationPair?> findPairInvolving(int transactionId) async {
    final rows = await _db.executor.query(
      LedgerSchema.reconciliationPair,
      where: 'outgoing_transaction_id = ? OR incoming_transaction_id = ?',
      whereArgs: <Object?>[transactionId, transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : ReconciliationMapper.pairFromRow(rows.first);
  }

  @override
  Future<Set<int>> findPairedTransactionIds(
    Iterable<int> transactionIds, {
    PairStatus? status,
  }) async {
    final wanted = transactionIds.toSet();
    if (wanted.isEmpty) return const <int>{};

    final paired = <int>{};
    // Lô ở đây chỉ bằng **nửa** trần, vì mỗi lô đi vào hai mệnh đề `IN` của cùng
    // một câu lệnh (vế chuyển ra và vế nhận vào) — trần của SQLite tính trên
    // tổng số tham số của cả câu. Lấy nguyên trần thì một trang 1000 dòng của
    // luồng xuất file sẽ gửi hơn 1000 tham số và vỡ trên các bản SQLite còn giữ
    // giới hạn 999, tức trên chính những thiết bị Android đời cũ.
    for (final chunk in SqlQuery.chunked(
      wanted,
      maxPerChunk: SqlQuery.maxVariablesPerStatement ~/ 2,
    )) {
      final slots = SqlQuery.placeholders(chunk.length);
      final rows = await _db.executor.rawQuery(
        'SELECT outgoing_transaction_id, incoming_transaction_id '
        'FROM ${LedgerSchema.reconciliationPair} '
        'WHERE ${status == null ? '' : 'status = ? AND '}'
        '(outgoing_transaction_id IN ($slots) '
        'OR incoming_transaction_id IN ($slots))',
        <Object?>[if (status != null) status.name, ...chunk, ...chunk],
      );
      for (final row in rows) {
        // Một cặp có thể có một vế nằm trong trang và vế kia thì không; chỉ vế
        // được hỏi mới được trả về, vì con số này đi thẳng vào chỉ báo "đã đối
        // soát" của từng dòng đang hiển thị (UC-04).
        for (final value in row.values) {
          if (value is int && wanted.contains(value)) paired.add(value);
        }
      }
    }
    return paired;
  }

  @override
  Future<void> addPairs(List<ReconciliationPair> pairs) async {
    if (pairs.isEmpty) return;
    final batch = _db.executor.batch();
    for (final pair in pairs) {
      batch.insert(
        LedgerSchema.reconciliationPair,
        ReconciliationMapper.pairToRow(pair),
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> updatePair(ReconciliationPair pair) async {
    await _db.executor.update(
      LedgerSchema.reconciliationPair,
      ReconciliationMapper.pairToRow(pair),
      where: 'pair_id = ?',
      whereArgs: <Object?>[pair.pairId],
    );
  }

  @override
  Future<void> deletePairById(int pairId) async {
    await _db.executor.delete(
      LedgerSchema.reconciliationPair,
      where: 'pair_id = ?',
      whereArgs: <Object?>[pairId],
    );
  }

  /// Cặp **đã xác nhận** sống sót qua một lần chạy lại: nó mang phán quyết của
  /// người dùng, còn gợi ý chỉ là kết quả của một lần dò tìm (UC-08).
  @override
  Future<int> deleteSuggestedPairs() => _db.executor.delete(
    LedgerSchema.reconciliationPair,
    where: 'status = ?',
    whereArgs: <Object?>[PairStatus.suggested.name],
  );

  @override
  Future<int> deletePairsInvolvingTransaction(int transactionId) =>
      _db.executor.delete(
        LedgerSchema.reconciliationPair,
        where: 'outgoing_transaction_id = ? OR incoming_transaction_id = ?',
        whereArgs: <Object?>[transactionId, transactionId],
      );

  @override
  Future<int> countPairsByAccountId(int accountId) => _db.executor.countRows(
    'SELECT COUNT(*) FROM ${LedgerSchema.reconciliationPair} '
    'WHERE ${_pairTouches('txn.account_id = ?')}',
    <Object?>[accountId],
  );

  @override
  Future<int> deletePairsByAccountId(int accountId) => _db.executor.delete(
    LedgerSchema.reconciliationPair,
    where: _pairTouches('txn.account_id = ?'),
    whereArgs: <Object?>[accountId],
  );

  @override
  Future<int> countPairsByImportFileRecordId(int recordId) =>
      _db.executor.countRows(
        'SELECT COUNT(*) FROM ${LedgerSchema.reconciliationPair} '
        'WHERE ${_pairTouches('txn.import_file_record_id = ?')}',
        <Object?>[recordId],
      );

  @override
  Future<int> deletePairsByImportFileRecordId(int recordId) =>
      _db.executor.delete(
        LedgerSchema.reconciliationPair,
        where: _pairTouches('txn.import_file_record_id = ?'),
        whereArgs: <Object?>[recordId],
      );

  @override
  Future<List<Transaction>> findUnpairedTransactions({
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.executor.rawQuery(
      'SELECT * FROM ${LedgerSchema.transaction} txn '
      'WHERE ${_unpaired('txn')} '
      // Theo định danh tăng dần: lần quét đi qua tập ứng viên theo trang, và
      // một thứ tự ổn định là điều kiện để hai lần chạy trên cùng dữ liệu cho ra
      // cùng kết quả (UC-08).
      'ORDER BY txn.transaction_id LIMIT ? OFFSET ?',
      <Object?>[limit, offset],
    );
    return rows.map(TransactionMapper.fromRow).toList(growable: false);
  }

  @override
  Future<int> countUnpairedTransactions() => _db.executor.countRows(
    'SELECT COUNT(*) FROM ${LedgerSchema.transaction} txn '
    'WHERE ${_unpaired('txn')}',
  );

  /// Ứng viên ghép **thô** của một giao dịch (UC-08, UC-09).
  ///
  /// Điều kiện ở đây là bản dịch sang SQL của đúng vị từ `MatchPredicate.canPair`
  /// — khác tài khoản, cùng loại tiền, số tiền đối nhau, ngày nằm trong cửa sổ —
  /// để cơ sở dữ liệu thu hẹp bằng chỉ mục thay vì trả cả bảng lên rồi lọc trong
  /// Dart. Việc loại các cặp **đã bị từ chối** cố ý không nằm ở đây: nó thuộc
  /// tầng Application, nơi phán quyết được đọc ra một lần và dùng chung cho cả
  /// lần quét lẫn màn hình.
  @override
  Future<List<Transaction>> findMatchCandidates({
    required Transaction anchor,
    required MatchWindow window,
  }) async {
    // Số tiền 0 không có vế đối nào — `Money.isOppositeOf` cũng nói đúng điều
    // đó, và hỏi cơ sở dữ liệu một câu chắc chắn rỗng thì không để làm gì.
    if (anchor.amount.isZero) return const <Transaction>[];

    final rows = await _db.executor.rawQuery(
      'SELECT * FROM ${LedgerSchema.transaction} txn '
      'WHERE txn.account_id <> ? '
      'AND txn.currency = ? '
      'AND txn.amount_minor = ? '
      'AND txn.booking_date BETWEEN ? AND ? '
      'AND ${_unpaired('txn')} '
      'ORDER BY txn.transaction_id',
      <Object?>[
        anchor.accountId,
        anchor.amount.currency.code,
        -anchor.amount.minorUnits,
        SqlCodec.bookingDate(
          anchor.bookingDate.subtract(Duration(days: window.days)),
        ),
        SqlCodec.bookingDate(
          anchor.bookingDate.add(Duration(days: window.days)),
        ),
      ],
    );
    return rows.map(TransactionMapper.fromRow).toList(growable: false);
  }

  /// Ghi lại phán quyết "hai giao dịch này không phải một cặp".
  ///
  /// Ghi đè khi phán quyết đó đã tồn tại: sau khi người dùng gỡ rồi từ chối lại
  /// cùng một cặp, thứ đúng để giữ là **lần phán quyết mới nhất**, không phải
  /// một lỗi ràng buộc duy nhất bật ngược lên giao diện.
  @override
  Future<RejectedMatch> addRejection(RejectedMatch rejection) async {
    final id = await _db.executor.insert(
      LedgerSchema.rejectedMatch,
      ReconciliationMapper.rejectionToRow(rejection),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return rejection.withIdentity(id);
  }

  @override
  Future<bool> deleteRejectionById(int rejectedMatchId) async {
    final removed = await _db.executor.delete(
      LedgerSchema.rejectedMatch,
      where: 'rejected_match_id = ?',
      whereArgs: <Object?>[rejectedMatchId],
    );
    return removed > 0;
  }

  @override
  Future<int> deleteRejectionsInvolvingTransaction(int transactionId) =>
      _db.executor.delete(
        LedgerSchema.rejectedMatch,
        where: 'transaction_a_id = ? OR transaction_b_id = ?',
        whereArgs: <Object?>[transactionId, transactionId],
      );

  @override
  Future<int> deleteRejectionsByAccountId(int accountId) => _db.executor.delete(
    LedgerSchema.rejectedMatch,
    where: _rejectionTouches('txn.account_id = ?'),
    whereArgs: <Object?>[accountId],
  );

  @override
  Future<int> deleteRejectionsByImportFileRecordId(int recordId) =>
      _db.executor.delete(
        LedgerSchema.rejectedMatch,
        where: _rejectionTouches('txn.import_file_record_id = ?'),
        whereArgs: <Object?>[recordId],
      );

  @override
  Future<List<RejectedMatch>> findRejections({
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.executor.query(
      LedgerSchema.rejectedMatch,
      orderBy: 'rejected_at DESC, rejected_match_id DESC',
      limit: limit,
      offset: offset,
    );
    return rows
        .map(ReconciliationMapper.rejectionFromRow)
        .toList(growable: false);
  }

  @override
  Future<List<RejectedMatch>> findRejectionsForTransaction(
    int transactionId,
  ) async {
    final rows = await _db.executor.query(
      LedgerSchema.rejectedMatch,
      where: 'transaction_a_id = ? OR transaction_b_id = ?',
      whereArgs: <Object?>[transactionId, transactionId],
    );
    return rows
        .map(ReconciliationMapper.rejectionFromRow)
        .toList(growable: false);
  }
}
