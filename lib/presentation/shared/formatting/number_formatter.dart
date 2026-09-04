/// Định dạng số nguyên theo quy ước Việt Nam: dấu chấm phân nhóm hàng nghìn.
///
/// Tự viết thay vì kéo `intl` vào là một lựa chọn có lý do. Ứng dụng chỉ có
/// **một** locale, và thứ cần định dạng luôn là chuỗi chữ số **đã chính xác
/// tuyệt đối** do `Money.toDecimalString()` sinh ra — đẩy nó qua `NumberFormat`
/// nghĩa là đi vòng qua `double`, đúng thứ mà `Money` tồn tại để tránh
/// (Rule – Money Is a Signed Integer, Never a Floating-Point Number).
///
/// Vì vậy mọi hàm ở đây làm việc trên **chuỗi chữ số**, không trên số: chúng
/// chèn dấu phân cách chứ không tính toán lại, nên không có bước nào để mất
/// chính xác.
abstract final class NumberFormatter {
  /// Dấu phân nhóm hàng nghìn.
  static const String groupSeparator = '.';

  /// Dấu thập phân.
  static const String decimalSeparator = ',';

  /// `1234567` → `1.234.567`. Dùng cho mọi con số đếm được (số giao dịch, số
  /// dòng lỗi, số cặp) — cùng một quy ước với số tiền để bảng không có hai kiểu
  /// đọc số.
  static String count(int value) {
    final digits = value.abs().toString();
    return '${value < 0 ? '-' : ''}${groupDigits(digits)}';
  }

  /// Chèn dấu phân nhóm vào một chuỗi **chỉ gồm chữ số**, tính từ phải sang.
  static String groupDigits(String digits) {
    if (digits.length <= 3) return digits;
    final buffer = StringBuffer();
    final firstGroupLength = digits.length % 3 == 0 ? 3 : digits.length % 3;
    buffer.write(digits.substring(0, firstGroupLength));
    for (var i = firstGroupLength; i < digits.length; i += 3) {
      buffer
        ..write(groupSeparator)
        ..write(digits.substring(i, i + 3));
    }
    return buffer.toString();
  }

  /// Đường ngược của [groupDigits] và [decimalSeparator], để đọc lại thứ người
  /// dùng vừa gõ vào ô lọc số tiền.
  ///
  /// Trả về dạng thập phân trần mà `Money.fromDecimalString` nhận (`-1234.56`),
  /// hoặc `null` khi chuỗi không phải một số đọc được. Nhận cả hai kiểu gõ —
  /// `1.234.567,89` lẫn `1234567.89` — vì bàn phím số trên Android không có dấu
  /// phẩy và người dùng sẽ gõ dấu chấm.
  static String? toDecimalInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final sign = trimmed.startsWith('-') ? '-' : '';
    final body = trimmed.replaceFirst(RegExp(r'^[+-]'), '');
    if (body.isEmpty) return null;

    // Dấu phân cách cuối cùng là dấu thập phân **chỉ khi** nó là dấu phẩy, hoặc
    // là dấu chấm mà phần sau nó không dài đúng 3 chữ số. `1.234` là một nghìn
    // hai trăm ba mươi tư, không phải một phẩy hai ba tư — quy ước Việt Nam
    // thắng ở chỗ nhập nhằng này.
    final lastComma = body.lastIndexOf(',');
    final lastDot = body.lastIndexOf('.');
    final int decimalAt;
    if (lastComma >= 0) {
      decimalAt = lastComma;
    } else if (lastDot >= 0 && body.length - lastDot - 1 != 3) {
      decimalAt = lastDot;
    } else {
      decimalAt = -1;
    }

    final integerPart = (decimalAt < 0 ? body : body.substring(0, decimalAt))
        .replaceAll(RegExp(r'[.,\s]'), '');
    final fractionPart = decimalAt < 0
        ? ''
        : body.substring(decimalAt + 1).replaceAll(RegExp(r'\s'), '');

    if (integerPart.isEmpty || !_digitsOnly.hasMatch(integerPart)) return null;
    if (fractionPart.isNotEmpty && !_digitsOnly.hasMatch(fractionPart)) {
      return null;
    }
    return fractionPart.isEmpty
        ? '$sign$integerPart'
        : '$sign$integerPart.$fractionPart';
  }

  static final RegExp _digitsOnly = RegExp(r'^\d+$');
}
