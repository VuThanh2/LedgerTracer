/// Dạng chuẩn hoá, không dấu của tên đối tác và nội dung chuyển khoản; là cột có
/// chỉ mục đứng sau tìm kiếm tức thời (UC-06).
///
/// Được tính **một lần lúc nhập** rồi lưu, không tính lại mỗi lần gõ — nếu không
/// mỗi phím bấm sẽ thành một lần quét toàn bảng trên luồng chính
/// (Rule – Normalization Happens Once, at Import). Chỉ tính lại khi giao dịch bị
/// sửa tay (UC-05).
///
/// [normalize] là **thuật toán chuẩn hoá duy nhất** của hệ thống: giá trị đem
/// lưu, từ khoá người dùng gõ, và nội dung dùng để dựng fingerprint đều đi qua
/// đúng hàm này, nhờ vậy thứ đã lưu luôn tìm lại được.
final class SearchText {
  const SearchText._(this.value);

  /// Dựng giá trị đem lưu từ đúng cặp trường mà nó được phép đến từ đó.
  factory SearchText.of({String? counterpartyName, String description = ''}) =>
      SearchText._(normalize('${counterpartyName ?? ''} $description'));

  /// Dựng dạng so khớp của từ khoá người dùng gõ (UC-06).
  factory SearchText.query(String keyword) => SearchText._(normalize(keyword));

  /// Dựng lại từ cột đã chuẩn hoá sẵn trong cơ sở dữ liệu.
  const SearchText.fromStored(this.value);

  final String value;

  bool get isEmpty => value.isEmpty;

  bool get isNotEmpty => value.isNotEmpty;

  /// Bản trong bộ nhớ của chính điều kiện `LIKE %keyword%` mà repository chạy
  /// dưới SQL — để hai nơi hiểu "khớp" giống hệt nhau.
  bool contains(SearchText keyword) =>
      keyword.isEmpty || value.contains(keyword.value);

  /// Hạ chữ thường, bỏ dấu tiếng Việt (kể cả dạng tổ hợp) và gộp khoảng trắng,
  /// để `"NGUYỄN Văn A"` và `"nguyen  van a"` là cùng một chuỗi.
  static String normalize(String raw) {
    final lowered = raw.toLowerCase();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      if (_isCombiningMark(rune)) continue;
      buffer.write(_foldedRunes[rune] ?? String.fromCharCode(rune));
    }
    return buffer.toString().trim().replaceAll(_whitespaceRun, ' ');
  }

  /// Dấu tổ hợp Unicode: văn bản lưu ở dạng phân rã (NFD) mang dấu thanh thành
  /// một code point riêng đứng sau nguyên âm.
  static bool _isCombiningMark(int rune) =>
      (rune >= 0x0300 && rune <= 0x036F) ||
      (rune >= 0x1AB0 && rune <= 0x1AFF) ||
      (rune >= 0x20D0 && rune <= 0x20F0);

  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Chữ thường có dấu ánh xạ về chữ gốc; dạng chữ hoa được bao phủ vì
  /// [normalize] hạ chữ thường trước.
  static const Map<String, String> _foldingGroups = <String, String>{
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };

  static final Map<int, String> _foldedRunes = <int, String>{
    for (final entry in _foldingGroups.entries)
      for (final rune in entry.value.runes) rune: entry.key,
  };

  @override
  bool operator ==(Object other) => other is SearchText && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
