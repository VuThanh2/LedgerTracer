import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' hide Transaction;

import 'package:ledger_tracer/application/export/export_dataset/export_dataset_dto.dart';
import 'package:ledger_tracer/application/import/contracts/statement_parser.dart';
import 'package:ledger_tracer/application/settings/backup_restore/backup_restore_dto.dart';
import 'package:ledger_tracer/application/settings/contracts/app_data_store.dart';
import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/domain/entities/import_error_row.dart';
import 'package:ledger_tracer/domain/entities/import_file_record.dart';
import 'package:ledger_tracer/domain/entities/import_session.dart';
import 'package:ledger_tracer/domain/entities/reconciliation_pair.dart';
import 'package:ledger_tracer/domain/entities/rejected_match.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/amount_range.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/pair_status.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';
import 'package:ledger_tracer/infrastructure/backup/backup_codec.dart';
import 'package:ledger_tracer/infrastructure/database/app_database.dart';
import 'package:ledger_tracer/infrastructure/database/sqlite_app_data_store.dart';
import 'package:ledger_tracer/infrastructure/export/csv_exporter.dart';
import 'package:ledger_tracer/infrastructure/export/excel_exporter.dart';
import 'package:ledger_tracer/infrastructure/export/spreadsheet_exporter.dart';
import 'package:ledger_tracer/infrastructure/parsers/csv/csv_parser.dart';
import 'package:ledger_tracer/infrastructure/parsers/excel/excel_parser.dart';
import 'package:ledger_tracer/infrastructure/parsers/format_detector.dart';
import 'package:ledger_tracer/infrastructure/parsers/json/json_parser.dart';
import 'package:ledger_tracer/infrastructure/parsers/mt940/mt940_parser.dart';
import 'package:ledger_tracer/infrastructure/platform/file_saver_service.dart';
import 'package:ledger_tracer/infrastructure/repositories/sqlite_app_settings_repository.dart';
import 'package:ledger_tracer/infrastructure/repositories/sqlite_bank_account_repository.dart';
import 'package:ledger_tracer/infrastructure/repositories/sqlite_import_repository.dart';
import 'package:ledger_tracer/infrastructure/repositories/sqlite_reconciliation_repository.dart';
import 'package:ledger_tracer/infrastructure/repositories/sqlite_transaction_repository.dart';
import 'package:ledger_tracer/infrastructure/security/pbkdf2_pin_hasher.dart';

Uint8List bytesOf(String text) => Uint8List.fromList(utf8.encode(text));

List<ParsedRowLike> rowsOf(Iterable<ParseLineResult> results) => <ParsedRowLike>[
  for (final result in results)
    if (result case ParsedLine(:final row))
      ParsedRowLike(row.bookingDate, row.amount, row.description, row.sourceLineNumber),
];

int errorsOf(Iterable<ParseLineResult> results) =>
    results.whereType<RejectedLine>().length;

final class ParsedRowLike {
  ParsedRowLike(this.date, this.amount, this.description, this.line);
  final DateTime date;
  final Money amount;
  final String description;
  final int? line;
  @override
  String toString() => '$date | $amount | $description | $line';
}

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late SqliteBankAccountRepository accounts;
  late SqliteTransactionRepository transactions;
  late SqliteImportRepository imports;
  late SqliteReconciliationRepository reconciliation;
  late SqliteAppSettingsRepository settings;

  final now = DateTime.utc(2025, 8, 28, 10);

  Future<int> seedRecord(int accountId, {int order = 0}) async {
    final session = await imports.addSession(ImportSession.started(now));
    final record = await imports.addFileRecord(
      ImportFileRecord.started(
        sessionId: session.sessionId!,
        accountId: accountId,
        fileName: 'f$order.csv',
        detectedFormat: StatementFormat.csv,
        orderIndex: order,
      ),
    );
    return record.recordId!;
  }

  Transaction tx({
    required int accountId,
    required int recordId,
    required DateTime date,
    required int amount,
    Currency currency = Currency.vnd,
    String description = 'Noi dung',
    String? counterparty,
  }) => Transaction.imported(
    accountId: accountId,
    bookingDate: date,
    amount: Money(amount, currency),
    counterpartyName: counterparty,
    description: description,
    importFileRecordId: recordId,
    importedAt: now,
  );

  setUp(() async {
    db = await AppDatabase.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    accounts = SqliteBankAccountRepository(db);
    transactions = SqliteTransactionRepository(db);
    imports = SqliteImportRepository(db);
    reconciliation = SqliteReconciliationRepository(db);
    settings = SqliteAppSettingsRepository(db);
  });

  tearDown(() => db.close());

  group('bank account repository', () {
    test('adds, reads back and updates', () async {
      final saved = await accounts.add(
        BankAccount.create(displayName: 'Vietinbank', createdAt: now),
      );
      expect(saved.accountId, isNotNull);

      await accounts.update(saved.withAccountNumber('0011 0004 1234'));
      final reloaded = await accounts.findById(saved.accountId!);
      expect(reloaded!.accountNumber, '001100041234');
      expect(reloaded.createdAt, now);
      expect(reloaded.matchesAccountNumber('0011.0004-1234'), isTrue);
      expect(reloaded.matchesAccountNumber('9999'), isFalse);

      final all = await accounts.findAll();
      expect(all, hasLength(1));
    });
  });

  group('transaction repository', () {
    test('paging, filtering and dedup counting', () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final record = await seedRecord(a.accountId!);

      final ids = await transactions.addAll(<Transaction>[
        tx(
          accountId: a.accountId!,
          recordId: record,
          date: DateTime.utc(2025, 1, 10),
          amount: 1000000,
          description: 'NGUYEN VAN A chuyen tien',
        ),
        tx(
          accountId: a.accountId!,
          recordId: record,
          date: DateTime.utc(2025, 2, 10),
          amount: -250000,
          description: 'Thanh toan dien',
        ),
        tx(
          accountId: a.accountId!,
          recordId: record,
          date: DateTime.utc(2025, 2, 10),
          amount: 4200,
          currency: Currency.usd,
          description: 'USD inbound',
        ),
      ]);
      expect(ids, hasLength(3));
      expect(ids, ids.toList()..sort());

      final page = await transactions.findPage(
        filter: TransactionFilter.none,
        limit: 2,
        offset: 0,
      );
      // Ngày gần nhất trước.
      expect(page.first.bookingDate, DateTime.utc(2025, 2, 10));
      expect(await transactions.count(TransactionFilter.none), 3);

      // Tìm kiếm không dấu, không phân biệt hoa thường.
      final keyword = TransactionFilter(keyword: SearchText.query('nguyễn VĂN a'));
      expect(await transactions.count(keyword), 1);

      // Ký tự đại diện của LIKE phải bị vô hiệu hoá.
      expect(
        await transactions.count(
          TransactionFilter(keyword: SearchText.query('%')),
        ),
        0,
      );

      // Lọc theo khoảng ngày.
      expect(
        await transactions.count(
          TransactionFilter(
            dateRange: DateRange(
              from: DateTime.utc(2025, 2, 1),
              to: DateTime.utc(2025, 2, 28),
            ),
          ),
        ),
        2,
      );

      // Lọc theo khoảng số tiền — kéo theo loại tiền.
      expect(
        await transactions.count(
          TransactionFilter(
            amountRange: AmountRange(
              min: const Money(0, Currency.vnd),
              max: const Money(2000000, Currency.vnd),
            ),
          ),
        ),
        1,
      );

      // Chống trùng đếm theo số lượng.
      final duplicate = tx(
        accountId: a.accountId!,
        recordId: record,
        date: DateTime.utc(2025, 1, 10),
        amount: 1000000,
        description: 'NGUYEN VAN A chuyen tien',
      );
      final counts = await transactions.countByFingerprint(
        accountId: a.accountId!,
        fingerprints: <dynamic>[duplicate.fingerprint].cast(),
      );
      expect(counts[duplicate.fingerprint], 1);

      // Loại tiền phổ biến nhất đứng trước.
      final usage = await transactions.currencyUsage();
      expect(usage.first.currency, Currency.vnd);
      expect(usage.first.transactionCount, 2);
      expect(usage.last.currency, Currency.usd);

      expect(await transactions.countByImportFileRecordId(record), 3);
      expect(await transactions.countByAccountId(a.accountId!), 3);
      expect(await transactions.findByIds(<int>[ids[1], ids[0]]), hasLength(2));
    });

    test('aggregates cash flow by period and account', () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final b = await accounts.add(
        BankAccount.create(displayName: 'B', createdAt: now),
      );
      final recordA = await seedRecord(a.accountId!);
      final recordB = await seedRecord(b.accountId!, order: 1);

      final ids = await transactions.addAll(<Transaction>[
        tx(
          accountId: a.accountId!,
          recordId: recordA,
          date: DateTime.utc(2025, 1, 5),
          amount: 500000,
        ),
        tx(
          accountId: a.accountId!,
          recordId: recordA,
          date: DateTime.utc(2025, 1, 20),
          amount: -200000,
        ),
        tx(
          accountId: b.accountId!,
          recordId: recordB,
          date: DateTime.utc(2025, 2, 3),
          amount: 200000,
        ),
      ]);

      final monthly = await transactions.aggregateByPeriod(
        currency: Currency.vnd,
        period: CashFlowPeriod.month,
      );
      expect(monthly, hasLength(2));
      expect(monthly.first.periodStart, DateTime.utc(2025, 1));
      expect(monthly.first.inflow, const Money(500000, Currency.vnd));
      expect(monthly.first.outflow, const Money(-200000, Currency.vnd));
      expect(monthly.first.net, const Money(300000, Currency.vnd));

      // Cặp đã xác nhận bị loại khỏi dòng tiền với bên ngoài.
      await reconciliation.addPairs(<ReconciliationPair>[
        ReconciliationPair.suggested(
          outgoingTransactionId: ids[1],
          incomingTransactionId: ids[2],
          createdAt: now,
        ),
      ]);
      final pair = (await reconciliation.findPairs(limit: 10, offset: 0)).single;
      await reconciliation.updatePair(pair.confirm(now));

      final excluded = await transactions.aggregateByPeriod(
        currency: Currency.vnd,
        period: CashFlowPeriod.month,
      );
      expect(excluded, hasLength(1));
      expect(excluded.single.inflow, const Money(500000, Currency.vnd));

      final raw = await transactions.aggregateByPeriod(
        currency: Currency.vnd,
        period: CashFlowPeriod.month,
        excludeInternalTransfers: false,
      );
      expect(raw, hasLength(2));

      final byAccount = await transactions.aggregateByAccount(
        currency: Currency.vnd,
        excludeInternalTransfers: false,
      );
      expect(byAccount.map((bucket) => bucket.accountId), <int>[
        a.accountId!,
        b.accountId!,
      ]);
    });
  });

  group('import repository', () {
    test('hydrates sessions with their file records in pick order', () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final session = await imports.addSession(ImportSession.started(now));
      for (var index = 2; index >= 0; index--) {
        await imports.addFileRecord(
          ImportFileRecord.started(
            sessionId: session.sessionId!,
            accountId: a.accountId!,
            fileName: 'file$index.csv',
            detectedFormat: StatementFormat.csv,
            orderIndex: index,
          ),
        );
      }

      final loaded = await imports.findSessionById(session.sessionId!);
      expect(loaded!.fileRecords.map((r) => r.orderIndex), <int>[0, 1, 2]);

      final page = await imports.findSessions(limit: 10, offset: 0);
      expect(page.single.fileRecords, hasLength(3));
      expect(await imports.countSessions(), 1);
      expect(await imports.findUnfinishedSessions(), hasLength(1));

      await imports.updateSession(loaded.complete(now));
      expect(await imports.findUnfinishedSessions(), isEmpty);

      final record = loaded.fileRecords.first;
      await imports.addErrorRows(<ImportErrorRow>[
        ImportErrorRow.from(
          recordId: record.recordId!,
          sourceLineNumber: 9,
          rawLine: 'bad;line',
          reason: 'khong doc duoc',
        ),
        ImportErrorRow.from(
          recordId: record.recordId!,
          sourceLineNumber: 3,
          rawLine: 'other',
          reason: 'thieu ngay',
        ),
      ]);
      final errors = await imports.findErrorRows(record.recordId!);
      expect(errors.map((row) => row.sourceLineNumber), <int>[3, 9]);

      await imports.updateFileRecord(
        record.accumulate(importedCount: 5, duplicateSkippedCount: 2),
      );
      expect(
        (await imports.findFileRecordById(record.recordId!))!.importedCount,
        5,
      );

      expect(await imports.deleteEmptySessions(), 0);
      for (final child in loaded.fileRecords) {
        await imports.deleteFileRecordById(child.recordId!);
      }
      expect(await imports.deleteEmptySessions(), 1);
    });
  });

  group('reconciliation repository', () {
    test('candidates, pairs and rejections', () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final b = await accounts.add(
        BankAccount.create(displayName: 'B', createdAt: now),
      );
      final recordA = await seedRecord(a.accountId!);
      final recordB = await seedRecord(b.accountId!, order: 1);

      final ids = await transactions.addAll(<Transaction>[
        tx(
          accountId: a.accountId!,
          recordId: recordA,
          date: DateTime.utc(2025, 3, 10),
          amount: -750000,
          description: 'chuyen noi bo',
        ),
        tx(
          accountId: b.accountId!,
          recordId: recordB,
          date: DateTime.utc(2025, 3, 12),
          amount: 750000,
          description: 'nhan noi bo',
        ),
        tx(
          accountId: b.accountId!,
          recordId: recordB,
          date: DateTime.utc(2025, 3, 30),
          amount: 750000,
          description: 'ngoai cua so',
        ),
        tx(
          accountId: b.accountId!,
          recordId: recordB,
          date: DateTime.utc(2025, 3, 12),
          amount: 750000,
          currency: Currency.usd,
          description: 'khac loai tien',
        ),
      ]);

      final anchor = (await transactions.findById(ids[0]))!;
      final candidates = await reconciliation.findMatchCandidates(
        anchor: anchor,
        window: MatchWindow.standard,
      );
      expect(candidates.map((c) => c.transactionId), <int>[ids[1]]);

      expect(await reconciliation.countUnpairedTransactions(), 4);
      await reconciliation.addPairs(<ReconciliationPair>[
        ReconciliationPair.suggested(
          outgoingTransactionId: ids[0],
          incomingTransactionId: ids[1],
          createdAt: now,
        ),
      ]);
      expect(await reconciliation.countUnpairedTransactions(), 2);
      expect(
        await reconciliation.findMatchCandidates(
          anchor: anchor,
          window: MatchWindow.standard,
        ),
        isEmpty,
      );

      final pair = (await reconciliation.findPairs(limit: 5, offset: 0)).single;
      expect(await reconciliation.findPairInvolving(ids[1]), isNotNull);
      expect(
        await reconciliation.findPairedTransactionIds(<int>[ids[0], ids[2]]),
        <int>{ids[0]},
      );
      expect(await reconciliation.countPairsByAccountId(a.accountId!), 1);
      expect(await reconciliation.countPairsByImportFileRecordId(recordB), 1);

      // Chỉ cặp chưa xác nhận bị xoá khi chạy lại.
      await reconciliation.updatePair(pair.confirm(now));
      expect(await reconciliation.deleteSuggestedPairs(), 0);
      expect(await reconciliation.countPairs(status: PairStatus.confirmed), 1);

      final rejection = await reconciliation.addRejection(
        RejectedMatch.between(
          transactionAId: ids[2],
          transactionBId: ids[0],
          rejectedAt: now,
        ),
      );
      expect(rejection.transactionAId, lessThan(rejection.transactionBId));
      expect(
        await reconciliation.findRejectionsForTransaction(ids[2]),
        hasLength(1),
      );
      // Từ chối lại cùng một cặp thì ghi đè, không nổ vì ràng buộc duy nhất.
      await reconciliation.addRejection(
        RejectedMatch.between(
          transactionAId: ids[0],
          transactionBId: ids[2],
          rejectedAt: now,
        ),
      );
      expect(await reconciliation.findRejections(limit: 10, offset: 0),
          hasLength(1));

      expect(await reconciliation.deletePairsByAccountId(a.accountId!), 1);
      expect(await reconciliation.deleteRejectionsByAccountId(a.accountId!), 1);
    });

    test('asks about a full export page without blowing the parameter limit',
        () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final b = await accounts.add(
        BankAccount.create(displayName: 'B', createdAt: now),
      );
      final recordA = await seedRecord(a.accountId!);
      final recordB = await seedRecord(b.accountId!, order: 1);

      // Đúng kích thước trang mà luồng xuất file dùng (1000 dòng).
      const pageSize = 1000;
      final ids = await transactions.addAll(<Transaction>[
        for (var index = 0; index < pageSize ~/ 2; index++) ...<Transaction>[
          tx(
            accountId: a.accountId!,
            recordId: recordA,
            date: DateTime.utc(2025, 1, 1),
            amount: -(index + 1),
            description: 'ra $index',
          ),
          tx(
            accountId: b.accountId!,
            recordId: recordB,
            date: DateTime.utc(2025, 1, 1),
            amount: index + 1,
            description: 'vao $index',
          ),
        ],
      ]);
      expect(ids, hasLength(pageSize));

      await reconciliation.addPairs(<ReconciliationPair>[
        for (var index = 0; index < pageSize; index += 2)
          ReconciliationPair.suggested(
            outgoingTransactionId: ids[index],
            incomingTransactionId: ids[index + 1],
            createdAt: now,
          ),
      ]);

      final paired = await reconciliation.findPairedTransactionIds(ids);
      expect(paired, hasLength(pageSize));
      expect(
        await reconciliation.findPairedTransactionIds(
          ids,
          status: PairStatus.confirmed,
        ),
        isEmpty,
      );
    });
  });

  group('unit of work', () {
    test('rolls back everything written inside a failing boundary', () async {
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final record = await seedRecord(a.accountId!);

      await expectLater(
        db.transaction(() async {
          await transactions.addAll(<Transaction>[
            tx(
              accountId: a.accountId!,
              recordId: record,
              date: DateTime.utc(2025, 4, 1),
              amount: 1,
            ),
          ]);
          // Ranh giới lồng nhau phải là một phần của ranh giới ngoài.
          await db.transaction(() async {
            await transactions.addAll(<Transaction>[
              tx(
                accountId: a.accountId!,
                recordId: record,
                date: DateTime.utc(2025, 4, 2),
                amount: 2,
              ),
            ]);
          });
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(await transactions.count(TransactionFilter.none), 0);
    });
  });

  group('app settings repository', () {
    test('returns the initial record and round-trips a saved one', () async {
      final initial = await settings.load();
      expect(initial.appLockEnabled, isFalse);
      expect(initial.matchWindow, MatchWindow.standard);

      await settings.save(
        initial.enableLock(pinHash: 'hashed').withMatchWindow(MatchWindow(7)),
      );
      final loaded = await settings.load();
      expect(loaded.appLockEnabled, isTrue);
      expect(loaded.pinHash, 'hashed');
      expect(loaded.matchWindow.days, 7);

      await settings.save(loaded.disableLock());
      expect((await settings.load()).pinHash, isNull);
    });
  });

  group('csv parser', () {
    test('skips the preamble, honours quoting and reports broken rows', () {
      const parser = CsvParser();
      final file = bytesOf(
        'Ngan hang ABC\n'
        'So tai khoan: 0011 0004 1234\n'
        'Ngay giao dich;Ghi no;Ghi co;Noi dung;Nguoi chuyen\n'
        '10/01/2025;;1.000.000;"Chuyen tien; hoc phi";NGUYỄN VĂN A\n'
        '11/01/2025;250.000;;Thanh toan dien;\n'
        'khong-phai-ngay;1;;Loi;\n'
        '12/01/2025;1;1;Ca hai cot;\n',
      );

      final results = parser.parseLines(file).toList();
      final rows = rowsOf(results);
      expect(rows, hasLength(2));
      expect(rows[0].date, DateTime.utc(2025, 1, 10));
      expect(rows[0].amount, const Money(1000000, Currency.vnd));
      expect(rows[0].description, 'Chuyen tien; hoc phi');
      expect(rows[0].line, 4);
      expect(rows[1].amount, const Money(-250000, Currency.vnd));
      expect(errorsOf(results), 2);

      expect(parser.peekAccountNumber(file), '0011 0004 1234');
      expect(parser.estimateRowCount(file), 6);
    });

    test('does not swallow prose after the account number label', () {
      const parser = CsvParser();
      // Số tài khoản đứng giữa câu: phần chữ đứng sau không được dính vào.
      expect(
        parser.peekAccountNumber(
          bytesOf(
            'So tai khoan: 001100041234 tai Vietinbank chi nhanh 1\n'
            'Ngay;So tien;Noi dung\n',
          ),
        ),
        '001100041234',
      );
      // Không có nhãn thì không đoán bừa.
      expect(
        parser.peekAccountNumber(bytesOf('Ngay;So tien\n01/01/2025;1\n')),
        isNull,
      );
      // Chuỗi quá ngắn sau nhãn không phải số tài khoản.
      expect(parser.peekAccountNumber(bytesOf('So tai khoan: 12\n')), isNull);
    });

    test('a short alias never matches a column by prefix', () {
      // `co` là bí danh của cột ghi có, nhưng `Co quan` phải là cột nội dung
      // bình thường chứ không được đọc thành tiền vào.
      final rows = rowsOf(
        const CsvParser().parseLines(
          bytesOf(
            'Ngay;Co quan;So tien;Noi dung\n'
            '05/01/2025;Cong ty A;-50000;Chi phi\n',
          ),
        ),
      );
      expect(rows, hasLength(1));
      expect(rows.single.amount, const Money(-50000, Currency.vnd));
    });

    test('rejects a file without a usable header', () {
      expect(
        () => const CsvParser().parseLines(bytesOf('a;b\n1;2\n')).toList(),
        throwsFormatException,
      );
    });

    test('reads a signed single amount column with comma decimals', () {
      final rows = rowsOf(
        const CsvParser().parseLines(
          bytesOf(
            'Date,Amount,Currency,Description\n'
            '2025-03-01,"1,234.56",USD,Inbound\n'
            '2025-03-02,-99.5,USD,Outbound\n',
          ),
        ),
      );
      expect(rows[0].amount, const Money(123456, Currency.usd));
      expect(rows[1].amount, const Money(-9950, Currency.usd));
    });
  });

  group('mt940 parser', () {
    const file = ':20:STMT001\n'
        ':25:0011000412345/VND\n'
        ':28C:00001/001\n'
        ':60F:C250110VND10000,00\n'
        ':61:2501100110DN1500000,NTRFNONREF//REF1\n'
        ':86:CHUYEN TIEN NOI BO SANG TK B\n'
        ':61:2501110111CN2000000,NTRFNONREF\n'
        ':86:NGUYEN VAN A CHUYEN TIEN\n'
        'DONG THU HAI\n'
        ':62F:C250131VND10500000,00\n'
        '-}\n';

    test('reads statement lines, sign and account number', () {
      const parser = Mt940Parser();
      final bytes = bytesOf(file);
      final rows = rowsOf(parser.parseLines(bytes));

      expect(rows, hasLength(2));
      expect(rows[0].date, DateTime.utc(2025, 1, 10));
      expect(rows[0].amount, const Money(-1500000, Currency.vnd));
      expect(rows[0].description, 'CHUYEN TIEN NOI BO SANG TK B');
      expect(rows[0].line, 5);
      expect(rows[1].amount, const Money(2000000, Currency.vnd));
      expect(rows[1].description, 'NGUYEN VAN A CHUYEN TIEN DONG THU HAI');

      expect(parser.peekAccountNumber(bytes), '0011000412345');
      expect(parser.estimateRowCount(bytes), 2);
    });

    test('rejects a file with no statement line', () {
      expect(
        () => const Mt940Parser().parseLines(bytesOf(':20:X\n')).toList(),
        throwsFormatException,
      );
    });
  });

  group('json parser', () {
    test('reads a wrapped array and keeps field order irrelevant', () {
      const parser = JsonParser();
      final bytes = bytesOf(
        '{"accountNumber":"001100041234","transactions":['
        '{"date":"2025-05-01","amount":1500000,"description":"Thu tien"},'
        '{"description":"Chi tien","date":"2025-05-02","amount":-250000},'
        '{"date":"khong-hop-le","amount":1,"description":"Loi"}'
        ']}',
      );
      final results = parser.parseLines(bytes).toList();
      final rows = rowsOf(results);
      expect(rows, hasLength(2));
      expect(rows[0].amount, const Money(1500000, Currency.vnd));
      expect(rows[1].amount, const Money(-250000, Currency.vnd));
      expect(rows[1].description, 'Chi tien');
      expect(errorsOf(results), 1);
      expect(parser.peekAccountNumber(bytes), '001100041234');
    });
  });

  group('format detector', () {
    const detector = ContentStatementFormatDetector();

    test('decides from content, not from the extension', () {
      expect(
        detector.detect(
          fileName: 'khong-duoi-file',
          head: bytesOf('Ngay;So tien\n01/01/2025;1\n'),
        ),
        StatementFormat.csv,
      );
      expect(
        detector.detect(fileName: 'a.csv', head: bytesOf('{"a":[]}')),
        StatementFormat.json,
      );
      expect(
        detector.detect(fileName: 'a.json', head: bytesOf(':20:X\n:61:Y\n')),
        StatementFormat.mt940,
      );
      expect(
        detector.detect(
          fileName: 'a.xlsx',
          head: ExcelExporter.encode(
            const ExportTable(
              metadata: <String>[],
              headers: <String>['a'],
              rows: <List<String>>[],
            ),
          ),
        ),
        StatementFormat.excel,
      );
      // `.xls` đời cũ nằm ngoài phạm vi và phải được từ chối tường minh.
      expect(
        detector.detect(
          fileName: 'a.xls',
          head: Uint8List.fromList(<int>[
            0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1, 0, 0,
          ]),
        ),
        isNull,
      );
    });
  });

  group('exporters', () {
    final table = ExportTable(
      metadata: const <String>['Bộ lọc: VND', 'Từ khoá: "abc"'],
      headers: const <String>['Ngay giao dich', 'So tien', 'Noi dung'],
      rows: const <List<String>>[
        <String>['2025-01-10', '1000000', 'Chuyen tien, hoc phi'],
        <String>['2025-01-11', '-250000', 'Thanh toan "dien"'],
      ],
    );

    test('csv round-trips through the csv parser', () {
      final bytes = CsvExporter.encode(table);
      expect(bytes.take(3), <int>[0xEF, 0xBB, 0xBF]);

      final rows = rowsOf(const CsvParser().parseLines(bytes));
      expect(rows, hasLength(2));
      expect(rows[0].amount, const Money(1000000, Currency.vnd));
      expect(rows[0].description, 'Chuyen tien, hoc phi');
      expect(rows[1].description, 'Thanh toan "dien"');
    });

    test('xlsx round-trips through the excel parser', () {
      final bytes = ExcelExporter.encode(table);
      final rows = rowsOf(const ExcelParser().parseLines(bytes));
      expect(rows, hasLength(2));
      expect(rows[0].date, DateTime.utc(2025, 1, 10));
      expect(rows[0].amount, const Money(1000000, Currency.vnd));
      expect(rows[1].amount, const Money(-250000, Currency.vnd));
      expect(rows[1].description, 'Thanh toan "dien"');
      expect(const ExcelParser().estimateRowCount(bytes), isNull);
    });

    test('dispatches on the requested format', () {
      const exporter = SpreadsheetExporter();
      expect(exporter.toBytes(table, ExportFormat.csv).take(3),
          <int>[0xEF, 0xBB, 0xBF]);
      expect(exporter.toBytes(table, ExportFormat.excel).take(2),
          <int>[0x50, 0x4B]);
    });
  });

  group('backup codec', () {
    const codec = AesGcmBackupCodec();

    test('round-trips and refuses the wrong password', () async {
      final plain = bytesOf('{"format":"ledger_tracer.backup"}');
      final cipher = await codec.encrypt(plain, 'mat-khau-dung');
      expect(cipher.take(4), <int>[0x4C, 0x54, 0x42, 0x4B]);
      expect(await codec.decrypt(cipher, 'mat-khau-dung'), plain);

      await expectLater(
        codec.decrypt(cipher, 'mat-khau-sai'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('rejects a file that is not a backup at all', () async {
      await expectLater(
        codec.decrypt(bytesOf('day khong phai ban sao luu'), 'x'),
        throwsA(isA<CorruptBackupException>()),
      );
    });

    test('two encryptions of the same data differ', () async {
      final plain = bytesOf('abc');
      final first = await codec.encrypt(plain, 'p');
      final second = await codec.encrypt(plain, 'p');
      expect(first, isNot(second));
    });
  });

  group('pin hasher', () {
    const hasher = Pbkdf2PinHasher();

    test('hashes, verifies and never stores the plain pin', () {
      final hash = hasher.hash('1234');
      expect(hash, contains('pbkdf2-sha256'));
      expect(hash, isNot(contains('1234')));
      expect(hasher.verify('1234', hash), isTrue);
      expect(hasher.verify('4321', hash), isFalse);
      // Muối riêng cho từng lần băm.
      expect(hasher.hash('1234'), isNot(hash));
      expect(hasher.verify('1234', 'rac'), isFalse);
    });
  });

  group('app data store', () {
    test('snapshots, inspects, restores and wipes', () async {
      final store = SqliteAppDataStore(db: db, now: () => now);

      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final record = await seedRecord(a.accountId!);
      await transactions.addAll(<Transaction>[
        tx(
          accountId: a.accountId!,
          recordId: record,
          date: DateTime.utc(2025, 6, 1),
          amount: 999,
        ),
      ]);
      await settings.save(
        (await settings.load()).enableLock(pinHash: 'bi-mat'),
      );

      final snapshot = await store.snapshot();
      final manifest = await store.inspect(snapshot);
      expect(manifest.accountCount, 1);
      expect(manifest.transactionCount, 1);
      expect(manifest.createdAt, now);

      // Bản sao lưu không được mang theo mã PIN, nếu không thì lối thoát của
      // UC-12 tự triệt tiêu.
      expect(utf8.decode(snapshot), isNot(contains('bi-mat')));

      await expectLater(
        store.inspect(bytesOf('{"format":"khac"}')),
        throwsA(isA<CorruptBackupException>()),
      );

      await store.wipe();
      expect(await transactions.count(TransactionFilter.none), 0);
      expect((await settings.load()).appLockEnabled, isFalse);

      await store.replaceAll(snapshot);
      expect(await transactions.count(TransactionFilter.none), 1);
      final restored = await accounts.findAll();
      expect(restored.single.accountId, a.accountId);
      // Khoá ứng dụng không quay lại sau khi khôi phục.
      expect((await settings.load()).appLockEnabled, isFalse);
    });

    test('pages through every row when a table is larger than one page',
        () async {
      final store = SqliteAppDataStore(db: db, now: () => now);
      final a = await accounts.add(
        BankAccount.create(displayName: 'A', createdAt: now),
      );
      final record = await seedRecord(a.accountId!);

      // Vượt qua kích thước trang (2000) để phần phân trang của snapshot thật
      // sự chạy nhiều vòng.
      const total = 2500;
      await transactions.addAll(<Transaction>[
        for (var index = 0; index < total; index++)
          tx(
            accountId: a.accountId!,
            recordId: record,
            date: DateTime.utc(2025, 1, 1).add(Duration(days: index)),
            amount: index + 1,
            description: 'Dong $index',
          ),
      ]);

      final snapshot = await store.snapshot();
      expect((await store.inspect(snapshot)).transactionCount, total);

      await store.wipe();
      await store.replaceAll(snapshot);
      expect(await transactions.count(TransactionFilter.none), total);
    });

    test('wipe works on a database that has never been written to', () async {
      final store = SqliteAppDataStore(db: db, now: () => now);
      await store.wipe();
      expect(await transactions.count(TransactionFilter.none), 0);
    });
  });

  group('file saver service', () {
    test('is wired to both export and backup ports', () {
      const saver = PlatformFileSaverService();
      expect(saver, isA<FileSaver>());
      expect(saver, isA<BackupWriter>());
    });
  });
}
