import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/presentation/shared/formatting/date_formatter.dart';
import 'package:ledger_tracer/presentation/shared/formatting/money_formatter.dart';
import 'package:ledger_tracer/presentation/shared/formatting/number_formatter.dart';

void main() {
  group('NumberFormatter.groupDigits', () {
    test('chèn dấu phân nhóm từ phải sang, mọi độ dài dư', () {
      expect(NumberFormatter.groupDigits('1'), '1');
      expect(NumberFormatter.groupDigits('123'), '123');
      expect(NumberFormatter.groupDigits('1234'), '1.234');
      expect(NumberFormatter.groupDigits('12345'), '12.345');
      expect(NumberFormatter.groupDigits('123456'), '123.456');
      expect(NumberFormatter.groupDigits('1234567'), '1.234.567');
    });
  });

  group('NumberFormatter.toDecimalInput', () {
    test('đọc được cả kiểu gõ Việt Nam lẫn kiểu bàn phím số', () {
      expect(NumberFormatter.toDecimalInput('1.234.567'), '1234567');
      expect(NumberFormatter.toDecimalInput('1234567,89'), '1234567.89');
      expect(NumberFormatter.toDecimalInput('1.234.567,89'), '1234567.89');
      expect(NumberFormatter.toDecimalInput('1234567.89'), '1234567.89');
    });

    test(
      'dấu chấm trước đúng ba chữ số là phân nhóm, không phải dấu thập phân',
      () {
        // Đây là chỗ nhập nhằng duy nhất giữa hai quy ước, và quy ước Việt Nam
        // thắng: "1.234" là một nghìn hai trăm ba mươi tư.
        expect(NumberFormatter.toDecimalInput('1.234'), '1234');
        expect(NumberFormatter.toDecimalInput('1.23'), '1.23');
        expect(NumberFormatter.toDecimalInput('1.2345'), '1.2345');
      },
    );

    test('giữ dấu âm và bỏ khoảng trắng', () {
      expect(NumberFormatter.toDecimalInput('  -1.000  '), '-1000');
      expect(NumberFormatter.toDecimalInput('+250'), '250');
    });

    test('trả null cho những gì không phải một số', () {
      expect(NumberFormatter.toDecimalInput(''), isNull);
      expect(NumberFormatter.toDecimalInput('   '), isNull);
      expect(NumberFormatter.toDecimalInput('-'), isNull);
      expect(NumberFormatter.toDecimalInput('abc'), isNull);
      expect(NumberFormatter.toDecimalInput('12a34'), isNull);
      expect(NumberFormatter.toDecimalInput(',50'), isNull);
    });

    test('đi trọn vòng với Money.fromDecimalString', () {
      final decimal = NumberFormatter.toDecimalInput('1.234.567,89')!;
      expect(
        Money.fromDecimalString(decimal, Currency.usd),
        Money(123456789, Currency.usd),
      );
    });
  });

  group('MoneyFormatter', () {
    test('luôn hiện dấu, và dấu trừ là U+2212 để cột số thẳng hàng', () {
      expect(
        MoneyFormatter.signed(Money(1500000, Currency.vnd)),
        '+1.500.000',
      );
      expect(
        MoneyFormatter.signed(Money(-1500000, Currency.vnd)),
        '−1.500.000',
      );
      // Số 0 không có chiều, và ký hiệu mặc định của nó là dấu cộng.
      expect(MoneyFormatter.signed(const Money.zero(Currency.vnd)), '+0');
    });

    test('phần thập phân theo đúng độ chính xác của loại tiền', () {
      expect(MoneyFormatter.signed(Money(123456, Currency.usd)), '+1.234,56');
      expect(MoneyFormatter.signed(Money(1234, Currency.vnd)), '+1.234');
    });

    test('dạng kèm loại tiền không bao giờ để số tiền đứng một mình', () {
      expect(
        MoneyFormatter.signedWithCurrency(Money(-2000, Currency.usd)),
        '−20,00 USD',
      );
      expect(
        MoneyFormatter.absoluteWithCurrency(Money(-2000, Currency.usd)),
        '20,00 USD',
      );
    });
  });

  group('DateFormatter', () {
    final date = DateTime.utc(2026, 9, 4);

    test('ngày theo quy ước Việt Nam, có đệm số 0', () {
      expect(DateFormatter.day(date), '04/09/2026');
      expect(DateFormatter.day(DateTime.utc(2026, 12, 25)), '25/12/2026');
    });

    test('nhãn cột nói đúng độ mịn đang chọn', () {
      expect(DateFormatter.period(date, CashFlowPeriod.day), '04/09/2026');
      expect(DateFormatter.period(date, CashFlowPeriod.month), '09/2026');
      expect(DateFormatter.period(date, CashFlowPeriod.year), '2026');
    });

    test('khoảng một ngày chỉ in một ngày', () {
      expect(
        DateFormatter.range(DateRange.singleDay(date)),
        '04/09/2026',
      );
      expect(
        DateFormatter.range(
          DateRange(from: date, to: DateTime.utc(2026, 9, 30)),
        ),
        '04/09/2026 – 30/09/2026',
      );
    });
  });
}
