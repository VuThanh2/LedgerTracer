import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/domain/entities/import_file_record.dart';
import 'package:ledger_tracer/domain/entities/import_session.dart';
import 'package:ledger_tracer/domain/entities/reconciliation_pair.dart';
import 'package:ledger_tracer/domain/entities/rejected_match.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

import 'fake_repositories.dart';

/// Dựng tiền điều kiện cho test tầng Application mà không phải chạy cả luồng
/// nhập: gieo thẳng vào cơ sở dữ liệu giả những gì một lượt nhập sẽ để lại.
final class Seed {
  Seed(this.db);

  final FakeDatabase db;

  static final DateTime defaultNow = DateTime.utc(2025, 9, 1, 12);

  Future<int> account(String name) async =>
      (await db.accounts.add(
        BankAccount.create(displayName: name, createdAt: defaultNow),
      )).accountId!;

  /// Một lượt nhập đã hoàn tất với đúng một bản ghi file, để các giao dịch gieo
  /// vào có nguồn gốc thật — mọi giao dịch đều phải trỏ về một bản ghi nhập.
  Future<int> fileRecord({required int accountId, String name = 'seed.csv'}) async {
    final session = await db.imports.addSession(
      ImportSession.started(defaultNow),
    );
    final record = await db.imports.addFileRecord(
      ImportFileRecord.started(
        sessionId: session.sessionId!,
        accountId: accountId,
        fileName: name,
        detectedFormat: StatementFormat.csv,
        orderIndex: 0,
      ),
    );
    return record.recordId!;
  }

  Future<int> transaction({
    required int accountId,
    required int recordId,
    required int amount,
    required DateTime bookingDate,
    Currency currency = Currency.vnd,
    String? counterpartyName = 'Doi tac',
    String description = 'CK',
    bool manuallyEdited = false,
  }) async {
    final base = Transaction.imported(
      accountId: accountId,
      bookingDate: bookingDate,
      amount: Money(amount, currency),
      counterpartyName: counterpartyName,
      description: description,
      importFileRecordId: recordId,
      importedAt: defaultNow,
    );
    final ids = await db.transactions.addAll(<Transaction>[base]);
    final id = ids.single;
    if (manuallyEdited) {
      final stored = db.transactionRows[id]!;
      db.transactionRows[id] = stored.editedWith(
        bookingDate: stored.bookingDate,
        amount: stored.amount,
        counterpartyName: stored.counterpartyName,
        description: stored.description,
      );
    }
    return id;
  }

  /// Chốt lại bộ đếm của bản ghi file cho khớp với số dòng đã gieo, để lịch sử
  /// nhập nói đúng sự thật.
  ///
  /// Cộng theo **phần chênh** chứ không cộng thẳng số dòng đếm được: bộ đếm của
  /// bản ghi lớn dần theo từng lô như ở đường nhập thật, nên cộng thẳng sẽ đếm
  /// đôi nếu ai đó gieo thêm rồi gọi lại. Gọi bao nhiêu lần cũng cho cùng một
  /// kết quả.
  Future<void> closeRecord(int recordId) async {
    final record = db.fileRecordRows[recordId]!;
    final imported = db.transactionRows.values
        .where((tx) => tx.importFileRecordId == recordId)
        .length;
    final missing = imported - record.importedCount;
    await db.imports.updateFileRecord(
      (missing > 0 ? record.accumulate(importedCount: missing) : record)
          .finished(),
    );
  }

  Future<int> pair({
    required int outgoingId,
    required int incomingId,
    bool confirmed = false,
  }) async {
    await db.reconciliation.addPairs(<ReconciliationPair>[
      ReconciliationPair.suggested(
        outgoingTransactionId: outgoingId,
        incomingTransactionId: incomingId,
        createdAt: defaultNow,
      ),
    ]);
    final pairId = db.pairRows.keys.last;
    if (confirmed) {
      await db.reconciliation.updatePair(
        db.pairRows[pairId]!.confirm(defaultNow),
      );
    }
    return pairId;
  }

  Future<int> rejection({required int aId, required int bId}) async =>
      (await db.reconciliation.addRejection(
        RejectedMatch.between(
          transactionAId: aId,
          transactionBId: bId,
          rejectedAt: defaultNow,
        ),
      )).rejectedMatchId!;
}
