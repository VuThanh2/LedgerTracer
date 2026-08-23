import 'dart:convert';

import 'money.dart';
import 'search_text.dart';

/// Danh tính của một giao dịch **xét như một sự kiện**: tài khoản, ngày ghi
/// nhận, số tiền, loại tiền và nội dung đã chuẩn hoá, rút gọn thành một mã băm.
///
/// Nó trả lời "giao dịch này đã từng được nhập chưa", còn `transactionId` trả
/// lời "đây là bản ghi nào" — hai khái niệm tách bạch
/// (Rule – Identity Is Local and Surrogate; Sameness Is Fingerprint).
///
/// Đây là **chỉ mục, không phải ràng buộc duy nhất**: hai dòng giống hệt nhau
/// trong cùng một file là hai giao dịch thật và phải được nhập đủ, nên chống
/// trùng là phép đếm chứ không phải phép kiểm tồn tại (UC-02).
///
/// Mã băm phải ổn định giữa các lần chạy và giữa các nền tảng nên không thể dùng
/// `Object.hashCode`. Ở đây là hai lượt FNV-1a 32-bit, tính bằng số học thuần để
/// kết quả giống hệt nhau trên native (int 64-bit) lẫn Web (double).
final class Fingerprint {
  const Fingerprint._(this.value);

  /// Dựng fingerprint của một giao dịch. Cố ý **không** có `counterpartyName`:
  /// cùng một giao dịch có thể được hai ngân hàng ghi tên khác nhau, và
  /// Ubiquitous Language định nghĩa "trùng nhau" là
  /// tài khoản • ngày • số tiền • loại tiền • nội dung.
  factory Fingerprint.of({
    required int accountId,
    required DateTime bookingDate,
    required Money amount,
    required String description,
  }) {
    final canonical = <String>[
      '$accountId',
      _formatDate(bookingDate),
      '${amount.minorUnits}',
      amount.currency.code,
      SearchText.normalize(description),
    ].join('|');
    return Fingerprint._(_hash(canonical));
  }

  /// Dựng lại từ cột đã lưu.
  const Fingerprint.fromStored(this.value);

  /// 16 ký tự hex.
  final String value;

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static String _hash(String canonical) {
    final bytes = utf8.encode(canonical);
    final low = _fnv1a(bytes, _offsetBasis, reversed: false);
    final high = _fnv1a(bytes, _secondaryOffsetBasis, reversed: true);
    return high.toRadixString(16).padLeft(8, '0') +
        low.toRadixString(16).padLeft(8, '0');
  }

  /// FNV-1a trên 32 bit. Lượt thứ hai đọc ngược mảng byte để hai nửa đủ độc lập,
  /// ghép lại có sức phân biệt tương đương một mã băm 64-bit.
  static int _fnv1a(
    List<int> bytes,
    int offsetBasis, {
    required bool reversed,
  }) {
    var hash = offsetBasis;
    for (var i = 0; i < bytes.length; i++) {
      final byte = bytes[reversed ? bytes.length - 1 - i : i];
      hash = _multiply32(hash ^ byte, _prime);
    }
    return hash;
  }

  /// `(value * factor) mod 2^32` tính theo từng nửa, để mọi giá trị trung gian
  /// đều dưới 2^53 và vì thế chính xác tuyệt đối cả trên Web.
  static int _multiply32(int value, int factor) {
    final low = (value % 0x10000) * factor;
    final high = ((value ~/ 0x10000) * factor) % 0x10000;
    return (low + high * 0x10000) % 0x100000000;
  }

  static const int _prime = 16777619;
  static const int _offsetBasis = 2166136261;
  static const int _secondaryOffsetBasis = 2654435761;

  @override
  bool operator ==(Object other) =>
      other is Fingerprint && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
