import '../../domain/entities/transaction.dart';
import '../../domain/errors/transaction_errors.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../domain/value_objects/currency.dart';
import '../../domain/value_objects/date_range.dart';
import '../../domain/value_objects/fingerprint.dart';
import '../../domain/value_objects/money.dart';
import '../../domain/value_objects/pair_status.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../database/sql_codec.dart';
import '../database/sql_query.dart';
import 'mappers/transaction_mapper.dart';

/// Một mệnh đề `WHERE` đã dựng xong cùng các tham số của nó.
///
/// Là kiểu riêng chứ không phải một `record` trần: mệnh đề và tham số của nó chỉ
/// đúng khi đi cùng nhau, và ghép nhầm thứ tự tham số là loại lỗi không có thông
/// báo nào cả — truy vấn vẫn chạy, chỉ trả về tập kết quả khác.
final class _Conditions {
  _Conditions();

  final List<String> _clauses = <String>[];
  final List<Object?> arguments = <Object?>[];

  void add(String clause, List<Object?> args) {
    _clauses.add(clause);
    arguments.addAll(args);
  }

  bool get isEmpty => _clauses.isEmpty;

  /// `null` khi không có tiêu chí nào — đúng thứ `sqflite` chờ đợi cho một truy
  /// vấn không điều kiện.
  String? get whereOrNull => isEmpty ? null : _clauses.join(' AND ');

  String get whereOrTrue => isEmpty ? '1 = 1' : _clauses.join(' AND ');
}

/// Hiện thực SQLite của [TransactionRepository].
///
/// Mọi đường đọc đều **truy vấn thẳng và theo trang**, không nạp aggregate: đó
/// là điều kiện để một danh sách hàng trăm nghìn dòng cuộn được (UC-04), và cũng
/// là lý do `Transaction` được tách khỏi `BankAccount` ngay từ Domain.
final class SqliteTransactionRepository implements TransactionRepository {
  const SqliteTransactionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<List<Transaction>> findPage({
    required TransactionFilter filter,
    required int limit,
    required int offset,
  }) async {
    final conditions = _conditionsOf(filter);
    final rows = await _db.executor.query(
      LedgerSchema.transaction,
      where: conditions.whereOrNull,
      whereArgs: conditions.isEmpty ? null : conditions.arguments,
      // Ngày gần nhất trước, phá hoà bằng định danh: thiếu tiêu chí phá hoà thì
      // hai dòng cùng ngày có thể đổi chỗ giữa hai lần hỏi, và một dòng sẽ vừa
      // hiện hai lần vừa biến mất khi người dùng cuộn qua ranh giới trang.
      orderBy: 'booking_date DESC, transaction_id',
      limit: limit,
      offset: offset,
    );
    return rows.map(TransactionMapper.fromRow).toList(growable: false);
  }

  @override
  Future<int> count(TransactionFilter filter) {
    final conditions = _conditionsOf(filter);
    return _db.executor.countRows(
      'SELECT COUNT(*) FROM ${LedgerSchema.transaction} '
      'WHERE ${conditions.whereOrTrue}',
      conditions.arguments,
    );
  }

  @override
  Future<Transaction?> findById(int transactionId) async {
    final rows = await _db.executor.query(
      LedgerSchema.transaction,
      where: 'transaction_id = ?',
      whereArgs: <Object?>[transactionId],
      limit: 1,
    );
    return rows.isEmpty ? null : TransactionMapper.fromRow(rows.first);
  }

  /// Trả về theo đúng thứ tự [transactionIds] đã hỏi, và bỏ qua định danh không
  /// còn tồn tại — màn hình đối soát dựng hai vế của một cặp theo thứ tự nó biết
  /// (UC-09), không theo thứ tự cơ sở dữ liệu trả ra.
  @override
  Future<List<Transaction>> findByIds(Iterable<int> transactionIds) async {
    final ids = transactionIds.toList(growable: false);
    if (ids.isEmpty) return const <Transaction>[];

    final found = <int, Transaction>{};
    for (final chunk in SqlQuery.chunked(ids)) {
      final rows = await _db.executor.query(
        LedgerSchema.transaction,
        where: 'transaction_id IN (${SqlQuery.placeholders(chunk.length)})',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final transaction = TransactionMapper.fromRow(row);
        found[transaction.transactionId!] = transaction;
      }
    }
    return <Transaction>[
      for (final id in ids)
        if (found[id] case final Transaction transaction) transaction,
    ];
  }

  /// Ghi một lô của giai đoạn ghi trong đúng một lần đi xuống cơ sở dữ liệu, và
  /// trả về định danh vừa cấp **theo đúng thứ tự đã gửi** (UC-02).
  @override
  Future<List<int>> addAll(List<Transaction> transactions) async {
    if (transactions.isEmpty) return const <int>[];
    final batch = _db.executor.batch();
    for (final transaction in transactions) {
      batch.insert(
        LedgerSchema.transaction,
        TransactionMapper.toRow(transaction),
      );
    }
    final results = await batch.commit();
    return results.cast<int>();
  }

  @override
  Future<void> update(Transaction transaction) async {
    final changed = await _db.executor.update(
      LedgerSchema.transaction,
      TransactionMapper.toRow(transaction),
      where: 'transaction_id = ?',
      whereArgs: <Object?>[transaction.transactionId],
    );
    if (changed == 0) throw TransactionNotFoundError(transaction.transactionId!);
  }

  @override
  Future<void> deleteById(int transactionId) async {
    await _db.executor.delete(
      LedgerSchema.transaction,
      where: 'transaction_id = ?',
      whereArgs: <Object?>[transactionId],
    );
  }

  /// Đếm theo fingerprint, gom nhóm bằng SQL.
  ///
  /// Chống trùng so theo **số lượng** chứ không theo sự tồn tại, nên câu trả lời
  /// phải là một phép đếm: đã có n dòng khớp, file mang tới m dòng, chỉ ghi thêm
  /// phần chênh lệch (UC-02).
  ///
  /// Một lô phân tích mang tới nhiều fingerprint hơn trần tham số của SQLite là
  /// chuyện bình thường, nên danh sách được chia lô trước khi vào mệnh đề `IN`.
  @override
  Future<Map<Fingerprint, int>> countByFingerprint({
    required int accountId,
    required Iterable<Fingerprint> fingerprints,
  }) async {
    final values = <String>{
      for (final fingerprint in fingerprints) fingerprint.value,
    };
    if (values.isEmpty) return const <Fingerprint, int>{};

    final counts = <Fingerprint, int>{};
    for (final chunk in SqlQuery.chunked(values)) {
      final rows = await _db.executor.rawQuery(
        'SELECT fingerprint, COUNT(*) AS total '
        'FROM ${LedgerSchema.transaction} '
        'WHERE account_id = ? '
        'AND fingerprint IN (${SqlQuery.placeholders(chunk.length)}) '
        'GROUP BY fingerprint',
        <Object?>[accountId, ...chunk],
      );
      for (final row in rows) {
        counts[Fingerprint.fromStored(row['fingerprint'] as String)] =
            row['total'] as int;
      }
    }
    return counts;
  }

  @override
  Future<int> countByImportFileRecordId(int recordId) => _db.executor.countRows(
    'SELECT COUNT(*) FROM ${LedgerSchema.transaction} '
    'WHERE import_file_record_id = ?',
    <Object?>[recordId],
  );

  @override
  Future<int> countByAccountId(int accountId) => _db.executor.countRows(
    'SELECT COUNT(*) FROM ${LedgerSchema.transaction} WHERE account_id = ?',
    <Object?>[accountId],
  );

  @override
  Future<int> deleteByImportFileRecordId(int recordId) => _db.executor.delete(
    LedgerSchema.transaction,
    where: 'import_file_record_id = ?',
    whereArgs: <Object?>[recordId],
  );

  @override
  Future<int> deleteByAccountId(int accountId) => _db.executor.delete(
    LedgerSchema.transaction,
    where: 'account_id = ?',
    whereArgs: <Object?>[accountId],
  );

  @override
  Future<int> countManuallyEditedByImportFileRecordId(int recordId) =>
      _db.executor.countRows(
        'SELECT COUNT(*) FROM ${LedgerSchema.transaction} '
        'WHERE import_file_record_id = ? AND is_manually_edited = 1',
        <Object?>[recordId],
      );

  /// Nhiều giao dịch nhất trước, mã loại tiền phá hoà — thứ tự phải lặp lại được
  /// vì nó quyết định tab mặc định của màn hình thống kê (UC-10) và giá trị mặc
  /// định của bộ lọc số tiền (UC-07).
  @override
  Future<List<CurrencyUsage>> currencyUsage() async {
    final rows = await _db.executor.rawQuery(
      'SELECT currency, COUNT(*) AS total FROM ${LedgerSchema.transaction} '
      'GROUP BY currency ORDER BY total DESC, currency ASC',
    );
    return <CurrencyUsage>[
      for (final row in rows)
        CurrencyUsage(
          currency: Currency.parse(row['currency'] as String),
          transactionCount: row['total'] as int,
        ),
    ];
  }

  @override
  Future<List<PeriodCashFlow>> aggregateByPeriod({
    required Currency currency,
    required CashFlowPeriod period,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  }) async {
    final rows = await _aggregate(
      groupExpression: _periodExpression(period),
      currency: currency,
      dateRange: dateRange,
      excludeInternalTransfers: excludeInternalTransfers,
    );
    return <PeriodCashFlow>[
      for (final row in rows)
        PeriodCashFlow(
          periodStart: _periodStartOf(row['bucket'] as String, period),
          inflow: Money(row['inflow'] as int, currency),
          outflow: Money(row['outflow'] as int, currency),
        ),
    ];
  }

  @override
  Future<List<AccountCashFlow>> aggregateByAccount({
    required Currency currency,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  }) async {
    final rows = await _aggregate(
      groupExpression: 'account_id',
      currency: currency,
      dateRange: dateRange,
      excludeInternalTransfers: excludeInternalTransfers,
    );
    return <AccountCashFlow>[
      for (final row in rows)
        AccountCashFlow(
          accountId: row['bucket'] as int,
          inflow: Money(row['inflow'] as int, currency),
          outflow: Money(row['outflow'] as int, currency),
        ),
    ];
  }

  /// Thân chung của hai phép gom nhóm ở UC-10; chỉ khác nhau ở biểu thức nhóm.
  ///
  /// Tổng được tính bằng SQL chứ không bằng cách nạp dòng rồi cộng trong Dart:
  /// thống kê chạy trên toàn bộ dữ liệu, và mọi số liệu ở đây luôn được **tính**
  /// tại thời điểm hiển thị chứ không bao giờ lưu sẵn
  /// (Rule – Statistics Are Always Derived, Never Stored).
  ///
  /// Tiền ra giữ nguyên dấu âm để `net` chỉ là một phép cộng, đúng như
  /// `CashFlowBucket` định nghĩa.
  Future<List<Map<String, Object?>>> _aggregate({
    required String groupExpression,
    required Currency currency,
    required DateRange? dateRange,
    required bool excludeInternalTransfers,
  }) {
    final conditions = _Conditions()
      ..add('currency = ?', <Object?>[currency.code]);
    if (dateRange != null) {
      conditions.add('booking_date BETWEEN ? AND ?', <Object?>[
        SqlCodec.bookingDate(dateRange.from),
        SqlCodec.bookingDate(dateRange.to),
      ]);
    }
    if (excludeInternalTransfers) {
      // Chỉ cặp **đã xác nhận** mới bị trừ: gợi ý chưa có hiệu lực nghiệp vụ nào
      // (Rule – Suggested Is Not Confirmed).
      conditions.add(
        'NOT EXISTS (SELECT 1 FROM ${LedgerSchema.reconciliationPair} pair '
        'WHERE pair.status = ? AND ('
        'pair.outgoing_transaction_id = '
        '${LedgerSchema.transaction}.transaction_id '
        'OR pair.incoming_transaction_id = '
        '${LedgerSchema.transaction}.transaction_id))',
        <Object?>[PairStatus.confirmed.name],
      );
    }

    return _db.executor.rawQuery(
      'SELECT $groupExpression AS bucket, '
      'SUM(CASE WHEN amount_minor > 0 THEN amount_minor ELSE 0 END) AS inflow, '
      'SUM(CASE WHEN amount_minor < 0 THEN amount_minor ELSE 0 END) AS outflow '
      'FROM ${LedgerSchema.transaction} '
      'WHERE ${conditions.whereOrTrue} '
      'GROUP BY bucket ORDER BY bucket',
      conditions.arguments,
    );
  }

  /// Gom nhóm theo mốc thời gian là phép cắt chuỗi, không phải phép đổi múi giờ.
  ///
  /// Đó là điều `booking_date` được lưu dạng `YYYY-MM-DD` mua về: tháng của một
  /// giao dịch không bao giờ phụ thuộc vào múi giờ của thiết bị đang xem nó.
  static String _periodExpression(CashFlowPeriod period) => switch (period) {
    CashFlowPeriod.day => 'booking_date',
    CashFlowPeriod.month => 'substr(booking_date, 1, 7)',
    CashFlowPeriod.year => 'substr(booking_date, 1, 4)',
  };

  static DateTime _periodStartOf(String bucket, CashFlowPeriod period) =>
      switch (period) {
        CashFlowPeriod.day => SqlCodec.parseBookingDate(bucket),
        CashFlowPeriod.month => DateTime.utc(
          int.parse(bucket.substring(0, 4)),
          int.parse(bucket.substring(5, 7)),
        ),
        CashFlowPeriod.year => DateTime.utc(int.parse(bucket)),
      };

  /// Dịch [TransactionFilter] thành SQL — **một lần**, dùng chung cho danh sách,
  /// phép đếm và file xuất.
  ///
  /// Đây chính là thứ việc gom tiêu chí vào một object mua về: ba bản chép tay
  /// của cùng điều kiện sẽ lệch nhau, và người dùng sẽ thấy danh sách nói một
  /// con số còn file xuất ra nói con số khác (UC-11).
  static _Conditions _conditionsOf(TransactionFilter filter) {
    final conditions = _Conditions();

    final keyword = filter.keyword;
    if (keyword != null) {
      // `searchText` đã được chuẩn hoá một lần lúc nhập và từ khoá đi qua đúng
      // hàm chuẩn hoá đó, nên đây là so hai chuỗi đã cùng dạng — không có
      // `LOWER()` hay phép bỏ dấu nào chạy trên từng dòng lúc truy vấn (UC-06).
      conditions.add(
        "search_text LIKE ? ESCAPE '${SqlQuery.likeEscape}'",
        <Object?>['%${SqlQuery.escapeLike(keyword.value)}%'],
      );
    }

    final accountId = filter.accountId;
    if (accountId != null) {
      conditions.add('account_id = ?', <Object?>[accountId]);
    }

    final dateRange = filter.dateRange;
    if (dateRange != null) {
      conditions.add('booking_date BETWEEN ? AND ?', <Object?>[
        SqlCodec.bookingDate(dateRange.from),
        SqlCodec.bookingDate(dateRange.to),
      ]);
    }

    final amountRange = filter.amountRange;
    if (amountRange != null) {
      // Hai cận có dấu, đúng như số tiền mà nó lọc: dấu đã mang chiều tiền nên
      // không cần thêm tiêu chí "chiều" nào (Rule – The Sign Carries the
      // Direction).
      conditions.add('amount_minor BETWEEN ? AND ?', <Object?>[
        amountRange.min.minorUnits,
        amountRange.max.minorUnits,
      ]);
    }

    final currency = filter.currency;
    if (currency != null) {
      conditions.add('currency = ?', <Object?>[currency.code]);
    }

    return conditions;
  }
}
