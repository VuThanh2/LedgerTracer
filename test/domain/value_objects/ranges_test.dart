import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/errors/reconciliation_errors.dart';
import 'package:ledger_tracer/domain/errors/transaction_errors.dart';
import 'package:ledger_tracer/domain/value_objects/amount_range.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';

void main() {
  group('DateRange', () {
    test('cắt bỏ phần giờ để lọc theo ngày là lọc theo ngày', () {
      final range = DateRange(
        from: DateTime(2025, 1, 10, 23, 30),
        to: DateTime(2025, 1, 20, 1, 15),
      );
      expect(range.from, DateTime.utc(2025, 1, 10));
      expect(range.to, DateTime.utc(2025, 1, 20));
    });

    test('bao gồm cả hai đầu mút', () {
      final range = DateRange(
        from: DateTime.utc(2025, 1, 10),
        to: DateTime.utc(2025, 1, 20),
      );
      expect(range.contains(DateTime.utc(2025, 1, 10)), isTrue);
      expect(range.contains(DateTime.utc(2025, 1, 20)), isTrue);
      expect(range.contains(DateTime.utc(2025, 1, 15)), isTrue);
      expect(range.contains(DateTime.utc(2025, 1, 9)), isFalse);
      expect(range.contains(DateTime.utc(2025, 1, 21)), isFalse);
    });

    test('cuối ngày cuối cùng vẫn nằm trong khoảng', () {
      // Không cắt giờ thì mọi giao dịch trong ngày cuối bị lọc mất.
      final range = DateRange(
        from: DateTime.utc(2025, 1, 10),
        to: DateTime.utc(2025, 1, 20),
      );
      expect(range.contains(DateTime.utc(2025, 1, 20, 23, 59, 59)), isTrue);
    });

    test('từ chối khoảng ngược', () {
      expect(
        () => DateRange(
          from: DateTime.utc(2025, 2, 1),
          to: DateTime.utc(2025, 1, 1),
        ),
        throwsA(isA<InvalidDateRangeError>()),
      );
    });

    test('cùng ngày là khoảng hợp lệ dài đúng một ngày', () {
      final day = DateRange.singleDay(DateTime(2025, 5, 5, 8));
      expect(day.lengthInDays, 1);
      expect(day.contains(DateTime(2025, 5, 5, 22)), isTrue);
    });

    test('lengthInDays đếm cả hai đầu mút', () {
      final range = DateRange(
        from: DateTime.utc(2025, 1, 1),
        to: DateTime.utc(2025, 1, 31),
      );
      expect(range.lengthInDays, 31);
    });

    test('daysBetween có dấu và bỏ qua phần giờ', () {
      expect(
        DateRange.daysBetween(DateTime.utc(2025, 1, 1), DateTime.utc(2025, 1, 4)),
        3,
      );
      expect(
        DateRange.daysBetween(DateTime.utc(2025, 1, 4), DateTime.utc(2025, 1, 1)),
        -3,
      );
      expect(
        DateRange.daysBetween(
          DateTime.utc(2025, 1, 1, 23),
          DateTime.utc(2025, 1, 2, 1),
        ),
        1,
      );
    });

    test('daysBetween không bị lệch bởi giờ địa phương', () {
      // dateOnly quy về UTC nên hai mốc giờ địa phương cùng ngày vẫn cách 0
      // ngày, kể cả khi máy chạy ở múi giờ có DST.
      expect(
        DateRange.daysBetween(
          DateTime(2025, 3, 30, 1),
          DateTime(2025, 3, 30, 23),
        ),
        0,
      );
    });

    test('đẳng thức theo hai đầu mút đã chuẩn hoá', () {
      expect(
        DateRange(from: DateTime(2025, 1, 1, 9), to: DateTime(2025, 1, 2, 18)),
        DateRange(from: DateTime(2025, 1, 1), to: DateTime(2025, 1, 2)),
      );
    });
  });

  group('AmountRange', () {
    test('bao gồm cả hai đầu mút', () {
      final range = AmountRange(
        min: const Money(1000, Currency.vnd),
        max: const Money(5000, Currency.vnd),
      );
      expect(range.contains(const Money(1000, Currency.vnd)), isTrue);
      expect(range.contains(const Money(5000, Currency.vnd)), isTrue);
      expect(range.contains(const Money(999, Currency.vnd)), isFalse);
      expect(range.contains(const Money(5001, Currency.vnd)), isFalse);
    });

    test('một khoảng số tiền luôn mang theo loại tiền của nó', () {
      final range = AmountRange(
        min: const Money(1000, Currency.vnd),
        max: const Money(5000, Currency.vnd),
      );
      expect(range.currency, Currency.vnd);
    });

    test('không lọc nhầm giao dịch của loại tiền khác', () {
      // "từ 1 triệu đến 5 triệu" không được vơ luôn 1.000 USD.
      final range = AmountRange(
        min: const Money(1000000, Currency.vnd),
        max: const Money(5000000, Currency.vnd),
      );
      expect(range.contains(const Money(2000000, Currency.usd)), isFalse);
    });

    test('từ chối khoảng trộn hai loại tiền', () {
      expect(
        () => AmountRange(
          min: const Money(0, Currency.vnd),
          max: const Money(1, Currency.usd),
        ),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });

    test('từ chối khoảng ngược', () {
      expect(
        () => AmountRange(
          min: const Money(5000, Currency.vnd),
          max: const Money(1000, Currency.vnd),
        ),
        throwsA(isA<InvalidAmountRangeError>()),
      );
    });

    test('min bằng max là khoảng hợp lệ của đúng một giá trị', () {
      final exact = AmountRange(
        min: const Money(42, Currency.vnd),
        max: const Money(42, Currency.vnd),
      );
      expect(exact.contains(const Money(42, Currency.vnd)), isTrue);
      expect(exact.contains(const Money(43, Currency.vnd)), isFalse);
    });

    test('atLeast mở về phía trên và vẫn nhận số âm nếu đủ lớn', () {
      final range = AmountRange.atLeast(const Money(0, Currency.vnd));
      expect(range.contains(const Money(999999999, Currency.vnd)), isTrue);
      expect(range.contains(const Money(-1, Currency.vnd)), isFalse);
    });

    test('atMost mở về phía dưới, bao cả tiền ra', () {
      final range = AmountRange.atMost(const Money(0, Currency.vnd));
      expect(range.contains(const Money(-999999999, Currency.vnd)), isTrue);
      expect(range.contains(const Money(1, Currency.vnd)), isFalse);
    });
  });

  group('MatchWindow', () {
    test('mặc định là ±3 ngày', () {
      expect(MatchWindow.standard.days, 3);
    });

    test('bao gồm đúng ngưỡng và loại thứ vượt ngưỡng', () {
      final window = MatchWindow(3);
      final anchor = DateTime.utc(2025, 6, 10);
      expect(window.covers(anchor, DateTime.utc(2025, 6, 13)), isTrue);
      expect(window.covers(anchor, DateTime.utc(2025, 6, 7)), isTrue);
      expect(window.covers(anchor, DateTime.utc(2025, 6, 14)), isFalse);
      expect(window.covers(anchor, DateTime.utc(2025, 6, 6)), isFalse);
    });

    test('không phụ thuộc thứ tự hai mốc', () {
      final window = MatchWindow(2);
      final a = DateTime.utc(2025, 6, 10);
      final b = DateTime.utc(2025, 6, 12);
      expect(window.covers(a, b), window.covers(b, a));
      expect(window.driftBetween(a, b), window.driftBetween(b, a));
    });

    test('cùng ngày lệch 0', () {
      expect(
        MatchWindow(1).driftBetween(
          DateTime.utc(2025, 6, 10, 8),
          DateTime.utc(2025, 6, 10, 20),
        ),
        0,
      );
    });

    test('từ chối ngưỡng nhỏ hơn một ngày', () {
      expect(() => MatchWindow(0), throwsA(isA<InvalidMatchWindowError>()));
      expect(() => MatchWindow(-1), throwsA(isA<InvalidMatchWindowError>()));
    });

    test('một ngày là ngưỡng nhỏ nhất hợp lệ', () {
      expect(MatchWindow(1).days, 1);
    });

    test('đẳng thức theo số ngày', () {
      expect(MatchWindow(3), MatchWindow.standard);
      expect(MatchWindow(3).hashCode, MatchWindow.standard.hashCode);
      expect(MatchWindow(4), isNot(MatchWindow.standard));
    });
  });
}
