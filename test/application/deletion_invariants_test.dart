import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/accounts/manage_accounts/manage_accounts_use_case.dart';
import 'package:ledger_tracer/application/import/revert_import/revert_import_use_case.dart';
import 'package:ledger_tracer/application/transactions/delete_transaction/delete_transaction_use_case.dart';
import 'package:ledger_tracer/core/result/failure.dart';

import '_support/fake_repositories.dart';
import '_support/seed.dart';

/// **Bất biến về cặp đối soát:** một cặp chỉ tồn tại khi cả hai giao dịch của nó
/// còn tồn tại. Có ba đường xoá giao dịch — xoá lẻ (UC-05), xoá theo tài khoản
/// (UC-01), hoàn tác lượt nhập (UC-03) — và cả ba đều phải huỷ cặp liên quan
/// **và** xoá phán quyết từ chối dính tới nó.
///
/// Ba đường được kiểm chung một chỗ, đúng như quy tắc được đặt tập trung ở UC-09
/// để các use case khác tham chiếu: nếu mỗi đường có test riêng theo cách riêng,
/// chúng sẽ trôi khỏi nhau đúng như bản mô tả sẽ trôi khỏi nhau.
void main() {
  late FakeDatabase db;
  late Seed seed;
  late DeleteTransactionUseCase deleteTransaction;
  late ManageAccountsUseCase manageAccounts;
  late RevertImportUseCase revertImport;

  late int accountA;
  late int accountB;
  late int recordA;
  late int recordB;

  final now = Seed.defaultNow;

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    deleteTransaction = DeleteTransactionUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
    );
    manageAccounts = ManageAccountsUseCase(
      accounts: db.accounts,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      now: () => now,
    );
    revertImport = RevertImportUseCase(
      imports: db.imports,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
      now: () => now,
    );

    accountA = await seed.account('A');
    accountB = await seed.account('B');
    recordA = await seed.fileRecord(accountId: accountA, name: 'a.csv');
    recordB = await seed.fileRecord(accountId: accountB, name: 'b.csv');
  });

  /// Một cặp đã xác nhận giữa hai tài khoản, cộng một phán quyết từ chối treo
  /// trên vế chuyển ra.
  Future<({int out, int into, int other, int pairId, int rejectionId})>
  pairedWorld() async {
    final out = await seed.transaction(
      accountId: accountA,
      recordId: recordA,
      amount: -500000,
      bookingDate: DateTime.utc(2025, 3, 10),
    );
    final into = await seed.transaction(
      accountId: accountB,
      recordId: recordB,
      amount: 500000,
      bookingDate: DateTime.utc(2025, 3, 11),
    );
    final other = await seed.transaction(
      accountId: accountB,
      recordId: recordB,
      amount: 500000,
      bookingDate: DateTime.utc(2025, 3, 12),
    );
    final pairId = await seed.pair(
      outgoingId: out,
      incomingId: into,
      confirmed: true,
    );
    final rejectionId = await seed.rejection(aId: out, bId: other);
    return (
      out: out,
      into: into,
      other: other,
      pairId: pairId,
      rejectionId: rejectionId,
    );
  }

  group('xoá lẻ một giao dịch (UC-05)', () {
    test('huỷ cặp và trả vế còn lại về trạng thái chưa ghép', () async {
      final world = await pairedWorld();

      final result = await deleteTransaction.execute(world.out);

      expect(result.valueOrNull, isTrue);
      expect(db.transactionRows.containsKey(world.out), isFalse);
      expect(db.pairRows, isEmpty);
      // Vế còn lại vẫn còn nguyên, chỉ là không còn thuộc cặp nào.
      expect(db.transactionRows.containsKey(world.into), isTrue);
      expect(
        await db.reconciliation.findPairInvolving(world.into),
        isNull,
      );
    });

    test('xoá luôn phán quyết từ chối dính tới giao dịch bị xoá', () async {
      // Phán quyết chỉ có nghĩa khi cả hai vế còn tồn tại.
      final world = await pairedWorld();
      await deleteTransaction.execute(world.out);
      expect(db.rejectionRows, isEmpty);
    });

    test('không đụng tới phán quyết của những giao dịch khác', () async {
      final world = await pairedWorld();
      final farA = await seed.transaction(
        accountId: accountA,
        recordId: recordA,
        amount: -1,
        bookingDate: DateTime.utc(2025, 3, 20),
      );
      final farB = await seed.transaction(
        accountId: accountB,
        recordId: recordB,
        amount: 1,
        bookingDate: DateTime.utc(2025, 3, 20),
      );
      final untouched = await seed.rejection(aId: farA, bId: farB);

      await deleteTransaction.execute(world.out);
      expect(db.rejectionRows.containsKey(untouched), isTrue);
    });

    test('báo cho giao diện biết có cặp nào vừa bị huỷ hay không', () async {
      final world = await pairedWorld();
      expect((await deleteTransaction.isInPair(world.out)).valueOrNull, isTrue);
      expect((await deleteTransaction.isInPair(world.other)).valueOrNull, isFalse);

      final withoutPair = await deleteTransaction.execute(world.other);
      expect(withoutPair.valueOrNull, isFalse);
    });

    test('xoá một định danh không tồn tại báo lỗi thay vì báo thành công', () async {
      final result = await deleteTransaction.execute(999999);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('cả ba bước nằm trong đúng một transaction', () async {
      final world = await pairedWorld();
      final before = db.unitOfWork.committed;
      await deleteTransaction.execute(world.out);
      expect(db.unitOfWork.committed, before + 1);
    });
  });

  group('xoá tài khoản (UC-01)', () {
    test('xoá theo cả giao dịch, cặp, phán quyết và bản ghi nhập của nó', () async {
      final world = await pairedWorld();

      final result = await manageAccounts.delete(accountA);

      expect(result.isOk, isTrue);
      expect(db.accountRows.containsKey(accountA), isFalse);
      expect(db.transactionRows.containsKey(world.out), isFalse);
      expect(db.pairRows, isEmpty);
      expect(db.rejectionRows, isEmpty);
      expect(db.fileRecordRows.containsKey(recordA), isFalse);
    });

    test('không đụng tới dữ liệu của tài khoản khác', () async {
      final world = await pairedWorld();
      await manageAccounts.delete(accountA);

      expect(db.accountRows.containsKey(accountB), isTrue);
      expect(db.transactionRows.containsKey(world.into), isTrue);
      expect(db.transactionRows.containsKey(world.other), isTrue);
      expect(db.fileRecordRows.containsKey(recordB), isTrue);
    });

    test('chỉ xoá bản ghi của file gán vào nó, không xoá cả lượt', () async {
      // Một lượt nhiều file có thể gán nhiều tài khoản khác nhau; xoá nguyên
      // lượt sẽ xoá oan lịch sử của file thuộc tài khoản khác.
      final session = db.fileRecordRows[recordA]!.sessionId;
      final sharedRecord = await db.imports.addFileRecord(
        db.fileRecordRows[recordB]!,
      );
      db.fileRecordRows[sharedRecord.recordId!] = sharedRecord;

      await manageAccounts.delete(accountA);

      expect(db.fileRecordRows.containsKey(recordA), isFalse);
      expect(db.fileRecordRows.containsKey(recordB), isTrue);
      // Lượt nhập chỉ biến mất khi không còn bản ghi con nào.
      expect(db.sessionRows.containsKey(session), isFalse);
    });

    test('hộp thoại xác nhận biết trước số giao dịch và số cặp bị ảnh hưởng', () async {
      await pairedWorld();
      final impact = await manageAccounts.previewDeletion(accountA);
      expect(impact.valueOrNull!.transactionCount, 1);
      expect(impact.valueOrNull!.reconciledPairCount, 1);
    });

    test('xoá một tài khoản không tồn tại báo không tìm thấy', () async {
      final result = await manageAccounts.delete(999999);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('toàn bộ chuỗi xoá nằm trong đúng một transaction', () async {
      await pairedWorld();
      final before = db.unitOfWork.committed;
      await manageAccounts.delete(accountA);
      expect(db.unitOfWork.committed, before + 1);
    });
  });

  group('hoàn tác một lượt nhập (UC-03)', () {
    test('xoá đúng những gì bản ghi đó đã thêm', () async {
      final world = await pairedWorld();
      await seed.closeRecord(recordA);

      final result = await revertImport.revertFile(recordA);

      expect(result.isOk, isTrue);
      expect(db.transactionRows.containsKey(world.out), isFalse);
      expect(db.transactionRows.containsKey(world.into), isTrue);
      expect(db.transactionRows.containsKey(world.other), isTrue);
    });

    test('huỷ cặp và xoá phán quyết dính tới các dòng bị xoá', () async {
      await pairedWorld();
      await seed.closeRecord(recordA);
      await revertImport.revertFile(recordA);
      expect(db.pairRows, isEmpty);
      expect(db.rejectionRows, isEmpty);
    });

    test('bản ghi ở lại lịch sử với dấu đã hoàn tác', () async {
      // revertedAt không phải tombstone: người dùng cần thấy "đã nhập rồi hoàn
      // tác", và dòng lỗi của nó vẫn phải xuất lại được.
      await pairedWorld();
      await seed.closeRecord(recordA);
      await revertImport.revertFile(recordA);

      final record = db.fileRecordRows[recordA]!;
      expect(record.isReverted, isTrue);
      expect(record.revertedAt, now);
      expect(record.fileName, 'a.csv');
    });

    test('hoàn tác hai lần bị chặn và không xoá thêm gì', () async {
      await pairedWorld();
      await seed.closeRecord(recordA);
      await revertImport.revertFile(recordA);
      final remaining = db.transactionRows.length;

      final again = await revertImport.revertFile(recordA);
      expect(again.failureOrNull, isA<ValidationFailure>());
      expect(db.transactionRows.length, remaining);
    });

    test('bản ghi chưa ghi được dòng nào thì không có gì để hoàn tác', () async {
      final emptyRecord = await seed.fileRecord(accountId: accountA);
      await seed.closeRecord(emptyRecord);
      expect(
        (await revertImport.revertFile(emptyRecord)).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('hoàn tác một bản ghi không tồn tại báo không tìm thấy', () async {
      expect(
        (await revertImport.revertFile(999999)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('hộp thoại biết trước số dòng, số cặp và việc đã sửa tay', () async {
      await pairedWorld();
      await seed.transaction(
        accountId: accountA,
        recordId: recordA,
        amount: -1,
        bookingDate: DateTime.utc(2025, 3, 15),
        manuallyEdited: true,
      );
      await seed.closeRecord(recordA);

      final impact = await revertImport.previewFileRevert(recordA);
      expect(impact.valueOrNull!.deletedTransactionCount, 2);
      expect(impact.valueOrNull!.cancelledPairCount, 1);
      expect(impact.valueOrNull!.hasManualEdits, isTrue);
    });

    test('xem trước không đụng tới dữ liệu', () async {
      await pairedWorld();
      await seed.closeRecord(recordA);
      final before = db.transactionRows.length;
      await revertImport.previewFileRevert(recordA);
      expect(db.transactionRows.length, before);
      expect(db.fileRecordRows[recordA]!.isReverted, isFalse);
    });
  });

  group('hoàn tác cả một lượt nhiều file', () {
    late int sessionId;
    late int firstRecord;
    late int secondRecord;

    setUp(() async {
      final session = db.sessionRows[db.fileRecordRows[recordA]!.sessionId]!;
      sessionId = session.sessionId!;
      firstRecord = recordA;
      secondRecord = (await db.imports.addFileRecord(
        db.fileRecordRows[recordA]!,
      )).recordId!;

      await seed.transaction(
        accountId: accountA,
        recordId: firstRecord,
        amount: -100,
        bookingDate: DateTime.utc(2025, 3, 1),
      );
      await seed.transaction(
        accountId: accountA,
        recordId: secondRecord,
        amount: -200,
        bookingDate: DateTime.utc(2025, 3, 2),
      );
      await seed.closeRecord(firstRecord);
      await seed.closeRecord(secondRecord);
    });

    test('lần lượt hoàn tác từng bản ghi con theo đúng quy tắc', () async {
      final result = await revertImport.revertSession(sessionId);

      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.deletedTransactionCount, 2);
      expect(db.transactionRows, isEmpty);
      expect(db.fileRecordRows[firstRecord]!.isReverted, isTrue);
      expect(db.fileRecordRows[secondRecord]!.isReverted, isTrue);
    });

    test('bỏ qua bản ghi con đã hoàn tác thay vì hỏng cả lượt', () async {
      await revertImport.revertFile(firstRecord);
      final result = await revertImport.revertSession(sessionId);
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.deletedTransactionCount, 1);
    });

    test('gộp số liệu xem trước của mọi bản ghi con còn hoàn tác được', () async {
      final impact = await revertImport.previewSessionRevert(sessionId);
      expect(impact.valueOrNull!.deletedTransactionCount, 2);
    });

    test('hoàn tác cả lượt là một transaction duy nhất', () async {
      final before = db.unitOfWork.committed;
      await revertImport.revertSession(sessionId);
      expect(db.unitOfWork.committed, before + 1);
    });

    test('lượt nhập không tồn tại báo không tìm thấy', () async {
      expect(
        (await revertImport.revertSession(999999)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('lịch sử nhập', () {
    test('trả về theo trang, kèm tổng số lượt', () async {
      final page = await revertImport.history(limit: 10, offset: 0);
      expect(page.valueOrNull!.totalCount, db.sessionRows.length);
      expect(page.valueOrNull!.offset, 0);
    });

    test('mỗi lượt kèm đầy đủ bản ghi file con của nó', () async {
      // Hoàn tác cả lượt được định nghĩa là hoàn tác từng bản ghi con, nên một
      // danh sách con rỗng sẽ khiến thao tác im lặng không làm gì.
      await seed.transaction(
        accountId: accountA,
        recordId: recordA,
        amount: -1,
        bookingDate: DateTime.utc(2025, 3, 1),
      );
      final page = await revertImport.history(limit: 10, offset: 0);
      final sessions = page.valueOrNull!.sessions;
      expect(sessions.every((s) => s.fileRecords.isNotEmpty), isTrue);
    });
  });
}
