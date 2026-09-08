import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/accounts/manage_accounts/manage_accounts_use_case.dart';
import 'package:ledger_tracer/application/transactions/delete_transaction/delete_transaction_use_case.dart';
import 'package:ledger_tracer/application/transactions/query_transactions/query_transactions_use_case.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/presentation/shared/bloc/load_status.dart';
import 'package:ledger_tracer/presentation/transactions/bloc/transactions_bloc.dart';
import 'package:ledger_tracer/presentation/transactions/bloc/transactions_event.dart';
import 'package:ledger_tracer/presentation/transactions/bloc/transactions_state.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/filter_chip_view_model.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_context.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_filter_draft.dart';

import '_support/presentation_fixtures.dart';

void main() {
  late FakeDatabase db;
  late Seed seed;
  late TransactionsBloc bloc;

  late int accountA;
  late int accountB;
  late int recordA1;
  late int recordA2;
  late int recordB;

  /// Đợi tới lúc BLoC đọc xong. Mọi phép đọc ở đây chạy trên cơ sở dữ liệu giả
  /// trong bộ nhớ, nên "xong" tới sau vài lượt event loop chứ không phải sau một
  /// khoảng thời gian.
  Future<TransactionsState> ready() =>
      bloc.stream.firstWhere((state) => state.status.isReady);

  TransactionsBloc build({int pageSize = 50}) => TransactionsBloc(
    queryTransactions: QueryTransactionsUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      accounts: db.accounts,
    ),
    deleteTransaction: DeleteTransactionUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
    ),
    manageAccounts: ManageAccountsUseCase(
      accounts: db.accounts,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      now: () => Seed.defaultNow,
    ),
    pageSize: pageSize,
  );

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);

    accountA = await seed.account('Vietinbank vận hành');
    accountB = await seed.account('Ví thu hộ');
    recordA1 = await seed.fileRecord(accountId: accountA, name: 'thang-01.csv');
    recordA2 = await seed.fileRecord(accountId: accountA, name: 'thang-02.csv');
    recordB = await seed.fileRecord(accountId: accountB, name: 'vi.csv');
  });

  tearDown(() => bloc.close());

  Future<int> tx({
    required int account,
    required int record,
    int amount = -500000,
    int day = 10,
    Currency currency = Currency.vnd,
    String description = 'CK tien hang',
  }) => seed.transaction(
    accountId: account,
    recordId: record,
    amount: amount,
    bookingDate: DateTime.utc(2025, 3, day),
    currency: currency,
    description: description,
  );

  group('mở màn hình', () {
    test('nạp trang đầu, đếm đúng, và không có ngữ cảnh nào', () async {
      for (var i = 1; i <= 3; i++) {
        await tx(account: accountA, record: recordA1, day: i);
      }
      bloc = build();
      bloc.add(const TransactionsStarted());
      final state = await ready();

      expect(state.rows, hasLength(3));
      expect(state.totalCount, 3);
      expect(state.hasMore, isFalse);
      expect(state.chips, isEmpty);
      // Tên tài khoản phải có mặt: danh sách gộp mọi tài khoản nên thiếu nó là
      // không đọc hiểu được dữ liệu.
      expect(state.rows.first.accountName, isNotEmpty);
    });

    test('loại tiền mặc định của bộ lọc là loại phổ biến nhất', () async {
      await tx(account: accountA, record: recordA1, day: 1);
      await tx(account: accountA, record: recordA1, day: 2);
      await tx(
        account: accountB,
        record: recordB,
        day: 3,
        amount: 1000,
        currency: Currency.usd,
      );

      bloc = build();
      bloc.add(const TransactionsStarted());
      await ready();

      expect(bloc.state.currencies.first.currency, Currency.vnd);
      expect(bloc.state.draft.currency, Currency.vnd);
    });
  });

  group('phân trang', () {
    test('cộng dồn trang thay vì thay thế', () async {
      for (var i = 1; i <= 5; i++) {
        await tx(account: accountA, record: recordA1, day: i);
      }
      bloc = build(pageSize: 2);
      bloc.add(const TransactionsStarted());
      var state = await ready();
      expect(state.rows, hasLength(2));
      expect(state.hasMore, isTrue);

      bloc.add(const TransactionsNextPageRequested());
      state = await bloc.stream.firstWhere(
        (state) => state.rows.length == 4,
      );
      expect(state.hasMore, isTrue);

      bloc.add(const TransactionsNextPageRequested());
      state = await bloc.stream.firstWhere((state) => state.rows.length == 5);
      expect(state.hasMore, isFalse);
    });
  });

  group('Context Chip', () {
    test(
      'ngữ cảnh "lượt nhập" chỉ giữ giao dịch của đúng file đó',
      () async {
        await tx(account: accountA, record: recordA1, day: 1);
        await tx(account: accountA, record: recordA2, day: 2);
        await tx(account: accountB, record: recordB, day: 3);

        bloc = build();
        bloc.add(
          TransactionsStarted(
            context: TransactionContext.fromImport(
              recordId: recordA1,
              fileName: 'thang-01.csv',
            ),
          ),
        );
        final state = await ready();

        expect(state.rows, hasLength(1));
        expect(
          state.chips.map((chip) => chip.kind),
          contains(FilterChipKind.importFile),
        );
        // Ngữ cảnh đi xuống cùng truy vấn với bộ lọc, nên phép đếm nói đúng
        // con số đang hiển thị chứ không phải một cận trên.
        expect(state.totalCount, 1);
      },
    );

    test(
      'ngữ cảnh "không gồm chuyển khoản nội bộ" bỏ đúng các dòng đã xác nhận',
      () async {
        final out = await tx(
          account: accountA,
          record: recordA1,
          amount: -2000000,
          day: 5,
        );
        final into = await tx(
          account: accountB,
          record: recordB,
          amount: 2000000,
          day: 5,
        );
        await tx(account: accountA, record: recordA1, day: 6);
        // Chỉ cặp **đã xác nhận** mới là "giao dịch nội bộ đã đối soát"; gợi ý
        // chưa có hiệu lực nghiệp vụ nên không được loại.
        await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

        bloc = build();
        bloc.add(
          const TransactionsStarted(
            context: TransactionContext.fromStatistics(
              excludeInternalTransfers: true,
            ),
          ),
        );
        final state = await ready();

        expect(state.rows, hasLength(1));
        expect(state.rows.single.isReconciled, isFalse);
        expect(state.totalCount, 1);
      },
    );

    test('cặp mới **gợi ý** thì không bị ngữ cảnh loại ra', () async {
      final out = await tx(
        account: accountA,
        record: recordA1,
        amount: -2000000,
        day: 5,
      );
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 2000000,
        day: 5,
      );
      await seed.pair(outgoingId: out, incomingId: into);

      bloc = build();
      bloc.add(
        const TransactionsStarted(
          context: TransactionContext.fromStatistics(
            excludeInternalTransfers: true,
          ),
        ),
      );
      final state = await ready();

      expect(state.rows, hasLength(2));
    });

    test('xoá chip ngữ cảnh thì danh sách rộng trở lại', () async {
      await tx(account: accountA, record: recordA1, day: 1);
      await tx(account: accountA, record: recordA2, day: 2);

      bloc = build();
      bloc.add(
        TransactionsStarted(
          context: TransactionContext.fromImport(
            recordId: recordA1,
            fileName: 'thang-01.csv',
          ),
        ),
      );
      await ready();
      expect(bloc.state.rows, hasLength(1));

      bloc.add(const TransactionsChipRemoved(FilterChipKind.importFile));
      final state = await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.rows.length == 2,
      );
      expect(state.totalCount, 2);
      expect(state.chips, isEmpty);
    });
  });

  group('bộ lọc', () {
    test('bản nháp sai giữ nguyên danh sách và báo lỗi theo từng ô', () async {
      await tx(account: accountA, record: recordA1, day: 1);
      bloc = build();
      bloc.add(const TransactionsStarted());
      await ready();

      bloc.add(
        const TransactionsFilterDraftChanged(
          TransactionFilterDraft(
            minAmountText: '5.000.000',
            maxAmountText: '1.000.000',
            currency: Currency.vnd,
          ),
        ),
      );
      bloc.add(const TransactionsFilterApplied());
      final state = await bloc.stream.firstWhere(
        (state) => state.validation != null,
      );

      expect(state.validation!.isValid, isFalse);
      expect(state.validation!.amountRangeError, isNotNull);
      // Danh sách **không** bị xoá vì một ô gõ sai.
      expect(state.rows, hasLength(1));
    });

    test('lọc theo tài khoản thu hẹp đúng và sinh chip', () async {
      await tx(account: accountA, record: recordA1, day: 1);
      await tx(account: accountB, record: recordB, day: 2);

      bloc = build();
      bloc.add(const TransactionsStarted());
      await ready();

      bloc
        ..add(
          TransactionsFilterDraftChanged(
            TransactionFilterDraft(accountId: accountB),
          ),
        )
        ..add(const TransactionsFilterApplied());
      final state = await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.filter.accountId == accountB,
      );

      expect(state.rows, hasLength(1));
      expect(
        state.chips.map((chip) => chip.kind),
        contains(FilterChipKind.account),
      );
    });
  });

  group('xoá giao dịch', () {
    test(
      'hỏi trước rằng cặp đối soát sẽ bị huỷ, rồi mới xoá',
      () async {
        final out = await tx(
          account: accountA,
          record: recordA1,
          amount: -2000000,
          day: 5,
        );
        final into = await tx(
          account: accountB,
          record: recordB,
          amount: 2000000,
          day: 5,
        );
        await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

        bloc = build();
        bloc.add(const TransactionsStarted());
        await ready();

        bloc.add(TransactionDeleteRequested(out));
        var state = await bloc.stream.firstWhere(
          (state) => state.pendingDelete != null,
        );
        // Con số phải có **trước** khi hộp thoại hiện lên.
        expect(state.pendingDelete!.cancelsReconciliation, isTrue);
        expect(db.transactionRows.containsKey(out), isTrue);

        bloc.add(const TransactionDeleteConfirmed());
        state = await bloc.stream.firstWhere(
          (state) => state.status.isReady && state.pendingDelete == null,
        );
        expect(db.transactionRows.containsKey(out), isFalse);
        expect(db.pairRows, isEmpty);
        expect(state.rows, hasLength(1));
      },
    );

    test('đóng hộp thoại thì không xoá gì', () async {
      final id = await tx(account: accountA, record: recordA1, day: 1);
      bloc = build();
      bloc.add(const TransactionsStarted());
      await ready();

      bloc.add(TransactionDeleteRequested(id));
      await bloc.stream.firstWhere((state) => state.pendingDelete != null);

      bloc.add(const TransactionDeleteDismissed());
      await bloc.stream.firstWhere((state) => state.pendingDelete == null);
      expect(db.transactionRows.containsKey(id), isTrue);
    });
  });

  group('chi tiết', () {
    test('chỉ báo "đã đối soát" đúng khi vào thẳng bằng định danh', () async {
      final out = await tx(
        account: accountA,
        record: recordA1,
        amount: -2000000,
        day: 5,
      );
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 2000000,
        day: 5,
      );
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      bloc = build();
      // Cố ý **không** gửi `TransactionsStarted`: đây là đường vào thẳng từ một
      // liên kết, khi danh sách chưa từng được nạp nên không có dòng nào để đọc
      // sẵn cờ đã đối soát.
      bloc.add(TransactionDetailRequested(out));
      final state = await bloc.stream.firstWhere(
        (state) => state.detailStatus == LoadStatus.ready,
      );

      expect(state.detail, isNotNull);
      expect(state.detail!.isReconciled, isTrue);
      expect(state.detail!.transactionId, out);
    });

    test('giao dịch đã biến mất thì báo và tải lại', () async {
      await tx(account: accountA, record: recordA1, day: 1);
      bloc = build();
      bloc.add(const TransactionsStarted());
      await ready();

      bloc.add(const TransactionDetailRequested(999999));
      final state = await bloc.stream.firstWhere(
        (state) => state.notice != null,
      );
      expect(state.detail, isNull);
    });
  });
}
