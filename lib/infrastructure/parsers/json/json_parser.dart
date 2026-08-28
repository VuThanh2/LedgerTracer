import 'dart:convert';
import 'dart:typed_data';

import '../../../application/import/contracts/statement_parser.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../shared/statement_fields.dart';
import '../shared/tabular_statement.dart';

/// Bộ phân tích sao kê JSON — định dạng của các nguồn dữ liệu đã có cấu trúc sẵn
/// hoặc đến từ tích hợp hệ thống khác.
///
/// **Bất biến và không giữ trạng thái**: object này bị sao chép sang isolate
/// phân tích.
final class JsonParser implements StatementParser {
  const JsonParser();

  @override
  StatementFormat get format => StatementFormat.json;

  /// Các khoá thường bọc mảng giao dịch khi JSON gốc là một object.
  static const List<String> _arrayKeys = <String>[
    'transactions',
    'data',
    'rows',
    'items',
    'records',
    'entries',
    'result',
  ];

  @override
  Iterable<ParseLineResult> parseLines(Uint8List bytes) sync* {
    final entries = _entriesOf(bytes);
    if (entries.isEmpty) return;

    // Khoá của object đầu tiên quyết định bố cục cho cả file, và các object sau
    // được đọc **theo tên khoá** chứ không theo vị trí. JSON không hứa hẹn gì về
    // thứ tự khoá giữa các phần tử, nên đọc theo vị trí là một giả định sẽ sai
    // đúng vào lúc nguồn dữ liệu đổi thư viện sinh JSON.
    final keys = entries.first.keys.toList(growable: false);
    final layout = ColumnLayout.fromHeader(keys);
    if (!layout.isUsable) {
      throw const FormatException(
        'Không nhận ra trường ngày và số tiền trong file JSON.',
      );
    }

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      // Đánh số theo **thứ tự phần tử**: JSON không có khái niệm dòng, và số thứ
      // tự phần tử mới là thứ giúp người dùng tìm lại đúng chỗ trong file gốc để
      // sửa rồi nhập lại (UC-11).
      final position = index + 1;
      yield TabularStatement.readRow(
        layout: layout,
        cells: <String?>[for (final key in keys) _asText(entry[key])],
        sourceLineNumber: position,
        rawLine: () => jsonEncode(entry),
      );
    }
  }

  /// Ước lượng bằng số dấu mở ngoặc nhọn.
  ///
  /// Rẻ và đủ cho một thanh tiến trình; đếm đúng thì phải giải mã cả file, mà
  /// việc đó đằng nào cũng sẽ xảy ra ngay sau đó ở [parseLines] — trả tiền hai
  /// lần cho cùng một phép đọc là thứ hợp đồng của `estimateRowCount` nói rõ là
  /// không đáng.
  @override
  int? estimateRowCount(Uint8List bytes) {
    var braces = 0;
    for (final byte in bytes) {
      if (byte == 0x7B) braces++;
    }
    return braces;
  }

  @override
  String? peekAccountNumber(Uint8List head) {
    final text = utf8.decode(head, allowMalformed: true);
    final match = _accountKeyPattern.firstMatch(text);
    return match?.group(1) ?? StatementFields.findAccountNumber(text);
  }

  /// Rút mảng giao dịch ra khỏi file, dù nó là JSON gốc hay nằm dưới một khoá.
  ///
  /// Ném [FormatException] khi file không phải JSON hợp lệ hoặc không chứa mảng
  /// object nào — đó là **cả file** hỏng, khác với một phần tử không đọc được.
  static List<Map<String, Object?>> _entriesOf(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes, allowMalformed: true));
    } on FormatException catch (error) {
      throw FormatException('File JSON không hợp lệ: ${error.message}');
    }

    final Object? array = switch (decoded) {
      List<Object?>() => decoded,
      Map<String, Object?>() => _findArray(decoded),
      _ => null,
    };
    if (array is! List<Object?>) {
      throw const FormatException(
        'File JSON không chứa mảng giao dịch nào đọc được.',
      );
    }
    return <Map<String, Object?>>[
      for (final element in array)
        if (element is Map<String, Object?>) element,
    ];
  }

  static Object? _findArray(Map<String, Object?> root) {
    for (final key in _arrayKeys) {
      final value = root[key];
      if (value is List<Object?>) return value;
    }
    // Khoá lạ vẫn chấp nhận được miễn là giá trị của nó là một mảng object: chỉ
    // có đúng một mảng như thế trong một file sao kê, nên không có gì để nhầm.
    for (final value in root.values) {
      if (value is List<Object?> &&
          value.isNotEmpty &&
          value.first is Map<String, Object?>) {
        return value;
      }
    }
    return null;
  }

  /// Đưa một giá trị JSON về văn bản để phần đọc dùng chung xử lý tiếp.
  ///
  /// Số được chuyển bằng `toString` chứ không qua `double`: nếu nguồn ghi số
  /// tiền thành số thực có phần lẻ vượt quá độ chính xác của loại tiền,
  /// `Money.fromDecimalString` sẽ biến dòng đó thành **dòng lỗi** thay vì làm
  /// tròn âm thầm (Rule – Money Is a Signed Integer, Never a Floating-Point
  /// Number).
  static String? _asText(Object? value) => switch (value) {
    null => null,
    String() => value,
    num() || bool() => value.toString(),
    // Object hay mảng lồng bên trong một ô không có nghĩa gì với sao kê phẳng;
    // coi như ô trống để phần đọc chung báo đúng trường nào bị thiếu.
    _ => null,
  };

  static final RegExp _accountKeyPattern = RegExp(
    r'"(?:account_?number|account_?no|so_?tai_?khoan|so_?tk)"\s*:\s*"([^"]+)"',
    caseSensitive: false,
  );
}
