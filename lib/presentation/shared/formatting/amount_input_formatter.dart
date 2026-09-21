import 'package:flutter/services.dart';

import 'number_formatter.dart';

/// Tự chèn dấu phân nhóm hàng nghìn **trong lúc gõ**, như ô nhập số tiền của app
/// ngân hàng: gõ `1234567` thấy ngay `1.234.567`.
///
/// Người dùng chỉ gõ chữ số. Dấu chấm phân nhóm do formatter đặt, nên không còn
/// cảnh tự canh dấu chấm cho đúng chỗ — và cũng không còn chuỗi `12.34.567`
/// mà `NumberFormatter.toDecimalInput` đọc ra một con số khác thứ người dùng
/// nghĩ.
///
/// Phần thập phân (chỉ khi loại tiền có, như USD) được mở bằng một phím `,`
/// **hoặc** `.`: bàn phím số Android thường chỉ có một trong hai, và ở ô này
/// dấu chấm người dùng tự gõ không thể là dấu phân nhóm nữa. Nó luôn hiện ra
/// thành `,` — đúng hình dạng `MoneyFormatter.plain` đổ vào ô lúc mở form, nên
/// chuỗi ban đầu và chuỗi đang gõ là cùng một định dạng. Số chữ số sau dấu phẩy
/// bị chặn ở [decimalDigits] thay vì để lúc lưu mới báo lỗi.
///
/// Chọn cách này thay cho kiểu "máy ATM" (gõ `1234` thành `12,34`): với VND —
/// loại tiền của gần như mọi dòng — hai cách là một, còn với USD kiểu ATM làm
/// việc sửa một chữ số ở giữa chuỗi trở nên khó đoán.
///
/// Formatter chỉ lo hình dạng chuỗi; đọc chuỗi thành `Money` vẫn là việc của
/// `TransactionEditDraft.validate`.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({required this.decimalDigits});

  /// Số chữ số thập phân của loại tiền, lấy từ `Currency.decimalDigits`.
  final int decimalDigits;

  static final RegExp _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    var caret = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;

    // Xoá lùi đúng vào một dấu phân nhóm: formatter sẽ đặt lại nó ngay, nên
    // phím xoá trông như không làm gì. Xoá luôn chữ số đứng trước nó — đúng
    // thứ người dùng muốn khi bấm xoá.
    final removedOne =
        oldValue.text.length == text.length + 1 &&
        oldValue.selection.isCollapsed &&
        oldValue.selection.extentOffset == caret + 1 &&
        oldValue.text[caret] == NumberFormatter.groupSeparator;
    if (removedOne && caret > 0) {
      text = text.substring(0, caret - 1) + text.substring(caret);
      caret -= 1;
    }

    // Dán cả một chuỗi số (`1234567.89`, `1.234.567,89`): đọc bằng đúng luật
    // của phần lọc rồi định dạng lại, con trỏ về cuối.
    final inserted = text.length - oldValue.text.length;
    if (inserted > 1) {
      final decimal = NumberFormatter.toDecimalInput(text.replaceAll('-', ''));
      if (decimal != null) {
        final dotAt = decimal.indexOf('.');
        final formatted = _compose(
          dotAt < 0 ? decimal : decimal.substring(0, dotAt),
          dotAt < 0 || decimalDigits == 0
              ? null
              : _clip(decimal.substring(dotAt + 1)),
        );
        return TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }

    // Vị trí dấu thập phân trong chuỗi thô: dấu phẩy luôn là dấu thập phân;
    // dấu chấm chỉ là dấu thập phân khi nó **vừa được gõ** — mọi dấu chấm khác
    // là dấu phân nhóm cũ, sắp được đặt lại.
    var decimalAt = -1;
    if (decimalDigits > 0) {
      decimalAt = text.indexOf(NumberFormatter.decimalSeparator);
      final typedOne = inserted == 1 && caret > 0;
      if (decimalAt < 0 &&
          typedOne &&
          text[caret - 1] == NumberFormatter.groupSeparator) {
        decimalAt = caret - 1;
      }
    }

    final integerRaw = decimalAt < 0 ? text : text.substring(0, decimalAt);
    final fractionRaw = decimalAt < 0 ? null : text.substring(decimalAt + 1);

    // Bỏ số 0 vô nghĩa ở đầu (`007` → `7`); toàn số 0 thì còn lại một số 0.
    final allDigits = integerRaw.replaceAll(_nonDigit, '');
    final significant = allDigits.replaceFirst(RegExp('^0+'), '');
    var integerDigits = significant.isEmpty && allDigits.isNotEmpty
        ? '0'
        : significant;
    final strippedZeros = allDigits.length - integerDigits.length;
    // Gõ dấu phẩy khi ô còn trống: `,5` thành `0,5`.
    if (integerDigits.isEmpty && fractionRaw != null) integerDigits = '0';

    final fraction = fractionRaw == null
        ? null
        : _clip(fractionRaw.replaceAll(_nonDigit, ''));

    final formatted = _compose(integerDigits, fraction);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _caretIn(
          formatted,
          text: text,
          caret: caret,
          decimalAt: decimalAt,
          strippedZeros: strippedZeros,
          fractionLength: fraction?.length ?? 0,
        ),
      ),
    );
  }

  String _clip(String fractionDigits) => fractionDigits.length > decimalDigits
      ? fractionDigits.substring(0, decimalDigits)
      : fractionDigits;

  String _compose(String integerDigits, String? fraction) {
    final grouped = NumberFormatter.groupDigits(integerDigits);
    return fraction == null
        ? grouped
        : '$grouped${NumberFormatter.decimalSeparator}$fraction';
  }

  /// Đặt con trỏ sau **đúng số chữ số** mà nó đứng sau trong chuỗi thô — dấu
  /// phân nhóm thêm vào hay mất đi không được làm con trỏ trôi.
  static int _caretIn(
    String formatted, {
    required String text,
    required int caret,
    required int decimalAt,
    required int strippedZeros,
    required int fractionLength,
  }) {
    final commaAt = formatted.indexOf(NumberFormatter.decimalSeparator);
    if (decimalAt >= 0 && caret > decimalAt) {
      final digitsAfter = text
          .substring(decimalAt + 1, caret)
          .replaceAll(_nonDigit, '')
          .length;
      return commaAt +
          1 +
          (digitsAfter < fractionLength ? digitsAfter : fractionLength);
    }

    final integerEnd = commaAt < 0 ? formatted.length : commaAt;
    var wanted =
        text.substring(0, caret).replaceAll(_nonDigit, '').length -
        strippedZeros;
    if (wanted <= 0) return 0;
    for (var i = 0; i < integerEnd; i++) {
      if (formatted[i] != NumberFormatter.groupSeparator) wanted--;
      if (wanted == 0) return i + 1;
    }
    return integerEnd;
  }
}
