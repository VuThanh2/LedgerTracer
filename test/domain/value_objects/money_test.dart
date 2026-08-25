import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/errors/transaction_errors.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';

/// Money là chỗ Rule – Money Is a Signed Integer sống hay chết. Hai chức năng
/// cốt lõi của ứng dụng — chống trùng và đối soát — đều so sánh số tiền **bằng
/// nhau tuyệt đối**, nên mọi phép làm tròn âm thầm ở đây đều biến thành một giao
/// dịch trùng lọt lưới hoặc một cặp đúng không ghép được.
void main() {
  group('Money.fromDecimalString', () {
    test('đọc số nguyên cho loại tiền không có phần thập phân', () {
      expect(Money.fromDecimalString('1000', Currency.vnd).minorUnits, 1000);
    });

    test('quy đổi phần thập phân sang đơn vị nhỏ nhất của loại tiền', () {
      expect(Money.fromDecimalString('10.50', Currency.usd).minorUnits, 1050);
      expect(Money.fromDecimalString('0.05', Currency.usd).minorUnits, 5);
    });

    test('bù đủ số chữ số thập phân khi nguồn ghi thiếu', () {
      expect(Money.fromDecimalString('10.5', Currency.usd).minorUnits, 1050);
      expect(Money.fromDecimalString('10', Currency.usd).minorUnits, 1000);
    });

    test('giữ dấu âm và chấp nhận dấu cộng tường minh', () {
      expect(Money.fromDecimalString('-10.50', Currency.usd).minorUnits, -1050);
      expect(Money.fromDecimalString('+10.50', Currency.usd).minorUnits, 1050);
    });

    test('bỏ khoảng trắng thừa hai đầu', () {
      expect(Money.fromDecimalString('  12  ', Currency.vnd).minorUnits, 12);
    });

    // Đây là ví dụ ghi thẳng trong Business Rules: cùng chuỗi "1,000,000.00"
    // nhưng VND là một triệu đồng còn USD là một trăm nghìn cent.
    test('cùng một chuỗi cho hai giá trị khác nhau ở hai loại tiền', () {
      expect(Money.fromDecimalString('1000.00', Currency.vnd).minorUnits, 1000);
      expect(
        Money.fromDecimalString('1000.00', Currency.usd).minorUnits,
        100000,
      );
    });

    test('bỏ được phần thập phân toàn số 0 vì nó không đổi giá trị', () {
      expect(Money.fromDecimalString('1000.00', Currency.vnd).minorUnits, 1000);
      expect(Money.fromDecimalString('12.5000', Currency.usd).minorUnits, 1250);
    });

    test('từ chối làm tròn khi phần bị cắt mang giá trị thật', () {
      expect(
        () => Money.fromDecimalString('1000.50', Currency.vnd),
        throwsA(isA<AmountPrecisionError>()),
      );
      expect(
        () => Money.fromDecimalString('10.005', Currency.usd),
        throwsA(isA<AmountPrecisionError>()),
      );
    });

    test('từ chối các chuỗi không phải số thập phân thuần', () {
      for (final raw in <String>['1,000', '', 'abc', '.5', '10.', '1 000']) {
        expect(
          () => Money.fromDecimalString(raw, Currency.vnd),
          throwsA(isA<MalformedAmountError>()),
          reason: 'chuỗi "$raw" phải bị từ chối',
        );
      }
    });
  });

  group('Money.toDecimalString', () {
    test('không thêm dấu chấm cho loại tiền không có phần thập phân', () {
      expect(const Money(1000, Currency.vnd).toDecimalString(), '1000');
      expect(const Money(-1000, Currency.vnd).toDecimalString(), '-1000');
    });

    test('luôn đủ số chữ số thập phân, kể cả khi phần nguyên là 0', () {
      expect(const Money(1050, Currency.usd).toDecimalString(), '10.50');
      expect(const Money(5, Currency.usd).toDecimalString(), '0.05');
      expect(const Money(0, Currency.usd).toDecimalString(), '0.00');
      expect(const Money(-5, Currency.usd).toDecimalString(), '-0.05');
    });

    test('đi trọn vòng với fromDecimalString', () {
      for (final raw in <String>['0.00', '10.50', '-0.05', '999999.99']) {
        expect(
          Money.fromDecimalString(raw, Currency.usd).toDecimalString(),
          raw,
        );
      }
    });

    test('toString luôn kèm mã loại tiền', () {
      expect(const Money(1050, Currency.usd).toString(), '10.50 USD');
    });
  });

  group('số học', () {
    test('cộng trừ trong cùng loại tiền', () {
      const a = Money(1000, Currency.vnd);
      const b = Money(250, Currency.vnd);
      expect((a + b).minorUnits, 1250);
      expect((a - b).minorUnits, 750);
      expect((-a).minorUnits, -1000);
      expect(a.absolute.minorUnits, 1000);
      expect((-a).absolute.minorUnits, 1000);
    });

    test('từ chối mọi phép trộn hai loại tiền', () {
      const vnd = Money(1000, Currency.vnd);
      const usd = Money(1000, Currency.usd);
      expect(() => vnd + usd, throwsA(isA<CurrencyMismatchError>()));
      expect(() => vnd - usd, throwsA(isA<CurrencyMismatchError>()));
      expect(() => vnd.compareTo(usd), throwsA(isA<CurrencyMismatchError>()));
      expect(() => vnd < usd, throwsA(isA<CurrencyMismatchError>()));
    });

    test('cộng dồn số lớn không tích luỹ sai số', () {
      // Với double, cộng 0.1 mười lần đã lệch. Số nguyên thì không.
      var total = const Money(0, Currency.usd);
      for (var i = 0; i < 1000000; i++) {
        total = total + const Money(10, Currency.usd);
      }
      expect(total.minorUnits, 10000000);
    });

    test('so sánh theo thứ tự số học', () {
      const small = Money(-100, Currency.vnd);
      const large = Money(100, Currency.vnd);
      expect(small < large, isTrue);
      expect(large > small, isTrue);
      expect(small <= small, isTrue);
      expect(large >= large, isTrue);
    });
  });

  group('chiều tiền và phép đối nhau', () {
    test('dấu quyết định chiều, không có cột loại giao dịch riêng', () {
      expect(const Money(1, Currency.vnd).isIncoming, isTrue);
      expect(const Money(-1, Currency.vnd).isOutgoing, isTrue);
      expect(const Money.zero(Currency.vnd).isZero, isTrue);
      expect(const Money.zero(Currency.vnd).isIncoming, isFalse);
      expect(const Money.zero(Currency.vnd).isOutgoing, isFalse);
    });

    test('hai vế của một cặp phải đối nhau và cùng loại tiền', () {
      const outgoing = Money(-5000, Currency.vnd);
      const incoming = Money(5000, Currency.vnd);
      expect(outgoing.isOppositeOf(incoming), isTrue);
      expect(incoming.isOppositeOf(outgoing), isTrue);
    });

    test('khác loại tiền thì không bao giờ đối nhau', () {
      // Chuyển tiền nội bộ có đổi loại tiền nằm ngoài phạm vi đối soát.
      expect(
        const Money(-5000, Currency.vnd).isOppositeOf(
          const Money(5000, Currency.usd),
        ),
        isFalse,
      );
    });

    test('số 0 không đối nhau với chính nó', () {
      // Nếu không chặn, mọi giao dịch 0 đồng ở hai tài khoản khác nhau sẽ
      // được ghép thành cặp.
      expect(
        const Money.zero(Currency.vnd).isOppositeOf(
          const Money.zero(Currency.vnd),
        ),
        isFalse,
      );
    });

    test('cùng dấu thì không đối nhau', () {
      expect(
        const Money(5000, Currency.vnd).isOppositeOf(
          const Money(5000, Currency.vnd),
        ),
        isFalse,
      );
    });
  });

  group('đẳng thức', () {
    test('bằng nhau khi cùng giá trị và cùng loại tiền', () {
      expect(const Money(100, Currency.vnd), const Money(100, Currency.vnd));
      expect(
        const Money(100, Currency.vnd).hashCode,
        const Money(100, Currency.vnd).hashCode,
      );
    });

    test('cùng con số nhưng khác loại tiền là hai giá trị khác nhau', () {
      expect(
        const Money(100, Currency.vnd),
        isNot(const Money(100, Currency.usd)),
      );
    });
  });
}
