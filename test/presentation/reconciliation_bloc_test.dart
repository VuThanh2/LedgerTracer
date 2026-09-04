import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/accounts/manage_accounts/manage_accounts_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/confirm_pair/confirm_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/reject_pair/reject_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/run_reconciliation/run_reconciliation_use_case.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/presentation/reconciliation/bloc/reconciliation_bloc.dart';
import 'package:ledger_tracer/presentation/reconciliation/bloc/reconciliation_event.dart';
import 'package:ledger_tracer/presentation/reconciliation/bloc/reconciliation_state.dart';
import 'package:ledger_tracer/presentation/reconciliation/view_models/reconciliation_group.dart';

import '_support/presentation_fixtures.dart';

void main() {
  late FakeDatabase db;
  late Seed seed;
  late ReconciliationBloc bloc;

  late int accountA;
  late int accountB;
  late int recordA;
  late int recordB;

  const capabilities = PlatformCapabilities.web();
  final now = Seed.defaultNow;

  ReconciliationBloc build() => ReconciliationBloc(
    runReconciliation: RunReconciliationUseCase(
      reconciliation: db.reconciliation,
      settings: db.settings,
      runner: const MainThreadRunner(capabilities),
      strategies: const StrategySelector(capabilities),
      now: () => now,
    ),
    listPairs: ListMatchAlternativesUseCase(
      reconciliation: db.reconciliation,
      transactions: db.transactions,
      accounts: db.accounts,
      settings: db.settings,
    ),
    confirmPair: ConfirmPairUseCase(
      reconciliation: db.reconciliation,
      now: () => now,
    ),
    rejectPair: RejectPairUseCase(
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
      now: () => now,
    ),
    manageAccounts: ManageAccountsUseCase(
      accounts: db.accounts,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      now: () => now,
    ),
    viewCashFlow: ViewCashFlowUseCase(
      transactions: db.transactions,
      accounts: db.accounts,
    ),
    capabilities: capabilities,
  );

  Future<ReconciliationState> ready() =>
      bloc.stream.firstWhere((state) => state.status.isReady);

  /// Một cặp chuyển tiền nội bộ thật: hai vế đối dấu, cùng ngày, khác tài khoản.
  Future<(int, int)> transferPair({int day = 10, int amount = 2000000}) async {
    final out = await seed.transaction(
      accountId: accountA,
      recordId: recordA,
      amount: -amount,
      bookingDate: DateTime.utc(2025, 3, day),
    );
    final into = await seed.transaction(
      accountId: accountB,
      recordId: recordB,
      amount: amount,
      bookingDate: DateTime.utc(2025, 3, day),
    );
    return (out, into);
  }

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    accountA = await seed.account('Vietinbank vận hành');
    accountB = await seed.account('Ví thu hộ');
    recordA = await seed.fileRecord(accountId: accountA);
    recordB = await seed.fileRecord(accountId: accountB);
  });

  tearDown(() => bloc.close());

  group('tiền điều kiện', () {
    test('dưới hai tài khoản có giao dịch thì không chạy được', () async {
      await seed.transaction(
        accountId: accountA,
        recordId: recordA,
        amount: -100000,
        bookingDate: DateTime.utc(2025, 3, 1),
      );

      bloc = build();
      bloc.add(const ReconciliationStarted());
      final state = await ready();

      // Tài khoản B đã khai báo nhưng chưa có giao dịch nào — khai báo không
      // phải là có dữ liệu, và đối soát cần hai tài khoản **có giao dịch**.
      expect(state.accountsWithTransactions, 1);
      expect(state.canRun, isFalse);
    });

    test('đủ hai tài khoản có giao dịch thì chạy được', () async {
      await transferPair();

      bloc = build();
      bloc.add(const ReconciliationStarted());
      final state = await ready();

      expect(state.accountsWithTransactions, 2);
      expect(state.canRun, isTrue);
    });

    test(
      'tài khoản mà mọi giao dịch đều đã đối soát vẫn được tính',
      () async {
        // Đây là chỗ dễ sai nhất: nếu phép đếm loại trừ giao dịch nội bộ thì màn
        // hình sẽ báo "chưa đủ tài khoản" ngay sau một lần đối soát thành công.
        final (out, into) = await transferPair();
        await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

        bloc = build();
        bloc.add(const ReconciliationStarted());
        final state = await ready();

        expect(state.accountsWithTransactions, 2);
        expect(state.canRun, isTrue);
      },
    );
  });

  group('chạy đối soát', () {
    test('lượt chạy đầu tìm ra cặp và đưa vào nhóm Chờ quyết định', () async {
      await transferPair();

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();

      bloc.add(const ReconciliationRunRequested());
      final state = await bloc.stream.firstWhere(
        (state) => state.lastRun != null && state.status.isReady,
      );

      expect(state.lastRun!.suggestedPairsFound, 1);
      expect(state.pendingCount, 1);
      expect(state.group, ReconciliationGroup.pending);
      expect(state.pairs, hasLength(1));
    });

    test(
      'chạy lại khi nhóm Chờ quyết định khác rỗng phải cảnh báo trước',
      () async {
        await transferPair();

        bloc = build();
        bloc.add(const ReconciliationStarted());
        await ready();
        bloc.add(const ReconciliationRunRequested());
        await bloc.stream.firstWhere(
          (state) => state.status.isReady && state.pendingCount == 1,
        );

        // Lần bấm thứ hai chỉ dựng cảnh báo — chưa có gì bị xoá.
        bloc.add(const ReconciliationRunRequested());
        var state = await bloc.stream.firstWhere(
          (state) =>
              state.runPhase == ReconciliationRunPhase.awaitingConfirmation,
        );
        expect(state.runWouldClearPending, isTrue);
        expect(db.pairRows, hasLength(1));

        // Đóng cảnh báo cũng không chạy.
        bloc.add(const ReconciliationRunDismissed());
        state = await bloc.stream.firstWhere(
          (state) => state.runPhase == ReconciliationRunPhase.idle,
        );
        expect(db.pairRows, hasLength(1));
      },
    );

    test('chạy lại giữ cặp đã xác nhận, xoá cặp còn chờ', () async {
      final (out1, in1) = await transferPair(day: 10);
      await transferPair(day: 20, amount: 3000000);

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();
      bloc.add(const ReconciliationRunRequested());
      await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.pendingCount == 2,
      );

      final confirmedId = db.pairRows.values
          .firstWhere(
            (pair) =>
                pair.outgoingTransactionId == out1 &&
                pair.incomingTransactionId == in1,
          )
          .pairId!;
      bloc.add(ReconciliationPairConfirmed(confirmedId));
      await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.confirmedCount == 1,
      );

      bloc.add(
        const ReconciliationRunRequested(acknowledgedClearingPending: true),
      );
      final state = await bloc.stream.firstWhere(
        (state) => state.lastRun != null && state.status.isReady,
      );

      // Cặp đã xác nhận sống sót qua mọi lần chạy lại; gợi ý thì bị tính lại từ
      // đầu, nên tổng số cặp vẫn là hai chứ không tích luỹ thành ba.
      expect(state.confirmedCount, 1);
      expect(db.pairRows.values.where((pair) => pair.isConfirmed), hasLength(1));
      expect(db.pairRows, hasLength(2));
    });
  });

  group('phán quyết', () {
    test('từ chối xoá cặp, ghi phán quyết, và cho hoàn tác', () async {
      await transferPair();

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();
      bloc.add(const ReconciliationRunRequested());
      await bloc.stream.firstWhere(
          (state) => state.status.isReady && state.pendingCount == 1,
        );

      final pairId = db.pairRows.keys.single;
      bloc.add(ReconciliationPairRejected(pairId));
      var state = await bloc.stream.firstWhere(
        (state) => state.undoableRejectionId != null,
      );

      expect(db.pairRows, isEmpty);
      expect(db.rejectionRows, hasLength(1));
      state = await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.rejectedCount == 1,
      );
      expect(state.pendingCount, 0);

      bloc.add(
        ReconciliationRejectionUndone(state.undoableRejectionId!),
      );
      state = await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.rejectedCount == 0,
      );

      // Gỡ phán quyết **không** dựng lại cặp: nó chỉ trở lại làm ứng viên ở lần
      // chạy kế tiếp.
      expect(db.rejectionRows, isEmpty);
      expect(db.pairRows, isEmpty);
    });

    test('cặp đã từ chối không được gợi ý lại ở lần chạy sau', () async {
      await transferPair();

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();
      bloc.add(const ReconciliationRunRequested());
      await bloc.stream.firstWhere(
          (state) => state.status.isReady && state.pendingCount == 1,
        );

      bloc.add(ReconciliationPairRejected(db.pairRows.keys.single));
      await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.rejectedCount == 1,
      );

      // Lượt chạy thứ hai: `lastRun` của lượt đầu đã khác null, nên mốc chờ phải
      // là "một kết quả **khác**", không phải "có kết quả".
      final firstRun = bloc.state.lastRun;
      bloc.add(const ReconciliationRunRequested());
      final state = await bloc.stream.firstWhere(
        (state) =>
            state.status.isReady && !identical(state.lastRun, firstRun),
      );
      expect(state.lastRun!.suggestedPairsFound, 0);
      expect(state.pendingCount, 0);
    });

    test('xác nhận chuyển cặp sang nhóm Đã xác nhận', () async {
      await transferPair();

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();
      bloc.add(const ReconciliationRunRequested());
      await bloc.stream.firstWhere(
          (state) => state.status.isReady && state.pendingCount == 1,
        );

      bloc.add(ReconciliationPairConfirmed(db.pairRows.keys.single));
      final state = await bloc.stream.firstWhere(
        (state) => state.status.isReady && state.confirmedCount == 1,
      );
      expect(state.pendingCount, 0);
      // Dòng biến mất khỏi danh sách đang xem ngay, không đợi một lượt đọc lại.
      expect(state.pairs, isEmpty);
    });
  });

  group('ngưỡng lệch', () {
    test('đổi ngưỡng chỉ ảnh hưởng lần chạy sau', () async {
      final (out, into) = await transferPair();
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();

      bloc.add(const ReconciliationMatchWindowChanged(7));
      final state = await bloc.stream.firstWhere(
        (state) => state.matchWindowDays == 7,
      );

      expect((await db.settings.load()).matchWindow.days, 7);
      // Cặp đã xác nhận không bị đụng tới: cửa sổ là tham số dò tìm, còn cặp đã
      // xác nhận là phán quyết của người dùng.
      expect(state.confirmedCount, 1);
      expect(db.pairRows.values.single.isConfirmed, isTrue);
    });

    test('ngưỡng không hợp lệ báo lỗi và giữ nguyên giá trị cũ', () async {
      bloc = build();
      bloc.add(const ReconciliationStarted());
      await ready();
      final before = bloc.state.matchWindowDays;

      bloc.add(const ReconciliationMatchWindowChanged(0));
      final state = await bloc.stream.firstWhere(
        (state) => state.notice != null,
      );
      expect(state.matchWindowDays, before);
    });
  });

  group('nhóm Đã từ chối', () {
    test('chạm trần nạp thì số đếm được đánh dấu là cận dưới', () async {
      // Nhóm này được đếm bằng cách nạp trọn rồi đếm — giả định "bảng này không
      // bao giờ lớn". Trần là chỗ giả định ấy được nói thành lời thay vì âm thầm
      // hiển thị một con số cụt.
      for (var i = 0; i < 3; i++) {
        final (out, into) = await transferPair(day: 10 + i, amount: 1000 + i);
        await seed.rejection(aId: out, bId: into);
      }

      bloc = ReconciliationBloc(
        runReconciliation: RunReconciliationUseCase(
          reconciliation: db.reconciliation,
          settings: db.settings,
          runner: const MainThreadRunner(capabilities),
          strategies: const StrategySelector(capabilities),
          now: () => now,
        ),
        listPairs: ListMatchAlternativesUseCase(
          reconciliation: db.reconciliation,
          transactions: db.transactions,
          accounts: db.accounts,
          settings: db.settings,
        ),
        confirmPair: ConfirmPairUseCase(
          reconciliation: db.reconciliation,
          now: () => now,
        ),
        rejectPair: RejectPairUseCase(
          reconciliation: db.reconciliation,
          unitOfWork: db.unitOfWork,
          now: () => now,
        ),
        manageAccounts: ManageAccountsUseCase(
          accounts: db.accounts,
          transactions: db.transactions,
          reconciliation: db.reconciliation,
          imports: db.imports,
          unitOfWork: db.unitOfWork,
          now: () => now,
        ),
        viewCashFlow: ViewCashFlowUseCase(
          transactions: db.transactions,
          accounts: db.accounts,
        ),
        capabilities: capabilities,
        pageSize: 1,
        maxRejectedRows: 2,
      );
      bloc.add(const ReconciliationStarted());
      final state = await ready();

      expect(state.rejectedCount, 2);
      expect(state.rejectedCountIsCapped, isTrue);
    });

    test('nạp hết trong trần thì số đếm là con số đúng', () async {
      final (out, into) = await transferPair();
      await seed.rejection(aId: out, bId: into);

      bloc = build();
      bloc.add(const ReconciliationStarted());
      final state = await ready();

      expect(state.rejectedCount, 1);
      expect(state.rejectedCountIsCapped, isFalse);
    });
  });

  test('Web được đánh dấu là không có isolate', () async {
    bloc = build();
    bloc.add(const ReconciliationStarted());
    final state = await ready();
    expect(state.supportsIsolates, isFalse);
  });
}
