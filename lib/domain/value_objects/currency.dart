import '../errors/transaction_errors.dart';

/// Mã tiền tệ ISO 4217 kèm số chữ số thập phân xác định đơn vị nhỏ nhất của nó.
///
/// Số chữ số lấy theo chuẩn, không đoán từ dữ liệu: `1,000,000.00` trong sao kê
/// VND là một triệu đồng (0 chữ số), còn `1,000.00` trong sao kê USD là một trăm
/// nghìn cent (2 chữ số).
final class Currency implements Comparable<Currency> {
  const Currency._(this.code, this.decimalDigits);

  /// Ném [InvalidCurrencyCodeError] nếu [code] không phải 3 chữ cái.
  factory Currency.parse(String code) {
    final normalized = code.trim().toUpperCase();
    if (!_codePattern.hasMatch(normalized)) {
      throw InvalidCurrencyCodeError(code);
    }
    return Currency._(normalized, _decimalDigitsByCode[normalized] ?? 2);
  }

  /// Như [Currency.parse] nhưng trả `null` thay vì ném — dùng trong parser, nơi
  /// một ô không đọc được phải thành dòng lỗi chứ không thành exception.
  static Currency? tryParse(String? code) {
    if (code == null) return null;
    final normalized = code.trim().toUpperCase();
    if (!_codePattern.hasMatch(normalized)) return null;
    return Currency._(normalized, _decimalDigitsByCode[normalized] ?? 2);
  }

  static const Currency vnd = Currency._('VND', 0);
  static const Currency usd = Currency._('USD', 2);
  static const Currency eur = Currency._('EUR', 2);
  static const Currency jpy = Currency._('JPY', 0);

  /// Dùng khi định dạng nguồn không nêu loại tiền (UC-02).
  static const Currency fallback = vnd;

  final String code;

  final int decimalDigits;

  /// Bao nhiêu đơn vị nhỏ nhất làm nên một đơn vị lớn — 1 với VND, 100 với USD.
  int get minorUnitsPerUnit {
    var result = 1;
    for (var i = 0; i < decimalDigits; i++) {
      result *= 10;
    }
    return result;
  }

  static final RegExp _codePattern = RegExp(r'^[A-Z]{3}$');

  /// Chỉ liệt kê loại tiền có số chữ số khác mặc định 2 của ISO 4217; mã hợp lệ
  /// nhưng không có trong bảng sẽ lấy 2.
  static const Map<String, int> _decimalDigitsByCode = <String, int>{
    'VND': 0,
    'JPY': 0,
    'KRW': 0,
    'CLP': 0,
    'ISK': 0,
    'BHD': 3,
    'JOD': 3,
    'KWD': 3,
    'OMR': 3,
    'TND': 3,
  };

  @override
  int compareTo(Currency other) => code.compareTo(other.code);

  @override
  bool operator ==(Object other) => other is Currency && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => code;
}
