import 'package:ledger_tracer/core/persistence/unit_of_work.dart';
import 'package:ledger_tracer/domain/entities/app_settings.dart';
import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/domain/entities/import_error_row.dart';
import 'package:ledger_tracer/domain/entities/import_file_record.dart';
import 'package:ledger_tracer/domain/entities/import_session.dart';
import 'package:ledger_tracer/domain/entities/reconciliation_pair.dart';
import 'package:ledger_tracer/domain/entities/rejected_match.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/errors/import_errors.dart';
import 'package:ledger_tracer/domain/errors/transaction_errors.dart';
import 'package:ledger_tracer/domain/repositories/app_settings_repository.dart';
import 'package:ledger_tracer/domain/repositories/bank_account_repository.dart';
import 'package:ledger_tracer/domain/repositories/import_repository.dart';
import 'package:ledger_tracer/domain/repositories/reconciliation_repository.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/services/match_predicate.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/fingerprint.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/pair_status.dart';

/// Cơ sở dữ liệu giả trong bộ nhớ, dùng chung cho toàn bộ test tầng Application.
///
/// Nó cố ý **không** phải mock ghi lại lời gọi: thứ đáng kiểm ở tầng use case là
/// *trạng thái sau cùng* của dữ liệu, không phải chuỗi phương thức đã gọi. Một
/// bộ mock đếm lời gọi sẽ pass ngay cả khi thứ tự các bước sai, còn bản này thì
/// không — nó thi hành đúng những ràng buộc mà cài đặt SQLite sẽ phải thi hành.
final class FakeDatabase {
  FakeDatabase() {
    accounts = FakeBankAccountRepository(this);
    transactions = FakeTransactionRepository(this);
    imports = FakeImportRepository(this);
    reconciliation = FakeReconciliationRepository(this);
    settings = FakeAppSettingsRepository();
    unitOfWork = FakeUnitOfWork(this);
  }

  late final FakeBankAccountRepository accounts;
  late final FakeTransactionRepository transactions;
  late final FakeImportRepository imports;
  late final FakeReconciliationRepository reconciliation;
  late final FakeAppSettingsRepository settings;
  late final FakeUnitOfWork unitOfWork;

  final Map<int, BankAccount> accountRows = <int, BankAccount>{};
  final Map<int, Transaction> transactionRows = <int, Transaction>{};
  final Map<int, ImportSession> sessionRows = <int, ImportSession>{};
  final Map<int, ImportFileRecord> fileRecordRows = <int, ImportFileRecord>{};
  final List<ImportErrorRow> errorRows = <ImportErrorRow>[];
  final Map<int, ReconciliationPair> pairRows = <int, ReconciliationPair>{};
  final Map<int, RejectedMatch> rejectionRows = <int, RejectedMatch>{};

  int _nextId = 0;
  int nextId() => ++_nextId;

  /// Ảnh chụp để khôi phục khi một transaction bị quay lui.
  FakeSnapshot snapshot() => FakeSnapshot(
    accounts: Map<int, BankAccount>.of(accountRows),
    transactions: Map<int, Transaction>.of(transactionRows),
    sessions: Map<int, ImportSession>.of(sessionRows),
    fileRecords: Map<int, ImportFileRecord>.of(fileRecordRows),
    errors: List<ImportErrorRow>.of(errorRows),
    pairs: Map<int, ReconciliationPair>.of(pairRows),
    rejections: Map<int, RejectedMatch>.of(rejectionRows),
  );

  void restore(FakeSnapshot snapshot) {
    accountRows
      ..clear()
      ..addAll(snapshot.accounts);
    transactionRows
      ..clear()
      ..addAll(snapshot.transactions);
    sessionRows
      ..clear()
      ..addAll(snapshot.sessions);
    fileRecordRows
      ..clear()
      ..addAll(snapshot.fileRecords);
    errorRows
      ..clear()
      ..addAll(snapshot.errors);
    pairRows
      ..clear()
      ..addAll(snapshot.pairs);
    rejectionRows
      ..clear()
      ..addAll(snapshot.rejections);
  }
}

final class FakeSnapshot {
  const FakeSnapshot({
    required this.accounts,
    required this.transactions,
    required this.sessions,
    required this.fileRecords,
    required this.errors,
    required this.pairs,
    required this.rejections,
  });

  final Map<int, BankAccount> accounts;
  final Map<int, Transaction> transactions;
  final Map<int, ImportSession> sessions;
  final Map<int, ImportFileRecord> fileRecords;
  final List<ImportErrorRow> errors;
  final Map<int, ReconciliationPair> pairs;
  final Map<int, RejectedMatch> rejections;
}

/// Quay lui thật khi thân transaction ném, để test kiểm được rằng use case đã
/// đặt đúng ranh giới nguyên tử.
final class FakeUnitOfWork implements UnitOfWork {
  FakeUnitOfWork(this._db);

  final FakeDatabase _db;

  int depth = 0;
  int committed = 0;
  int rolledBack = 0;

  /// Gọi sau mỗi lần ranh giới **ngoài cùng** commit.
  ///
  /// Có mặt vì một lớp bất biến của hệ thống không phải "đúng ở cuối use case"
  /// mà là "đúng tại mọi thời điểm dữ liệu nằm yên trên đĩa": tiến trình có thể
  /// bị hệ điều hành kết liễu ngay sau bất kỳ lần commit nào, và khi đó không
  /// còn dòng lệnh nào chạy để dọn dẹp. Kiểm ở cuối test không bắt được loại lỗi
  /// đó, kiểm ở đây thì có.
  void Function()? onCommit;

  @override
  Future<T> transaction<T>(Future<T> Function() action) async {
    final snapshot = _db.snapshot();
    depth++;
    try {
      final result = await action();
      committed++;
      if (depth == 1) onCommit?.call();
      return result;
    } catch (_) {
      _db.restore(snapshot);
      rolledBack++;
      rethrow;
    } finally {
      depth--;
    }
  }
}

final class FakeBankAccountRepository implements BankAccountRepository {
  FakeBankAccountRepository(this._db);

  final FakeDatabase _db;

  @override
  Future<BankAccount> add(BankAccount account) async {
    final saved = account.withIdentity(_db.nextId());
    _db.accountRows[saved.accountId!] = saved;
    return saved;
  }

  @override
  Future<void> deleteById(int accountId) async =>
      _db.accountRows.remove(accountId);

  @override
  Future<List<BankAccount>> findAll() async =>
      _db.accountRows.values.toList(growable: false);

  @override
  Future<BankAccount?> findById(int accountId) => Future<BankAccount?>.value(
    _db.accountRows[accountId],
  );

  @override
  Future<void> update(BankAccount account) async {
    _db.accountRows[account.accountId!] = account;
  }
}

final class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository(this._db);

  final FakeDatabase _db;

  /// Bản ghi lại các trang đã hỏi, để test kiểm được rằng đường đọc thật sự đi
  /// theo trang chứ không nạp cả bảng.
  final List<int> requestedPageSizes = <int>[];

  Iterable<Transaction> get _all => _db.transactionRows.values;

  List<Transaction> _sorted(Iterable<Transaction> rows) {
    final list = rows.toList()
      ..sort((a, b) {
        final byDate = b.bookingDate.compareTo(a.bookingDate);
        return byDate != 0
            ? byDate
            : a.transactionId!.compareTo(b.transactionId!);
      });
    return list;
  }

  @override
  Future<List<int>> addAll(List<Transaction> transactions) async {
    final ids = <int>[];
    for (final transaction in transactions) {
      final id = _db.nextId();
      _db.transactionRows[id] = transaction.withIdentity(id);
      ids.add(id);
    }
    return ids;
  }

  @override
  Future<int> count(TransactionFilter filter) async =>
      _all.where((tx) => _matches(filter, tx)).length;

  @override
  Future<int> countByAccountId(int accountId) async =>
      _all.where((tx) => tx.accountId == accountId).length;

  @override
  Future<int> countAccountsWithTransactions() async =>
      _all.map((tx) => tx.accountId).toSet().length;

  /// Áp bộ lọc đúng như cổng lưu trữ thật.
  ///
  /// `excludeInternalTransfers` nói về một quan hệ mà bản thân [Transaction]
  /// không mang, nên nó phải được tra ở đây — bản giả bỏ qua nó sẽ để lọt đúng
  /// loại lỗi mà tiêu chí ấy sinh ra.
  bool _matches(TransactionFilter filter, Transaction tx) => filter.matches(
        tx,
        isReconciled: _db.pairRows.values.any(
          (pair) =>
              pair.isConfirmed &&
              pair.transactionIds.contains(tx.transactionId),
        ),
      );

  @override
  Future<Map<Fingerprint, int>> countByFingerprint({
    required int accountId,
    required Iterable<Fingerprint> fingerprints,
  }) async {
    final wanted = fingerprints.toSet();
    final counts = <Fingerprint, int>{};
    for (final tx in _all) {
      if (tx.accountId != accountId) continue;
      if (!wanted.contains(tx.fingerprint)) continue;
      counts[tx.fingerprint] = (counts[tx.fingerprint] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Future<int> countByImportFileRecordId(int recordId) async =>
      _all.where((tx) => tx.importFileRecordId == recordId).length;

  @override
  Future<int> countManuallyEditedByImportFileRecordId(int recordId) async =>
      _all
          .where((tx) => tx.importFileRecordId == recordId && tx.isManuallyEdited)
          .length;

  @override
  Future<int> deleteByAccountId(int accountId) async {
    final ids = _all
        .where((tx) => tx.accountId == accountId)
        .map((tx) => tx.transactionId!)
        .toList();
    ids.forEach(_db.transactionRows.remove);
    return ids.length;
  }

  @override
  Future<int> deleteByImportFileRecordId(int recordId) async {
    final ids = _all
        .where((tx) => tx.importFileRecordId == recordId)
        .map((tx) => tx.transactionId!)
        .toList();
    ids.forEach(_db.transactionRows.remove);
    return ids.length;
  }

  @override
  Future<void> deleteById(int transactionId) async =>
      _db.transactionRows.remove(transactionId);

  @override
  Future<Transaction?> findById(int transactionId) =>
      Future<Transaction?>.value(_db.transactionRows[transactionId]);

  @override
  Future<List<Transaction>> findByIds(Iterable<int> transactionIds) async =>
      <Transaction>[
        for (final id in transactionIds)
          if (_db.transactionRows[id] case final Transaction tx) tx,
      ];

  @override
  Future<List<Transaction>> findPage({
    required TransactionFilter filter,
    required int limit,
    required int offset,
  }) async {
    requestedPageSizes.add(limit);
    final matching = _sorted(_all.where((tx) => _matches(filter, tx)));
    if (offset >= matching.length) return const <Transaction>[];
    return matching.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<void> update(Transaction transaction) async {
    final id = transaction.transactionId!;
    if (!_db.transactionRows.containsKey(id)) {
      throw TransactionNotFoundError(id);
    }
    _db.transactionRows[id] = transaction;
  }

  @override
  Future<List<CurrencyUsage>> currencyUsage() async {
    final counts = <Currency, int>{};
    for (final tx in _all) {
      counts[tx.amount.currency] = (counts[tx.amount.currency] ?? 0) + 1;
    }
    final usage = counts.entries
        .map(
          (entry) => CurrencyUsage(
            currency: entry.key,
            transactionCount: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final byCount = b.transactionCount.compareTo(a.transactionCount);
        return byCount != 0 ? byCount : a.currency.compareTo(b.currency);
      });
    return usage;
  }

  Iterable<Transaction> _forAggregation({
    required Currency currency,
    DateRange? dateRange,
    required bool excludeInternalTransfers,
  }) {
    final excluded = excludeInternalTransfers
        ? <int>{
            for (final pair in _db.pairRows.values)
              if (pair.isConfirmed) ...pair.transactionIds,
          }
        : const <int>{};
    return _all.where(
      (tx) =>
          tx.amount.currency == currency &&
          (dateRange == null || dateRange.contains(tx.bookingDate)) &&
          !excluded.contains(tx.transactionId),
    );
  }

  @override
  Future<List<PeriodCashFlow>> aggregateByPeriod({
    required Currency currency,
    required CashFlowPeriod period,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  }) async {
    final buckets = <DateTime, List<Transaction>>{};
    for (final tx in _forAggregation(
      currency: currency,
      dateRange: dateRange,
      excludeInternalTransfers: excludeInternalTransfers,
    )) {
      buckets
          .putIfAbsent(_startOf(tx.bookingDate, period), () => <Transaction>[])
          .add(tx);
    }
    final keys = buckets.keys.toList()..sort();
    return <PeriodCashFlow>[
      for (final key in keys)
        PeriodCashFlow(
          periodStart: key,
          inflow: _sumWhere(buckets[key]!, (tx) => tx.isIncoming, currency),
          outflow: _sumWhere(buckets[key]!, (tx) => tx.isOutgoing, currency),
        ),
    ];
  }

  @override
  Future<List<AccountCashFlow>> aggregateByAccount({
    required Currency currency,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  }) async {
    final buckets = <int, List<Transaction>>{};
    for (final tx in _forAggregation(
      currency: currency,
      dateRange: dateRange,
      excludeInternalTransfers: excludeInternalTransfers,
    )) {
      buckets.putIfAbsent(tx.accountId, () => <Transaction>[]).add(tx);
    }
    final keys = buckets.keys.toList()..sort();
    return <AccountCashFlow>[
      for (final key in keys)
        AccountCashFlow(
          accountId: key,
          inflow: _sumWhere(buckets[key]!, (tx) => tx.isIncoming, currency),
          outflow: _sumWhere(buckets[key]!, (tx) => tx.isOutgoing, currency),
        ),
    ];
  }

  static DateTime _startOf(DateTime date, CashFlowPeriod period) =>
      switch (period) {
        CashFlowPeriod.day => DateTime.utc(date.year, date.month, date.day),
        CashFlowPeriod.month => DateTime.utc(date.year, date.month),
        CashFlowPeriod.year => DateTime.utc(date.year),
      };

  static Money _sumWhere(
    List<Transaction> rows,
    bool Function(Transaction tx) test,
    Currency currency,
  ) => rows.where(test).fold(
    Money.zero(currency),
    (total, tx) => total + tx.amount,
  );
}

final class FakeImportRepository implements ImportRepository {
  FakeImportRepository(this._db);

  final FakeDatabase _db;

  /// Trả session kèm đầy đủ bản ghi con, đúng hợp đồng ghi ở đầu interface.
  ImportSession _hydrate(ImportSession session) {
    final children = _db.fileRecordRows.values
        .where((record) => record.sessionId == session.sessionId)
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return session.withFileRecords(children);
  }

  @override
  Future<ImportSession> addSession(ImportSession session) async {
    final saved = session.withIdentity(_db.nextId());
    _db.sessionRows[saved.sessionId!] = saved;
    return saved;
  }

  @override
  Future<void> updateSession(ImportSession session) async {
    final id = session.sessionId!;
    if (!_db.sessionRows.containsKey(id)) {
      throw ImportSessionNotFoundError(id);
    }
    _db.sessionRows[id] = session;
  }

  @override
  Future<int> countSessions() async => _db.sessionRows.length;

  @override
  Future<List<ImportSession>> findUnfinishedSessions() async => _db
      .sessionRows
      .values
      .where((session) => !session.isFinished)
      .toList();

  @override
  Future<ImportSession?> findSessionById(int sessionId) async {
    final session = _db.sessionRows[sessionId];
    return session == null ? null : _hydrate(session);
  }

  @override
  Future<List<ImportSession>> findSessions({
    required int limit,
    required int offset,
  }) async {
    final sessions = _db.sessionRows.values.toList()
      ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions.skip(offset).take(limit).map(_hydrate).toList();
  }

  @override
  Future<int> deleteEmptySessions() async {
    final live = _db.fileRecordRows.values
        .map((record) => record.sessionId)
        .toSet();
    final empty = _db.sessionRows.keys
        .where((id) => !live.contains(id))
        .toList();
    empty.forEach(_db.sessionRows.remove);
    return empty.length;
  }

  @override
  Future<ImportFileRecord> addFileRecord(ImportFileRecord record) async {
    final saved = record.withIdentity(_db.nextId());
    _db.fileRecordRows[saved.recordId!] = saved;
    return saved;
  }

  @override
  Future<void> updateFileRecord(ImportFileRecord record) async {
    final id = record.recordId!;
    if (!_db.fileRecordRows.containsKey(id)) {
      throw ImportFileRecordNotFoundError(id);
    }
    _db.fileRecordRows[id] = record;
  }

  @override
  Future<ImportFileRecord?> findFileRecordById(int recordId) =>
      Future<ImportFileRecord?>.value(_db.fileRecordRows[recordId]);

  @override
  Future<List<ImportFileRecord>> findFileRecordsByAccountId(
    int accountId,
  ) async => _db.fileRecordRows.values
      .where((record) => record.accountId == accountId)
      .toList(growable: false);

  @override
  Future<void> deleteFileRecordById(int recordId) async {
    _db.fileRecordRows.remove(recordId);
    _db.errorRows.removeWhere((row) => row.recordId == recordId);
  }

  @override
  Future<void> addErrorRows(List<ImportErrorRow> rows) async {
    for (final row in rows) {
      _db.errorRows.add(
        ImportErrorRow(
          errorRowId: _db.nextId(),
          recordId: row.recordId,
          sourceLineNumber: row.sourceLineNumber,
          rawExcerpt: row.rawExcerpt,
          reason: row.reason,
        ),
      );
    }
  }

  @override
  Future<List<ImportErrorRow>> findErrorRows(int recordId) async {
    final rows = _db.errorRows
        .where((row) => row.recordId == recordId)
        .toList()
      ..sort((a, b) => a.sourceLineNumber.compareTo(b.sourceLineNumber));
    return rows;
  }
}

final class FakeReconciliationRepository implements ReconciliationRepository {
  FakeReconciliationRepository(this._db);

  final FakeDatabase _db;

  Iterable<ReconciliationPair> get _pairs => _db.pairRows.values;

  Set<int> get _pairedIds => <int>{
    for (final pair in _pairs) ...pair.transactionIds,
  };

  Set<int> _transactionIdsOfAccount(int accountId) => <int>{
    for (final tx in _db.transactionRows.values)
      if (tx.accountId == accountId) tx.transactionId!,
  };

  Set<int> _transactionIdsOfRecord(int recordId) => <int>{
    for (final tx in _db.transactionRows.values)
      if (tx.importFileRecordId == recordId) tx.transactionId!,
  };

  @override
  Future<void> addPairs(List<ReconciliationPair> pairs) async {
    for (final pair in pairs) {
      final id = _db.nextId();
      _db.pairRows[id] = pair.withIdentity(id);
    }
  }

  @override
  Future<RejectedMatch> addRejection(RejectedMatch rejection) async {
    final id = _db.nextId();
    final saved = rejection.withIdentity(id);
    _db.rejectionRows[id] = saved;
    return saved;
  }

  @override
  Future<int> countPairs({PairStatus? status}) async =>
      _pairs.where((pair) => status == null || pair.status == status).length;

  @override
  Future<int> countPairsByAccountId(int accountId) async {
    final ids = _transactionIdsOfAccount(accountId);
    return _pairs
        .where((pair) => pair.transactionIds.any(ids.contains))
        .length;
  }

  @override
  Future<int> countPairsByImportFileRecordId(int recordId) async {
    final ids = _transactionIdsOfRecord(recordId);
    return _pairs
        .where((pair) => pair.transactionIds.any(ids.contains))
        .length;
  }

  @override
  Future<int> countUnpairedTransactions() async {
    final paired = _pairedIds;
    return _db.transactionRows.values
        .where((tx) => !paired.contains(tx.transactionId))
        .length;
  }

  @override
  Future<void> deletePairById(int pairId) async => _db.pairRows.remove(pairId);

  @override
  Future<int> deletePairsByAccountId(int accountId) async =>
      _removePairsWhere(_transactionIdsOfAccount(accountId));

  @override
  Future<int> deletePairsByImportFileRecordId(int recordId) async =>
      _removePairsWhere(_transactionIdsOfRecord(recordId));

  @override
  Future<int> deletePairsInvolvingTransaction(int transactionId) async =>
      _removePairsWhere(<int>{transactionId});

  int _removePairsWhere(Set<int> transactionIds) {
    final doomed = _pairs
        .where((pair) => pair.transactionIds.any(transactionIds.contains))
        .map((pair) => pair.pairId!)
        .toList();
    doomed.forEach(_db.pairRows.remove);
    return doomed.length;
  }

  @override
  Future<bool> deleteRejectionById(int rejectedMatchId) async =>
      _db.rejectionRows.remove(rejectedMatchId) != null;

  @override
  Future<int> deleteRejectionsByAccountId(int accountId) async =>
      _removeRejectionsWhere(_transactionIdsOfAccount(accountId));

  @override
  Future<int> deleteRejectionsByImportFileRecordId(int recordId) async =>
      _removeRejectionsWhere(_transactionIdsOfRecord(recordId));

  @override
  Future<int> deleteRejectionsInvolvingTransaction(int transactionId) async =>
      _removeRejectionsWhere(<int>{transactionId});

  int _removeRejectionsWhere(Set<int> transactionIds) {
    final doomed = _db.rejectionRows.values
        .where(
          (rejection) =>
              transactionIds.contains(rejection.transactionAId) ||
              transactionIds.contains(rejection.transactionBId),
        )
        .map((rejection) => rejection.rejectedMatchId!)
        .toList();
    doomed.forEach(_db.rejectionRows.remove);
    return doomed.length;
  }

  @override
  Future<int> deleteSuggestedPairs() async {
    final doomed = _pairs
        .where((pair) => !pair.isConfirmed)
        .map((pair) => pair.pairId!)
        .toList();
    doomed.forEach(_db.pairRows.remove);
    return doomed.length;
  }

  @override
  Future<List<Transaction>> findMatchCandidates({
    required Transaction anchor,
    required MatchWindow window,
  }) async {
    // Đúng hợp đồng: chỉ dòng **chưa ghép**, đã thu hẹp bằng vị từ; việc loại
    // các cặp đã bị từ chối là của tầng Application.
    final paired = _pairedIds;
    return _db.transactionRows.values
        .where(
          (candidate) =>
              !paired.contains(candidate.transactionId) &&
              MatchPredicate.canPair(anchor, candidate, window),
        )
        .toList(growable: false);
  }

  @override
  Future<ReconciliationPair?> findPairById(int pairId) =>
      Future<ReconciliationPair?>.value(_db.pairRows[pairId]);

  @override
  Future<ReconciliationPair?> findPairInvolving(int transactionId) async {
    for (final pair in _pairs) {
      if (pair.involves(transactionId)) return pair;
    }
    return null;
  }

  @override
  Future<Set<int>> findPairedTransactionIds(
    Iterable<int> transactionIds, {
    PairStatus? status,
  }) async {
    final wanted = transactionIds.toSet();
    return <int>{
      for (final pair in _pairs)
        if (status == null || pair.status == status)
          for (final id in pair.transactionIds)
            if (wanted.contains(id)) id,
    };
  }

  @override
  Future<List<ReconciliationPair>> findPairs({
    PairStatus? status,
    required int limit,
    required int offset,
  }) async {
    final rows =
        _pairs.where((pair) => status == null || pair.status == status).toList()
          ..sort((a, b) => a.pairId!.compareTo(b.pairId!));
    return rows.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<RejectedMatch>> findRejections({
    required int limit,
    required int offset,
  }) async {
    final rows = _db.rejectionRows.values.toList()
      ..sort((a, b) => b.rejectedMatchId!.compareTo(a.rejectedMatchId!));
    return rows.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<List<RejectedMatch>> findRejectionsForTransaction(
    int transactionId,
  ) async => _db.rejectionRows.values
      .where((rejection) => rejection.involves(transactionId))
      .toList(growable: false);

  @override
  Future<List<Transaction>> findUnpairedTransactions({
    required int limit,
    required int offset,
  }) async {
    final paired = _pairedIds;
    final rows =
        _db.transactionRows.values
            .where((tx) => !paired.contains(tx.transactionId))
            .toList()
          ..sort((a, b) => a.transactionId!.compareTo(b.transactionId!));
    return rows.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<void> updatePair(ReconciliationPair pair) async {
    _db.pairRows[pair.pairId!] = pair;
  }
}

final class FakeAppSettingsRepository implements AppSettingsRepository {
  /// Trạng thái hiện tại; test đặt thẳng vào đây để dựng tiền điều kiện.
  AppSettings current = AppSettings.initial;

  int saveCount = 0;

  @override
  Future<AppSettings> load() async => current;

  @override
  Future<void> save(AppSettings settings) async {
    saveCount++;
    current = settings;
  }
}
