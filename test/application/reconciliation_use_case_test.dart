import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/reconciliation/confirm_pair/confirm_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/reject_pair/reject_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/run_reconciliation/run_reconciliation_dto.dart';
import 'package:ledger_tracer/application/reconciliation/run_reconciliation/run_reconciliation_use_case.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/domain/entities/rejected_match.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';
import 'package:ledger_tracer/domain/value_objects/pair_status.dart';

import '_support/fake_repositories.dart';
import '_support/seed.dart';

/// UC-08 và UC-09 nói cùng một điều từ hai phía: **gợi ý không phải xác nhận**.
/// Thuật toán ghép theo số tiền và cửa sổ thời gian chắc chắn sẽ trùng khớp ngẫu
/// nhiên với những giao dịch không liên quan, nên mọi hệ quả nghiệp vụ đều phải
/// chờ người dùng gật đầu.
void main() {
  late FakeDatabase db;
  late Seed seed;
  late RunReconciliationUseCase runReconciliation;
  late ConfirmPairUseCase confirmPair;
  late RejectPairUseCase rejectPair;
  late ListMatchAlternativesUseCase listPairs;

  late int accountA;
  late int accountB;
  late int accountC;
  late int recordA;
  late int recordB;
  late int recordC;

  final now = Seed.defaultNow;

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    runReconciliation = RunReconciliationUseCase(
      reconciliation: db.reconciliation,
      settings: db.settings,
      runner: const MainThreadRunner(PlatformCapabilities.web()),
      strategies: const StrategySelector(PlatformCapabilities.web()),
      now: () => now,
    );
    confirmPair = ConfirmPairUseCase(
      reconciliation: db.reconciliation,
      now: () => now,
    );
    rejectPair = RejectPairUseCase(
      reconciliation: db.reconciliation,
      unitOfWork: db.unitOfWork,
      now: () => now,
    );
    listPairs = ListMatchAlternativesUseCase(
      reconciliation: db.reconciliation,
      transactions: db.transactions,
      accounts: db.accounts,
      settings: db.settings,
    );

    accountA = await seed.account('A');
    accountB = await seed.account('B');
    accountC = await seed.account('C');
    recordA = await seed.fileRecord(accountId: accountA);
    recordB = await seed.fileRecord(accountId: accountB);
    recordC = await seed.fileRecord(accountId: accountC);
  });

  Future<int> outgoing({
    int account = 0,
    int record = 0,
    int amount = 500000,
    int day = 10,
    Currency currency = Currency.vnd,
  }) => seed.transaction(
    accountId: account == 0 ? accountA : account,
    recordId: record == 0 ? recordA : record,
    amount: -amount,
    bookingDate: DateTime.utc(2025, 3, day),
    currency: currency,
  );

  Future<int> incoming({
    int account = 0,
    int record = 0,
    int amount = 500000,
    int day = 10,
    Currency currency = Currency.vnd,
  }) => seed.transaction(
    accountId: account == 0 ? accountB : account,
    recordId: record == 0 ? recordB : record,
    amount: amount,
    bookingDate: DateTime.utc(2025, 3, day),
    currency: currency,
  );

  Future<RunReconciliationResult> scan({
    CancellationSignal? cancellation,
    void Function(ReconciliationProgress progress)? onProgress,
    ConcurrencyStrategy? strategy,
  }) async {
    final result = await runReconciliation.execute(
      RunReconciliationRequest(
        strategy: strategy ?? ConcurrencyStrategy.mainThread(batchSize: 2),
        cancellation: cancellation,
      ),
      onProgress: onProgress,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!;
  }

  group('quét đối soát', () {
    test('ghép hai vế đối nhau ở hai tài khoản khác nhau', () async {
      final out = await outgoing();
      final into = await incoming(day: 11);

      final result = await scan();

      expect(result.suggestedPairsFound, 1);
      expect(result.scannedTransactionCount, 2);
      final pair = db.pairRows.values.single;
      expect(pair.outgoingTransactionId, out);
      expect(pair.incomingTransactionId, into);
      expect(pair.status, PairStatus.suggested);
      expect(pair.createdAt, now);
    });

    test('không ghép hai giao dịch cùng tài khoản', () async {
      await outgoing(account: accountA, record: recordA);
      await seed.transaction(
        accountId: accountA,
        recordId: recordA,
        amount: 500000,
        bookingDate: DateTime.utc(2025, 3, 10),
      );
      expect((await scan()).suggestedPairsFound, 0);
    });

    test('không ghép hai loại tiền khác nhau', () async {
      await outgoing(currency: Currency.usd);
      await incoming();
      expect((await scan()).suggestedPairsFound, 0);
    });

    test('không ghép khi lệch ngày vượt cửa sổ', () async {
      await outgoing(day: 10);
      await incoming(day: 20);
      expect((await scan()).suggestedPairsFound, 0);
    });

    test('nới cửa sổ thì lần chạy sau ghép được cặp trước đó bị loại', () async {
      await outgoing(day: 10);
      await incoming(day: 15);
      expect((await scan()).suggestedPairsFound, 0);

      final widened = await runReconciliation.setMatchWindow(7);
      expect(widened.isOk, isTrue);
      expect((await scan()).suggestedPairsFound, 1);
    });

    test('mỗi giao dịch chỉ vào tối đa một cặp', () async {
      // Một vế chuyển ra với hai ứng viên nhận vào hợp lệ.
      await outgoing(day: 10);
      await incoming(day: 11);
      await incoming(account: accountC, record: recordC, day: 12);

      final result = await scan();
      expect(result.suggestedPairsFound, 1);
      final paired = db.pairRows.values.single.transactionIds.toSet();
      expect(paired.length, 2);
    });

    test('chọn ứng viên lệch ngày nhỏ nhất', () async {
      final out = await outgoing(day: 10);
      final far = await incoming(day: 13);
      final near = await incoming(account: accountC, record: recordC, day: 11);

      await scan();
      final pair = db.pairRows.values.single;
      expect(pair.outgoingTransactionId, out);
      expect(pair.incomingTransactionId, near);
      expect(pair.involves(far), isFalse);
    });

    test('lệch bằng nhau thì chọn theo định danh để kết quả lặp lại được', () async {
      final out = await outgoing(day: 10);
      final first = await incoming(day: 11);
      await incoming(account: accountC, record: recordC, day: 11);

      await scan();
      final pair = db.pairRows.values.single;
      expect(pair.outgoingTransactionId, out);
      expect(pair.incomingTransactionId, first);
    });

    test('không quét lại những giao dịch đã thuộc cặp đã xác nhận', () async {
      final out = await outgoing(day: 10);
      final into = await incoming(day: 10);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      final result = await scan();
      expect(result.scannedTransactionCount, 0);
      expect(result.suggestedPairsFound, 0);
    });
  });

  group('chạy lại', () {
    test('xoá sạch gợi ý cũ rồi tính lại, không tích luỹ trùng', () async {
      await outgoing(day: 10);
      await incoming(day: 11);

      final first = await scan();
      expect(first.suggestedPairsFound, 1);

      final second = await scan();
      expect(second.clearedSuggestions, 1);
      expect(second.suggestedPairsFound, 1);
      expect(db.pairRows.length, 1);
    });

    test('giữ nguyên mọi cặp đã xác nhận', () async {
      final out = await outgoing(day: 10);
      final into = await incoming(day: 11);
      await scan();
      final pairId = db.pairRows.keys.single;
      await confirmPair.execute(pairId);

      final again = await scan();
      expect(again.clearedSuggestions, 0);
      expect(db.pairRows[pairId]!.isConfirmed, isTrue);
      expect(db.pairRows[pairId]!.outgoingTransactionId, out);
      expect(db.pairRows[pairId]!.incomingTransactionId, into);
    });

    test('cặp đã bị từ chối không bao giờ được gợi ý lại', () async {
      // Phán quyết là thông tin về quá khứ; không nhớ thì mỗi lần chạy lại sẽ đề
      // xuất y nguyên cặp vừa bị từ chối và người dùng không có đường thoát.
      await outgoing(day: 10);
      await incoming(day: 11);
      await scan();
      final pairId = db.pairRows.keys.single;
      expect((await rejectPair.execute(pairId)).isOk, isTrue);

      final again = await scan();
      expect(again.suggestedPairsFound, 0);
      expect(db.pairRows, isEmpty);
      expect(db.rejectionRows.length, 1);
    });

    test('từ chối một cặp không chặn hai vế ghép với đối tác khác', () async {
      final out = await outgoing(day: 10);
      final rejectedPartner = await incoming(day: 10);
      await seed.rejection(aId: out, bId: rejectedPartner);
      final otherPartner = await incoming(
        account: accountC,
        record: recordC,
        day: 12,
      );

      await scan();
      final pair = db.pairRows.values.single;
      expect(pair.outgoingTransactionId, out);
      expect(pair.incomingTransactionId, otherPartner);
    });

    test('gỡ phán quyết thì lần chạy kế tiếp gợi ý lại', () async {
      await outgoing(day: 10);
      await incoming(day: 11);
      await scan();
      final pairId = db.pairRows.keys.single;
      final rejection = await rejectPair.execute(pairId);
      expect((await scan()).suggestedPairsFound, 0);

      final undo = await rejectPair.undo(
        rejection.valueOrNull!.rejectedMatchId!,
      );
      expect(undo.isOk, isTrue);
      expect((await scan()).suggestedPairsFound, 1);
    });
  });

  group('huỷ và tiến trình', () {
    test('huỷ giữa chừng giữ lại các cặp đã ghi', () async {
      for (var i = 0; i < 6; i++) {
        await outgoing(day: 10 + i, amount: 100000 + i);
        await incoming(day: 10 + i, amount: 100000 + i);
      }
      final cancellation = CancellationSignal();
      final result = await scan(
        cancellation: cancellation,
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
        onProgress: (progress) {
          if (progress.pairsFound >= 1) cancellation.cancel();
        },
      );

      expect(result.wasCancelled, isTrue);
      expect(db.pairRows, isNotEmpty);
      expect(db.pairRows.length, lessThan(6));
    });

    test('báo tiến trình có tỷ lệ và số cặp tìm được tới lúc đó', () async {
      await outgoing(day: 10);
      await incoming(day: 10);
      final reports = <ReconciliationProgress>[];
      await scan(onProgress: reports.add);

      expect(reports, isNotEmpty);
      // Báo cáo đầu tiên phát ra trước cả khi nạp dữ liệu, để thanh tiến trình
      // hiện ra ngay thay vì đứng im chờ một truy vấn dài.
      expect(reports.first.processed, 0);
      expect(reports.first.total, 2);
      expect(reports.last.processed, 2);
      expect(reports.last.fraction, 1.0);
      expect(reports.last.pairsFound, 1);
    });

    test('không có giao dịch nào thì vẫn chạy trót lọt', () async {
      final result = await scan();
      expect(result.suggestedPairsFound, 0);
      expect(result.scannedTransactionCount, 0);
    });
  });

  group('xác nhận và từ chối', () {
    late int pairId;

    setUp(() async {
      final out = await outgoing(day: 10);
      final into = await incoming(day: 11);
      pairId = await seed.pair(outgoingId: out, incomingId: into);
    });

    test('xác nhận chuyển trạng thái và ghi mốc thời gian', () async {
      final result = await confirmPair.execute(pairId);
      expect(result.isOk, isTrue);
      expect(db.pairRows[pairId]!.status, PairStatus.confirmed);
      expect(db.pairRows[pairId]!.confirmedAt, now);
    });

    test('xác nhận hai lần bị chặn — không có thao tác bỏ xác nhận', () async {
      await confirmPair.execute(pairId);
      final again = await confirmPair.execute(pairId);
      expect(again.failureOrNull, isA<ValidationFailure>());
    });

    test('xác nhận một cặp không tồn tại báo không tìm thấy', () async {
      final result = await confirmPair.execute(999999);
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('từ chối xoá cặp và ghi lại phán quyết trong cùng một transaction', () async {
      final before = db.unitOfWork.committed;
      final result = await rejectPair.execute(pairId);

      expect(result.isOk, isTrue);
      expect(db.pairRows, isEmpty);
      expect(db.rejectionRows.length, 1);
      expect(db.unitOfWork.committed, before + 1);
    });

    test('phán quyết ghi lại đúng hai vế, theo thứ tự chính tắc', () async {
      final pair = db.pairRows[pairId]!;
      await rejectPair.execute(pairId);
      final rejection = db.rejectionRows.values.single;
      expect(
        rejection.key,
        RejectedMatch.keyOf(
          pair.outgoingTransactionId,
          pair.incomingTransactionId,
        ),
      );
      expect(rejection.rejectedAt, now);
    });

    test('từ chối được cả cặp đã xác nhận, không cần thao tác riêng', () async {
      // Một nút chỉ mang một ý nghĩa; đường lùi khi bấm nhầm là gỡ phán quyết.
      await confirmPair.execute(pairId);
      final result = await rejectPair.execute(pairId);
      expect(result.isOk, isTrue);
      expect(db.pairRows, isEmpty);
    });

    test('từ chối một cặp không tồn tại báo không tìm thấy', () async {
      expect(
        (await rejectPair.execute(999999)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });

    test('gỡ một phán quyết không tồn tại báo lỗi thay vì im lặng', () async {
      // Đây là màn hình người dùng vào để sửa một cái bấm nhầm, nên "đã gỡ xong"
      // phải là sự thật.
      expect(
        (await rejectPair.undo(999999)).failureOrNull,
        isA<NotFoundFailure>(),
      );
    });
  });

  group('danh sách ứng viên tính lại lúc hiển thị', () {
    test('dùng đúng điều kiện của lần quét, không lệch đi', () async {
      final out = await outgoing(day: 10);
      final chosen = await incoming(day: 11);
      final alternative = await incoming(
        account: accountC,
        record: recordC,
        day: 12,
      );
      final pairId = await seed.pair(outgoingId: out, incomingId: chosen);

      final view = await listPairs.alternativesForPair(pairId);
      expect(view.isOk, isTrue);
      expect(
        view.valueOrNull!.alternativesForOutgoing
            .map((tx) => tx.transactionId)
            .toList(),
        <int>[alternative],
      );
    });

    test('không gợi ý lại vế đang nằm trong chính cặp đang xem', () async {
      final out = await outgoing(day: 10);
      final chosen = await incoming(day: 11);
      final pairId = await seed.pair(outgoingId: out, incomingId: chosen);

      final view = await listPairs.alternativesForPair(pairId);
      expect(view.valueOrNull!.alternativesForOutgoing, isEmpty);
      expect(view.valueOrNull!.hasAlternatives, isFalse);
    });

    test('không gợi ý giao dịch đang thuộc một cặp khác', () async {
      // Một giao dịch chỉ được ghép vào tối đa một cặp; gợi ý một dòng đã ghép
      // là mời người dùng làm một việc hệ thống sẽ từ chối.
      final out = await outgoing(day: 10);
      final chosen = await incoming(day: 11);
      final pairId = await seed.pair(outgoingId: out, incomingId: chosen);

      final busyOut = await outgoing(account: accountC, record: recordC, day: 12);
      final busyIn = await incoming(account: accountC, record: recordC, day: 12);
      await seed.pair(outgoingId: busyOut, incomingId: busyIn);

      final view = await listPairs.alternativesForPair(pairId);
      expect(
        view.valueOrNull!.alternativesForOutgoing
            .map((tx) => tx.transactionId),
        isNot(contains(busyIn)),
      );
    });

    test('không gợi ý lại cặp người dùng đã từ chối', () async {
      // Thiếu tầng lọc này thì từ chối xong vẫn thấy đúng cặp ấy trong danh sách
      // ứng viên, và không có đường nào ra khỏi vòng lặp đó.
      final out = await outgoing(day: 10);
      final chosen = await incoming(day: 11);
      final refused = await incoming(account: accountC, record: recordC, day: 12);
      final pairId = await seed.pair(outgoingId: out, incomingId: chosen);
      await seed.rejection(aId: out, bId: refused);

      final view = await listPairs.alternativesForPair(pairId);
      expect(view.valueOrNull!.alternativesForOutgoing, isEmpty);
    });

    test('phán quyết của vế này không loại ứng viên của vế kia', () async {
      final out = await outgoing(day: 10);
      final chosen = await incoming(day: 11);
      final pairId = await seed.pair(outgoingId: out, incomingId: chosen);
      final otherOut = await outgoing(account: accountC, record: recordC, day: 11);
      // Từ chối cặp (out, otherOut) — vốn không hợp lệ — không được ảnh hưởng
      // tới danh sách ứng viên của vế nhận vào.
      await seed.rejection(aId: out, bId: otherOut);

      final view = await listPairs.alternativesForPair(pairId);
      expect(
        view.valueOrNull!.alternativesForIncoming
            .map((tx) => tx.transactionId)
            .toList(),
        <int>[otherOut],
      );
    });

    test('kèm độ lệch ngày và tên hai tài khoản để đọc hiểu được', () async {
      final out = await outgoing(day: 10);
      final into = await incoming(day: 13);
      final pairId = await seed.pair(outgoingId: out, incomingId: into);

      final view = await listPairs.alternativesForPair(pairId);
      final pairView = view.valueOrNull!.pair;
      expect(pairView.driftInDays, 3);
      expect(pairView.outgoingAccountName, 'A');
      expect(pairView.incomingAccountName, 'B');
    });
  });

  group('danh sách cặp và phán quyết', () {
    test('lọc được theo trạng thái', () async {
      final out1 = await outgoing(day: 10);
      final in1 = await incoming(day: 10);
      final out2 = await outgoing(account: accountC, record: recordC, day: 12);
      final in2 = await incoming(day: 12);
      await seed.pair(outgoingId: out1, incomingId: in1, confirmed: true);
      await seed.pair(outgoingId: out2, incomingId: in2);

      final confirmed = await listPairs.pairs(
        status: PairStatus.confirmed,
        limit: 10,
        offset: 0,
      );
      expect(confirmed.valueOrNull!.totalCount, 1);
      expect(confirmed.valueOrNull!.items.single.pair.isConfirmed, isTrue);

      final all = await listPairs.pairs(limit: 10, offset: 0);
      expect(all.valueOrNull!.totalCount, 2);
    });

    test('danh sách đã từ chối kèm hai vế còn tồn tại', () async {
      final out = await outgoing(day: 10);
      final into = await incoming(day: 10);
      await seed.rejection(aId: out, bId: into);

      final rejected = await listPairs.rejected(limit: 10, offset: 0);
      final view = rejected.valueOrNull!.items.single;
      expect(view.transactionA, isNotNull);
      expect(view.transactionB, isNotNull);
      expect(rejected.valueOrNull!.hasMore, isFalse);
    });
  });

  group('ngưỡng lệch thời gian', () {
    test('đọc ra được và mặc định là ±3 ngày', () async {
      final window = await runReconciliation.currentMatchWindow();
      expect(window.valueOrNull, MatchWindow.standard);
    });

    test('đổi được và lưu lại', () async {
      expect((await runReconciliation.setMatchWindow(7)).isOk, isTrue);
      expect(db.settings.current.matchWindow, MatchWindow(7));
      expect(
        (await runReconciliation.currentMatchWindow()).valueOrNull,
        MatchWindow(7),
      );
    });

    test('từ chối ngưỡng nhỏ hơn một ngày', () async {
      final result = await runReconciliation.setMatchWindow(0);
      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(db.settings.current.matchWindow, MatchWindow.standard);
    });

    test('đổi ngưỡng không đụng tới cặp đã xác nhận', () async {
      // Cửa sổ là tham số dò tìm; cặp đã xác nhận mang phán quyết của người dùng.
      final out = await outgoing(day: 10);
      final into = await incoming(day: 11);
      final pairId = await seed.pair(
        outgoingId: out,
        incomingId: into,
        confirmed: true,
      );
      await runReconciliation.setMatchWindow(1);
      expect(db.pairRows[pairId]!.isConfirmed, isTrue);
    });
  });
}
