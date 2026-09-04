import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/transactions/edit_transaction/edit_transaction_dto.dart';
import 'package:ledger_tracer/application/transactions/edit_transaction/edit_transaction_use_case.dart';
import 'package:ledger_tracer/application/transactions/query_transactions/query_transactions_dto.dart';
import 'package:ledger_tracer/application/transactions/query_transactions/query_transactions_use_case.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';

import '_support/fake_repositories.dart';
import '_support/seed.dart';

void main() {
  late FakeDatabase db;
  late Seed seed;
  late EditTransactionUseCase editTransaction;
  late QueryTransactionsUseCase queryTransactions;

  late int accountA;
  late int accountB;
  late int recordA;
  late int recordB;

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    editTransaction = EditTransactionUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
    );
    queryTransactions = QueryTransactionsUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      accounts: db.accounts,
    );

    accountA = await seed.account('Vietinbank vận hành');
    accountB = await seed.account('Ví thu hộ');
    recordA = await seed.fileRecord(accountId: accountA);
    recordB = await seed.fileRecord(accountId: accountB);
  });

  Future<int> tx({
    int? account,
    int? record,
    int amount = -500000,
    int day = 10,
    Currency currency = Currency.vnd,
    String? counterparty = 'Nguyễn Văn A',
    String description = 'CK tien hang',
  }) => seed.transaction(
    accountId: account ?? accountA,
    recordId: record ?? recordA,
    amount: amount,
    bookingDate: DateTime.utc(2025, 3, day),
    currency: currency,
    counterpartyName: counterparty,
    description: description,
  );

  group('sửa một giao dịch', () {
    test('tính lại searchText và fingerprint theo dữ liệu mới', () async {
      // Bản đã sửa mà giữ cột dẫn xuất cũ sẽ vừa tìm không ra vừa bị coi là giao
      // dịch mới ở lần nhập sau.
      final id = await tx();
      final before = db.transactionRows[id]!;

      final result = await editTransaction.execute(
        EditTransactionRequest(
          transactionId: id,
          bookingDate: DateTime.utc(2025, 3, 12),
          amount: const Money(-600000, Currency.vnd),
          counterpartyName: 'Trần Thị B',
          description: 'Trả nợ',
        ),
      );

      expect(result.isOk, isTrue);
      final after = db.transactionRows[id]!;
      expect(after.searchText, SearchText.query('tran thi b tra no'));
      expect(after.fingerprint, isNot(before.fingerprint));
      expect(after.isManuallyEdited, isTrue);
      expect(after.amount, const Money(-600000, Currency.vnd));
      expect(after.bookingDate, DateTime.utc(2025, 3, 12));
    });

    test('bản đã sửa tìm được bằng từ khoá mới và không còn khớp từ khoá cũ', () async {
      final id = await tx();
      await editTransaction.execute(
        EditTransactionRequest(
          transactionId: id,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-500000, Currency.vnd),
          counterpartyName: 'Lê Đình C',
          description: 'Hoan tien',
        ),
      );

      final found = await queryTransactions.execute(
        QueryTransactionsRequest(
          filter: TransactionFilter(keyword: SearchText.query('lê đình')),
          limit: 10,
          offset: 0,
        ),
      );
      expect(found.valueOrNull!.totalCount, 1);

      final gone = await queryTransactions.execute(
        QueryTransactionsRequest(
          filter: TransactionFilter(keyword: SearchText.query('nguyen van a')),
          limit: 10,
          offset: 0,
        ),
      );
      expect(gone.valueOrNull!.totalCount, 0);
    });

    test('huỷ cặp gợi ý mà giao dịch đang thuộc về', () async {
      // Gợi ý sinh ra từ chính số tiền và thời điểm vừa bị thay đổi.
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into);

      final result = await editTransaction.execute(
        EditTransactionRequest(
          transactionId: out,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-400000, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );

      expect(result.valueOrNull!.cancelledReconciliation, isTrue);
      expect(db.pairRows, isEmpty);
    });

    test('huỷ cả cặp đã xác nhận, không chỉ cặp gợi ý', () async {
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      await editTransaction.execute(
        EditTransactionRequest(
          transactionId: out,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-400000, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      expect(db.pairRows, isEmpty);
    });

    test('huỷ cặp do sửa dữ liệu KHÔNG ghi thành phán quyết từ chối', () async {
      // Người dùng đang chỉnh dữ liệu sai, không phủ nhận rằng hai giao dịch là
      // một cặp. Gộp hai tình huống sẽ khiến mỗi lần sửa vô tình chặn vĩnh viễn
      // giao dịch khỏi đối tác cũ.
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      await editTransaction.execute(
        EditTransactionRequest(
          transactionId: out,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-400000, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      expect(db.rejectionRows, isEmpty);
    });

    test('giao dịch không thuộc cặp nào thì không báo huỷ cặp', () async {
      final id = await tx();
      final result = await editTransaction.execute(
        EditTransactionRequest(
          transactionId: id,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-1, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      expect(result.valueOrNull!.cancelledReconciliation, isFalse);
    });

    test('không đụng tới tài khoản và chuỗi nguồn gốc', () async {
      final id = await tx();
      await editTransaction.execute(
        EditTransactionRequest(
          transactionId: id,
          bookingDate: DateTime.utc(2025, 4, 1),
          amount: const Money(-1, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      final after = db.transactionRows[id]!;
      expect(after.accountId, accountA);
      expect(after.importFileRecordId, recordA);
    });

    test('sửa một giao dịch không tồn tại báo không tìm thấy', () async {
      final result = await editTransaction.execute(
        EditTransactionRequest(
          transactionId: 999999,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-1, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('sửa và huỷ cặp cùng thành công hoặc cùng không', () async {
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into);
      final before = db.unitOfWork.committed;

      await editTransaction.execute(
        EditTransactionRequest(
          transactionId: out,
          bookingDate: DateTime.utc(2025, 3, 10),
          amount: const Money(-1, Currency.vnd),
          counterpartyName: null,
          description: 'x',
        ),
      );
      expect(db.unitOfWork.committed, before + 1);
    });
  });

  group('duyệt và tìm kiếm', () {
    test('trả về theo trang kèm tổng số dòng khớp', () async {
      for (var day = 1; day <= 5; day++) {
        await tx(day: day);
      }
      final page = await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 2, offset: 0),
      );
      expect(page.valueOrNull!.items.length, 2);
      expect(page.valueOrNull!.totalCount, 5);
      expect(page.valueOrNull!.isEmpty, isFalse);
    });

    test('không nạp cả tập vào bộ nhớ — chỉ hỏi đúng kích thước trang', () async {
      for (var day = 1; day <= 5; day++) {
        await tx(day: day);
      }
      db.transactions.requestedPageSizes.clear();
      await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 2, offset: 0),
      );
      expect(db.transactions.requestedPageSizes, <int>[2]);
    });

    test('mỗi dòng kèm tên tài khoản vì danh sách gộp chung mọi tài khoản', () async {
      await tx();
      await tx(account: accountB, record: recordB, amount: 100);
      final page = await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 10, offset: 0),
      );
      expect(
        page.valueOrNull!.items.map((i) => i.accountDisplayName).toSet(),
        <String>{'Vietinbank vận hành', 'Ví thu hộ'},
      );
    });

    test('chỉ báo "đã đối soát" chỉ bật cho cặp đã xác nhận', () async {
      // Gợi ý chưa có hiệu lực nghiệp vụ nên chưa phải "đã đối soát".
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into);

      var page = await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 10, offset: 0),
      );
      expect(page.valueOrNull!.items.every((i) => !i.isReconciled), isTrue);

      await db.reconciliation.updatePair(
        db.pairRows.values.single.confirm(Seed.defaultNow),
      );
      page = await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 10, offset: 0),
      );
      expect(page.valueOrNull!.items.every((i) => i.isReconciled), isTrue);
    });

    test('danh sách rỗng nói rõ là rỗng để giao diện hiện trạng thái trống', () async {
      final page = await queryTransactions.execute(
        const QueryTransactionsRequest(limit: 10, offset: 0),
      );
      expect(page.valueOrNull!.isEmpty, isTrue);
      expect(page.valueOrNull!.items, isEmpty);
    });

    test('tìm kiếm kết hợp được với bộ lọc', () async {
      await tx(day: 5, counterparty: 'Nguyễn Văn A');
      await tx(day: 25, counterparty: 'Nguyễn Văn A');
      await tx(day: 5, counterparty: 'Trần B');

      final page = await queryTransactions.execute(
        QueryTransactionsRequest(
          filter: TransactionFilter(
            keyword: SearchText.query('nguyễn'),
            dateRange: DateRange(
              from: DateTime.utc(2025, 3, 1),
              to: DateTime.utc(2025, 3, 10),
            ),
          ),
          limit: 10,
          offset: 0,
        ),
      );
      expect(page.valueOrNull!.totalCount, 1);
    });

    test('lọc thu hẹp về một tài khoản', () async {
      await tx();
      await tx(account: accountB, record: recordB, amount: 100);
      final page = await queryTransactions.execute(
        QueryTransactionsRequest(
          filter: TransactionFilter(accountId: accountB),
          limit: 10,
          offset: 0,
        ),
      );
      expect(page.valueOrNull!.totalCount, 1);
      expect(page.valueOrNull!.items.single.accountDisplayName, 'Ví thu hộ');
    });

    test('nạp được chi tiết một giao dịch, và trả null khi không còn', () async {
      final id = await tx();
      expect(
        (await queryTransactions.findById(id)).valueOrNull!.transactionId,
        id,
      );
      expect((await queryTransactions.findById(999999)).valueOrNull, isNull);
    });
  });

  group('các loại tiền đang có', () {
    test('xếp loại tiền nhiều giao dịch nhất lên đầu', () async {
      // Bộ lọc số tiền mặc định theo loại tiền phổ biến nhất, và màn hình thống
      // kê mở sẵn ở tab đó.
      await tx(currency: Currency.usd, amount: -100, day: 1);
      await tx(currency: Currency.vnd, amount: -100, day: 2);
      await tx(currency: Currency.vnd, amount: -100, day: 3);
      await tx(currency: Currency.vnd, amount: -100, day: 4);

      final usage = await queryTransactions.availableCurrencies();
      expect(usage.valueOrNull!.first.currency, Currency.vnd);
      expect(usage.valueOrNull!.first.transactionCount, 3);
      expect(usage.valueOrNull!.last.currency, Currency.usd);
    });

    test('dữ liệu rỗng thì không có loại tiền nào', () async {
      expect((await queryTransactions.availableCurrencies()).valueOrNull, isEmpty);
    });
  });
}
