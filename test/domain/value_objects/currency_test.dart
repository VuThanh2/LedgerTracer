import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/errors/transaction_errors.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';

/// Số chữ số thập phân lấy theo ISO 4217, **không đoán từ dữ liệu**: đó là thứ
/// quyết định "1000.00" trong file là một nghìn đồng hay một trăm nghìn cent.
void main() {
  group('parse', () {
    test('chuẩn hoá hoa/thường và khoảng trắng', () {
      expect(Currency.parse('vnd').code, 'VND');
      expect(Currency.parse('  usd  ').code, 'USD');
    });

    test('lấy số chữ số thập phân theo bảng ISO 4217', () {
      expect(Currency.parse('VND').decimalDigits, 0);
      expect(Currency.parse('JPY').decimalDigits, 0);
      expect(Currency.parse('KRW').decimalDigits, 0);
      expect(Currency.parse('USD').decimalDigits, 2);
      expect(Currency.parse('EUR').decimalDigits, 2);
      expect(Currency.parse('KWD').decimalDigits, 3);
    });

    test('mặc định 2 chữ số cho mã hợp lệ nhưng không có trong bảng', () {
      expect(Currency.parse('GBP').decimalDigits, 2);
    });

    test('từ chối mọi mã không phải ba chữ cái', () {
      for (final raw in <String>['US', 'USDD', '', '12A', 'US-', 'us d']) {
        expect(
          () => Currency.parse(raw),
          throwsA(isA<InvalidCurrencyCodeError>()),
          reason: 'mã "$raw" phải bị từ chối',
        );
      }
    });
  });

  group('tryParse', () {
    test('trả null thay vì ném, kể cả với null đầu vào', () {
      expect(Currency.tryParse(null), isNull);
      expect(Currency.tryParse('nope'), isNull);
      expect(Currency.tryParse(''), isNull);
    });

    test('cho cùng kết quả với parse khi mã hợp lệ', () {
      expect(Currency.tryParse(' jpy '), Currency.jpy);
    });
  });

  test('minorUnitsPerUnit là luỹ thừa 10 của số chữ số thập phân', () {
    expect(Currency.vnd.minorUnitsPerUnit, 1);
    expect(Currency.usd.minorUnitsPerUnit, 100);
    expect(Currency.parse('KWD').minorUnitsPerUnit, 1000);
  });

  test('hằng dựng sẵn trùng khớp với kết quả parse', () {
    expect(Currency.parse('VND'), Currency.vnd);
    expect(Currency.parse('USD'), Currency.usd);
    expect(Currency.parse('EUR'), Currency.eur);
    expect(Currency.parse('JPY'), Currency.jpy);
    expect(Currency.fallback, Currency.vnd);
  });

  test('đẳng thức và băm chỉ dựa trên mã', () {
    expect(Currency.parse('vnd'), Currency.vnd);
    expect(Currency.parse('vnd').hashCode, Currency.vnd.hashCode);
    expect(Currency.usd, isNot(Currency.eur));
  });

  test('sắp xếp theo mã để danh sách loại tiền ổn định', () {
    final codes = <Currency>[Currency.usd, Currency.eur, Currency.vnd]..sort();
    expect(codes.map((c) => c.code).toList(), <String>['EUR', 'USD', 'VND']);
  });
}
