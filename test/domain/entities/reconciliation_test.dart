import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/reconciliation_pair.dart';
import 'package:ledger_tracer/domain/entities/rejected_match.dart';
import 'package:ledger_tracer/domain/errors/reconciliation_errors.dart';
import 'package:ledger_tracer/domain/value_objects/pair_status.dart';

void main() {
  final createdAt = DateTime.utc(2025, 6, 1, 8);
  final confirmedAt = DateTime.utc(2025, 6, 2, 9);

  group('ReconciliationPair', () {
    ReconciliationPair suggested({int outgoing = 10, int incoming = 20}) =>
        ReconciliationPair.suggested(
          outgoingTransactionId: outgoing,
          incomingTransactionId: incoming,
          createdAt: createdAt,
        );

    test('cặp mới luôn ở trạng thái gợi ý, chưa có hiệu lực nghiệp vụ', () {
      final pair = suggested();
      expect(pair.status, PairStatus.suggested);
      expect(pair.isConfirmed, isFalse);
      expect(pair.confirmedAt, isNull);
      expect(pair.isPersisted, isFalse);
    });

    test('không thể ghép một giao dịch với chính nó', () {
      expect(
        () => suggested(outgoing: 10, incoming: 10),
        throwsA(isA<SelfPairError>()),
      );
    });

    test('giữ đúng chiều của hai vế', () {
      final pair = suggested(outgoing: 10, incoming: 20);
      expect(pair.outgoingTransactionId, 10);
      expect(pair.incomingTransactionId, 20);
      expect(pair.transactionIds, <int>[10, 20]);
    });

    test('involves nhận ra cả hai vế và chỉ hai vế đó', () {
      final pair = suggested(outgoing: 10, incoming: 20);
      expect(pair.involves(10), isTrue);
      expect(pair.involves(20), isTrue);
      expect(pair.involves(30), isFalse);
    });

    test('xác nhận chuyển trạng thái và ghi mốc thời gian', () {
      final confirmed = suggested().withIdentity(1).confirm(confirmedAt);
      expect(confirmed.status, PairStatus.confirmed);
      expect(confirmed.isConfirmed, isTrue);
      expect(confirmed.confirmedAt, confirmedAt);
      expect(confirmed.createdAt, createdAt);
      expect(confirmed.pairId, 1);
    });

    test('xác nhận là chuyển trạng thái một chiều — không xác nhận hai lần', () {
      // Đường lùi khi bấm nhầm là **từ chối**, không phải "bỏ xác nhận".
      final confirmed = suggested().withIdentity(1).confirm(confirmedAt);
      expect(
        () => confirmed.confirm(confirmedAt),
        throwsA(isA<PairAlreadyConfirmedError>()),
      );
    });

    test('chỉ cặp đã lưu mới xác nhận được', () {
      expect(() => suggested().confirm(confirmedAt), throwsA(isA<AssertionError>()));
    });

    test('bằng nhau theo định danh cặp', () {
      expect(suggested().withIdentity(1), suggested(outgoing: 99, incoming: 98).withIdentity(1));
      expect(suggested().withIdentity(1), isNot(suggested().withIdentity(2)));
      expect(suggested(), isNot(suggested()));
    });
  });

  group('RejectedMatch', () {
    test('luôn lưu hai định danh theo thứ tự tăng dần', () {
      // Cặp không có chiều; lưu chính tắc để một lần tra là đủ.
      final ab = RejectedMatch.between(
        transactionAId: 30,
        transactionBId: 10,
        rejectedAt: createdAt,
      );
      expect(ab.transactionAId, 10);
      expect(ab.transactionBId, 30);
    });

    test('hai chiều nhập vào cho cùng một bản ghi', () {
      final ab = RejectedMatch.between(
        transactionAId: 10,
        transactionBId: 30,
        rejectedAt: createdAt,
      );
      final ba = RejectedMatch.between(
        transactionAId: 30,
        transactionBId: 10,
        rejectedAt: createdAt,
      );
      expect(ab.key, ba.key);
      expect(ab.transactionAId, ba.transactionAId);
    });

    test('không thể từ chối một giao dịch với chính nó', () {
      expect(
        () => RejectedMatch.between(
          transactionAId: 5,
          transactionBId: 5,
          rejectedAt: createdAt,
        ),
        throwsA(isA<SelfPairError>()),
      );
    });

    test('dựng được từ một cặp đang tồn tại', () {
      final pair = ReconciliationPair.suggested(
        outgoingTransactionId: 42,
        incomingTransactionId: 7,
        createdAt: createdAt,
      );
      final rejection = RejectedMatch.forPair(pair, confirmedAt);
      expect(rejection.transactionAId, 7);
      expect(rejection.transactionBId, 42);
      expect(rejection.rejectedAt, confirmedAt);
    });

    test('involves nhận ra cả hai vế', () {
      final rejection = RejectedMatch.between(
        transactionAId: 10,
        transactionBId: 30,
        rejectedAt: createdAt,
      );
      expect(rejection.involves(10), isTrue);
      expect(rejection.involves(30), isTrue);
      expect(rejection.involves(20), isFalse);
    });

    group('keyOf — khoá chính tắc dùng chung với phía isolate', () {
      test('không phụ thuộc thứ tự hai đối số', () {
        expect(RejectedMatch.keyOf(10, 30), RejectedMatch.keyOf(30, 10));
      });

      test('khớp với key của bản ghi tương ứng', () {
        final rejection = RejectedMatch.between(
          transactionAId: 30,
          transactionBId: 10,
          rejectedAt: createdAt,
        );
        expect(rejection.key, RejectedMatch.keyOf(10, 30));
        expect(rejection.key, RejectedMatch.keyOf(30, 10));
      });

      test('hai cặp khác nhau cho hai khoá khác nhau', () {
        expect(RejectedMatch.keyOf(1, 2), isNot(RejectedMatch.keyOf(1, 3)));
        expect(RejectedMatch.keyOf(1, 2), isNot(RejectedMatch.keyOf(2, 3)));
      });

      test('không nhập nhằng giữa các định danh nhiều chữ số', () {
        // Ghép chuỗi thiếu dấu phân cách sẽ làm (1, 23) trùng với (12, 3).
        expect(RejectedMatch.keyOf(1, 23), isNot(RejectedMatch.keyOf(12, 3)));
        expect(RejectedMatch.keyOf(1, 234), isNot(RejectedMatch.keyOf(123, 4)));
      });
    });

    test('bằng nhau theo định danh bản ghi', () {
      final one = RejectedMatch.between(
        transactionAId: 1,
        transactionBId: 2,
        rejectedAt: createdAt,
      ).withIdentity(9);
      final other = RejectedMatch.between(
        transactionAId: 3,
        transactionBId: 4,
        rejectedAt: createdAt,
      ).withIdentity(9);
      expect(one, other);
      expect(one.isPersisted, isTrue);
    });
  });
}
