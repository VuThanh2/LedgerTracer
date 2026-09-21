import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/presentation/shared/formatting/amount_input_formatter.dart';
import 'package:ledger_tracer/presentation/shared/formatting/number_formatter.dart';

/// Mô phỏng người dùng: mỗi lượt là một thao tác trên bàn phím, áp lên giá trị
/// **đã được formatter định dạng** của lượt trước — đúng như TextField chạy.
TextEditingValue _type(
  AmountInputFormatter formatter,
  TextEditingValue current,
  String char,
) {
  final at = current.selection.extentOffset;
  final text =
      current.text.substring(0, at) + char + current.text.substring(at);
  return formatter.formatEditUpdate(
    current,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at + char.length),
    ),
  );
}

TextEditingValue _backspace(
  AmountInputFormatter formatter,
  TextEditingValue current,
) {
  final at = current.selection.extentOffset;
  final text = current.text.substring(0, at - 1) + current.text.substring(at);
  return formatter.formatEditUpdate(
    current,
    TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: at - 1),
    ),
  );
}

TextEditingValue _typeAll(AmountInputFormatter formatter, String keys) {
  // `TextEditingValue.empty` có selection -1 (chưa focus); ô vừa chạm vào thì
  // con trỏ ở 0.
  var value = _at('', 0);
  for (final char in keys.split('')) {
    value = _type(formatter, value, char);
  }
  return value;
}

TextEditingValue _at(String text, int caret) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret),
);

void main() {
  group('VND (không có phần thập phân)', () {
    final vnd = AmountInputFormatter(decimalDigits: 0);

    test('gõ chữ số: dấu phân nhóm tự chèn, con trỏ luôn ở cuối', () {
      final value = _typeAll(vnd, '1234567');
      expect(value.text, '1.234.567');
      expect(value.selection.extentOffset, value.text.length);
    });

    test('dấu chấm/phẩy tự gõ bị bỏ — VND không có phần lẻ', () {
      expect(_typeAll(vnd, '12.5').text, '125');
      expect(_typeAll(vnd, '12,5').text, '125');
    });

    test('số 0 ở đầu bị bỏ, nhưng một số 0 đứng một mình được giữ', () {
      expect(_typeAll(vnd, '0').text, '0');
      expect(_typeAll(vnd, '007').text, '7');
    });

    test('sửa ở giữa chuỗi: con trỏ đứng sau đúng chữ số vừa gõ', () {
      // 1.234.567, con trỏ sau "1.2" → gõ 9 → 12.934.567, con trỏ sau "12.9".
      final value = _type(vnd, _at('1.234.567', 3), '9');
      expect(value.text, '12.934.567');
      expect(value.text.substring(0, value.selection.extentOffset), '12.9');
    });

    test('xoá lùi vào dấu phân nhóm xoá luôn chữ số đứng trước nó', () {
      // Con trỏ ngay sau dấu chấm của "1.234": xoá thì mất số 1, không phải
      // một phím xoá không làm gì.
      final value = _backspace(vnd, _at('1.234', 2));
      expect(value.text, '234');
      expect(value.selection.extentOffset, 0);
    });

    test('xoá lùi thường: nhóm được xếp lại', () {
      final value = _backspace(vnd, _at('1.234', 5));
      expect(value.text, '123');
      expect(value.selection.extentOffset, 3);
    });

    test('dán số trần hoặc số đã phân nhóm kiểu Việt Nam', () {
      expect(
        vnd.formatEditUpdate(_at('', 0), _at('1234567', 7)).text,
        '1.234.567',
      );
      expect(
        vnd.formatEditUpdate(_at('', 0), _at('1.234.567,00', 12)).text,
        '1.234.567',
      );
    });

    test('kết quả luôn đọc lại được đúng con số bằng toDecimalInput', () {
      for (final keys in <String>['5', '1000', '1234567', '100000000']) {
        final text = _typeAll(vnd, keys).text;
        expect(NumberFormatter.toDecimalInput(text), keys);
      }
    });
  });

  group('USD (hai chữ số thập phân)', () {
    final usd = AmountInputFormatter(decimalDigits: 2);

    test('phím "." mở phần thập phân và hiện thành dấu phẩy', () {
      expect(_typeAll(usd, '1234.5').text, '1.234,5');
      expect(_typeAll(usd, '1234,56').text, '1.234,56');
    });

    test('phần thập phân bị chặn ở số chữ số của loại tiền', () {
      expect(_typeAll(usd, '1.567').text, '1,56');
    });

    test('chỉ có một dấu thập phân', () {
      expect(_typeAll(usd, '1.2.3').text, '1,23');
    });

    test('gõ dấu thập phân khi ô trống thành 0,', () {
      expect(_typeAll(usd, '.5').text, '0,5');
    });

    test('toDecimalInput đọc lại đúng — kể cả "1.234" không có phần lẻ', () {
      expect(
        NumberFormatter.toDecimalInput(_typeAll(usd, '1234').text),
        '1234',
      );
      expect(
        NumberFormatter.toDecimalInput(_typeAll(usd, '1234.5').text),
        '1234.5',
      );
    });

    test('dán "1234567.8912" bị chặn ở hai chữ số lẻ', () {
      final value = usd.formatEditUpdate(_at('', 0), _at('1234567.8912', 12));
      expect(value.text, '1.234.567,89');
    });
  });
}
