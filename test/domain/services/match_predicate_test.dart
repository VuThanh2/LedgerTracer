import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/services/match_predicate.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';

/// Vị từ ghép cặp là **nơi duy nhất** định nghĩa một cặp hợp lệ, dùng chung cho
/// lần quét theo lô và cho danh sách ứng viên tính lại lúc hiển thị. Hai bản sao
/// của cùng điều kiện sẽ lệch nhau, và người dùng sẽ thấy một ứng viên có ở màn
/// hình này mà không có ở màn hình kia.
///
/// Test dùng một cài đặt [MatchCandidate] tối giản chứ không dùng `Transaction`:
/// chính khả năng đó là thứ cho phép phía isolate chạy cùng vị từ trên dòng rút
/// gọn của nó.
final class _Row implements MatchCandidate {
  const _Row(this.transactionId, this.accountId, this.bookingDate, this.amount);

  @override
  final int? transactionId;
  @override
  final int accountId;
  @override
  final DateTime bookingDate;
  @override
  final Money amount;
}

void main() {
  final day = DateTime.utc(2025, 7, 10);
  final window = MatchWindow.standard;

  _Row row({
    int id = 1,
    int account = 1,
    int dayOffset = 0,
    int minorUnits = -500000,
    Currency currency = Currency.vnd,
  }) => _Row(
    id,
    account,
    day.add(Duration(days: dayOffset)),
    Money(minorUnits, currency),
  );

  group('canPair', () {
    test('ghép khi khác tài khoản, số tiền đối nhau, trong cửa sổ', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(id: 2, account: 2, minorUnits: 500000, dayOffset: 1);
      expect(MatchPredicate.canPair(out, into, window), isTrue);
      expect(MatchPredicate.canPair(into, out, window), isTrue);
    });

    test('không ghép hai giao dịch cùng tài khoản', () {
      // Chuyển tiền nội bộ theo định nghĩa là giữa **hai** tài khoản.
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(id: 2, account: 1, minorUnits: 500000);
      expect(MatchPredicate.canPair(out, into, window), isFalse);
    });

    test('không ghép hai giao dịch cùng chiều', () {
      final a = row(id: 1, account: 1, minorUnits: -500000);
      final b = row(id: 2, account: 2, minorUnits: -500000);
      expect(MatchPredicate.canPair(a, b, window), isFalse);
    });

    test('không ghép hai số tiền lệch nhau dù chỉ một đơn vị nhỏ nhất', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(id: 2, account: 2, minorUnits: 500001);
      expect(MatchPredicate.canPair(out, into, window), isFalse);
    });

    test('không ghép hai loại tiền khác nhau', () {
      // Chuyển tiền nội bộ có đổi loại tiền nằm ngoài phạm vi đối soát.
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(
        id: 2,
        account: 2,
        minorUnits: 500000,
        currency: Currency.usd,
      );
      expect(MatchPredicate.canPair(out, into, window), isFalse);
    });

    test('không ghép hai giao dịch 0 đồng', () {
      final a = row(id: 1, account: 1, minorUnits: 0);
      final b = row(id: 2, account: 2, minorUnits: 0);
      expect(MatchPredicate.canPair(a, b, window), isFalse);
    });

    test('đúng ngưỡng cửa sổ vẫn ghép, vượt một ngày thì không', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      expect(
        MatchPredicate.canPair(
          out,
          row(id: 2, account: 2, minorUnits: 500000, dayOffset: 3),
          window,
        ),
        isTrue,
      );
      expect(
        MatchPredicate.canPair(
          out,
          row(id: 2, account: 2, minorUnits: 500000, dayOffset: 4),
          window,
        ),
        isFalse,
      );
    });

    test('cửa sổ tính cả hai chiều thời gian', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      expect(
        MatchPredicate.canPair(
          out,
          row(id: 2, account: 2, minorUnits: 500000, dayOffset: -3),
          window,
        ),
        isTrue,
      );
    });

    test('nới cửa sổ thì cặp trước đó bị loại lại ghép được', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(id: 2, account: 2, minorUnits: 500000, dayOffset: 5);
      expect(MatchPredicate.canPair(out, into, window), isFalse);
      expect(MatchPredicate.canPair(out, into, MatchWindow(5)), isTrue);
    });
  });

  group('driftInDays', () {
    test('không âm và không phụ thuộc thứ tự', () {
      final a = row(id: 1);
      final b = row(id: 2, dayOffset: -2);
      expect(MatchPredicate.driftInDays(a, b), 2);
      expect(MatchPredicate.driftInDays(b, a), 2);
    });

    test('cùng ngày cho 0', () {
      expect(MatchPredicate.driftInDays(row(id: 1), row(id: 2)), 0);
    });
  });

  group('alternativesFor', () {
    test('chỉ giữ ứng viên hợp lệ', () {
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      final candidates = <_Row>[
        row(id: 2, account: 2, minorUnits: 500000, dayOffset: 1), // hợp lệ
        row(id: 3, account: 1, minorUnits: 500000), // cùng tài khoản
        row(id: 4, account: 2, minorUnits: -500000), // cùng chiều
        row(id: 5, account: 2, minorUnits: 500000, dayOffset: 9), // ngoài cửa sổ
      ];
      final result = MatchPredicate.alternativesFor(anchor, candidates, window);
      expect(result.map((r) => r.transactionId).toList(), <int>[2]);
    });

    test('xếp ứng viên lệch ngày nhỏ nhất lên đầu', () {
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      final candidates = <_Row>[
        row(id: 2, account: 2, minorUnits: 500000, dayOffset: 3),
        row(id: 3, account: 2, minorUnits: 500000, dayOffset: 1),
        row(id: 4, account: 2, minorUnits: 500000, dayOffset: 2),
      ];
      final result = MatchPredicate.alternativesFor(anchor, candidates, window);
      expect(result.map((r) => r.transactionId).toList(), <int>[3, 4, 2]);
    });

    test('lệch bằng nhau thì xếp theo định danh để kết quả lặp lại được', () {
      // Đây là điều kiện để hai lần chạy trên cùng dữ liệu cho cùng kết quả.
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      final candidates = <_Row>[
        row(id: 9, account: 2, minorUnits: 500000, dayOffset: 1),
        row(id: 4, account: 2, minorUnits: 500000, dayOffset: 1),
        row(id: 7, account: 2, minorUnits: 500000, dayOffset: -1),
      ];
      final result = MatchPredicate.alternativesFor(anchor, candidates, window);
      expect(result.map((r) => r.transactionId).toList(), <int>[4, 7, 9]);
    });

    test('thứ tự đầu vào không ảnh hưởng kết quả', () {
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      final a = row(id: 5, account: 2, minorUnits: 500000, dayOffset: 2);
      final b = row(id: 6, account: 2, minorUnits: 500000, dayOffset: 1);
      expect(
        MatchPredicate.alternativesFor(anchor, <_Row>[a, b], window)
            .map((r) => r.transactionId)
            .toList(),
        MatchPredicate.alternativesFor(anchor, <_Row>[b, a], window)
            .map((r) => r.transactionId)
            .toList(),
      );
    });

    test('không có ứng viên nào thì trả danh sách rỗng', () {
      expect(
        MatchPredicate.alternativesFor(row(), const <_Row>[], window),
        isEmpty,
      );
    });
  });

  group('bestMatchFor', () {
    test('chính là ứng viên đầu tiên của alternativesFor', () {
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      final candidates = <_Row>[
        row(id: 2, account: 2, minorUnits: 500000, dayOffset: 3),
        row(id: 3, account: 2, minorUnits: 500000, dayOffset: 1),
      ];
      expect(
        MatchPredicate.bestMatchFor(anchor, candidates, window)?.transactionId,
        MatchPredicate.alternativesFor(
          anchor,
          candidates,
          window,
        ).first.transactionId,
      );
    });

    test('trả null khi không ứng viên nào hợp lệ', () {
      final anchor = row(id: 1, account: 1, minorUnits: -500000);
      expect(
        MatchPredicate.bestMatchFor(
          anchor,
          <_Row>[row(id: 2, account: 1, minorUnits: 500000)],
          window,
        ),
        isNull,
      );
    });
  });

  group('orient', () {
    test('vế âm luôn là vế chuyển ra, bất kể thứ tự đối số', () {
      final out = row(id: 1, account: 1, minorUnits: -500000);
      final into = row(id: 2, account: 2, minorUnits: 500000);

      final (outgoingA, incomingA) = MatchPredicate.orient(out, into);
      expect(outgoingA.transactionId, 1);
      expect(incomingA.transactionId, 2);

      final (outgoingB, incomingB) = MatchPredicate.orient(into, out);
      expect(outgoingB.transactionId, 1);
      expect(incomingB.transactionId, 2);
    });
  });
}
