import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

import '../../../application/import/contracts/statement_parser.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../shared/statement_fields.dart';
import '../shared/tabular_statement.dart';

/// Bộ phân tích sao kê Excel `.xlsx` — định dạng mà một số ngân hàng (Agribank
/// chẳng hạn) cho xuất trực tiếp ngay trong ứng dụng di động.
///
/// ## Giới hạn có chủ đích: chỉ `.xlsx`, không `.xls`
///
/// `.xlsx` là một file ZIP chứa XML — đọc được bằng hai thư viện thuần Dart, và
/// đọc được **theo luồng**. `.xls` (BIFF8) là định dạng nhị phân OLE2 đời cũ,
/// đòi hỏi một bộ đọc hoàn toàn khác và không có thư viện Dart nào đọc được.
/// Viết lấy một bộ đọc BIFF8 là một dự án riêng, nằm ngoài trọng tâm kỹ thuật
/// của đề tài (xử lý dữ liệu lớn / concurrency) — đúng cùng loại đánh đổi mà
/// Overview đã ghi cho PDF. Người dùng có file `.xls` chỉ cần mở và lưu lại
/// thành `.xlsx`, thao tác mà chính Excel đề nghị.
///
/// **Bất biến và không giữ trạng thái**: object này bị sao chép sang isolate
/// phân tích.
final class ExcelParser implements StatementParser {
  const ExcelParser();

  @override
  StatementFormat get format => StatementFormat.excel;

  @override
  Iterable<ParseLineResult> parseLines(Uint8List bytes) sync* {
    final workbook = _XlsxWorkbook.open(bytes);
    ColumnLayout? layout;

    for (final row in workbook.rows()) {
      if (layout == null) {
        // Sao kê Excel gần như luôn có vài dòng tiêu đề trang trước bảng dữ
        // liệu (tên ngân hàng, chủ tài khoản, kỳ sao kê). Đi tới khi gặp dòng
        // đủ tư cách làm tiêu đề, thay vì mặc định dòng đầu tiên là tiêu đề.
        final candidate = ColumnLayout.fromHeader(row.cells);
        if (candidate.isUsable) layout = candidate;
        continue;
      }
      if (row.isBlank) continue;
      yield TabularStatement.readRow(
        layout: layout,
        cells: row.cells,
        sourceLineNumber: row.number,
        rawLine: () => row.cells.map((cell) => cell ?? '').join(' | '),
      );
    }

    if (layout == null) {
      throw const FormatException(
        'Không tìm thấy dòng tiêu đề có cột ngày và số tiền trong file Excel.',
      );
    }
  }

  /// `null`, và đó là câu trả lời đúng cho định dạng này.
  ///
  /// Đếm số dòng của một file `.xlsx` đòi hỏi giải nén rồi duyệt hết XML của
  /// sheet — tức đúng toàn bộ công việc mà [parseLines] sắp làm. Trả tiền hai
  /// lần cho cùng một phép đọc chỉ để lấy một con số trang trí là điều hợp đồng
  /// của phương thức này nói rõ là không đáng; thanh tiến trình của file Excel
  /// vì thế là loại không xác định (UC-02 bước 5).
  @override
  int? estimateRowCount(Uint8List bytes) => null;

  /// Số tài khoản, nếu chính file khai báo nó trong khối thông tin phía trên
  /// bảng dữ liệu.
  ///
  /// [head] là **phần đầu file**, mà `.xlsx` lại là ZIP có thư mục nằm ở cuối —
  /// một phần đầu bị cắt cụt không giải nén được. Hợp đồng đã lường trước điều
  /// đó: phần đầu chưa đủ để kết luận thì trả `null`, và luồng nhập đi tiếp
  /// đúng như với một file không mang số tài khoản (UC-02 bước 4).
  @override
  String? peekAccountNumber(Uint8List head) {
    try {
      final workbook = _XlsxWorkbook.open(head);
      final buffer = StringBuffer();
      for (final row in workbook.rows()) {
        buffer.writeln(row.cells.map((cell) => cell ?? '').join(' '));
        // Số tài khoản nằm trong khối thông tin đầu trang; quét cả file chỉ để
        // tìm nó là đọc lại toàn bộ dữ liệu trước khi luồng nhập kịp bắt đầu.
        if (row.number > _headerScanRowLimit) break;
      }
      return StatementFields.findAccountNumber(buffer.toString());
    } catch (_) {
      // Bắt **mọi** thứ, và đó là chủ đích. [head] là một file ZIP bị cắt cụt
      // giữa chừng: bộ giải nén có thể ném `ArchiveException`, mà cũng có thể
      // đọc trúng một độ dài rác rồi ném `RangeError`. Hợp đồng ở đây chỉ có hai
      // kết cục — một số tài khoản, hoặc `null` nghĩa là chưa đủ để kết luận —
      // nên để bất kỳ ngoại lệ nào thoát ra là làm hỏng cả bước soi file, vốn
      // chạy chung cho **mọi** file người dùng vừa chọn: một file Excel cụt sẽ
      // kéo theo tất cả những file lành khác trong cùng lượt (UC-02).
      return null;
    }
  }

  static const int _headerScanRowLimit = 20;
}

/// Một dòng của sheet, các ô đã về dạng văn bản.
final class _SheetRow {
  const _SheetRow({required this.number, required this.cells});

  /// Số thứ tự dòng trong file gốc, đúng như Excel hiển thị — đây là thứ người
  /// dùng dùng để tìm lại dòng cần sửa (UC-11).
  final int number;

  final List<String?> cells;

  bool get isBlank =>
      cells.every((cell) => cell == null || cell.trim().isEmpty);
}

/// Phần "đọc OOXML" của `.xlsx`, tách khỏi phần hiểu nghiệp vụ.
///
/// Một file `.xlsx` là ZIP chứa vài file XML tham chiếu lẫn nhau: nội dung ô
/// nằm ở sheet, chuỗi nằm trong bảng dùng chung, còn "ô này là ngày hay là số"
/// lại nằm ở bảng định dạng. Ba mảnh đó phải ghép lại mới ra được một giá trị —
/// và đó là toàn bộ lý do lớp này tồn tại riêng.
final class _XlsxWorkbook {
  _XlsxWorkbook._({
    required this.sheetXml,
    required this.sharedStrings,
    required this.dateStyles,
  });

  factory _XlsxWorkbook.open(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on ArchiveException catch (error) {
      throw FormatException('File Excel không đọc được: ${error.message}');
    }

    final sheetPath = _firstSheetPath(archive);
    final sheetXml = _textOf(archive, sheetPath);
    if (sheetXml == null) {
      throw const FormatException('File Excel không có sheet dữ liệu nào.');
    }
    return _XlsxWorkbook._(
      sheetXml: sheetXml,
      sharedStrings: _readSharedStrings(archive),
      dateStyles: _readDateStyles(archive),
    );
  }

  final String sheetXml;

  /// Excel gom mọi chuỗi lặp lại vào một bảng dùng chung; ô chỉ giữ chỉ số.
  final List<String> sharedStrings;

  /// Chỉ số các kiểu ô được định dạng như ngày tháng.
  ///
  /// Không có bảng này thì cột ngày của một sao kê Excel đọc ra là `45123` — một
  /// con số hợp lệ, không có lỗi nào báo, và mọi dòng đều thành dòng lỗi vì
  /// "không đọc được ngày".
  final Set<int> dateStyles;

  /// Duyệt sheet thành từng dòng, theo luồng sự kiện XML.
  ///
  /// Không dựng cây DOM: một sheet hàng trăm nghìn dòng sẽ thành hàng triệu
  /// object trong bộ nhớ isolate, mà mỗi dòng chỉ cần sống đúng tới lúc nó được
  /// giao đi.
  Iterable<_SheetRow> rows() sync* {
    var rowNumber = 0;
    var cells = <String?>[];
    var columnIndex = 0;
    String? cellType;
    var isDateCell = false;
    final text = StringBuffer();
    var insideValue = false;

    for (final event in parseEvents(sheetXml)) {
      switch (event) {
        case XmlStartElementEvent(:final name, :final attributes):
          switch (name) {
            case 'row':
              rowNumber = int.tryParse(_attribute(attributes, 'r') ?? '') ??
                  rowNumber + 1;
              cells = <String?>[];
            case 'c':
              columnIndex = _columnIndexOf(_attribute(attributes, 'r'));
              cellType = _attribute(attributes, 't');
              final style = int.tryParse(_attribute(attributes, 's') ?? '');
              isDateCell = style != null && dateStyles.contains(style);
              text.clear();
              // `<c r="B2"/>` là ô rỗng có định dạng; nó không có thẻ đóng nên
              // phải chốt ngay tại đây.
              if (event.isSelfClosing) {
                _setCell(cells, columnIndex, null);
              }
            case 'v' || 't':
              insideValue = true;
          }
        case XmlTextEvent(:final value):
          if (insideValue) text.write(value);
        case XmlEndElementEvent(:final name):
          switch (name) {
            case 'v' || 't':
              insideValue = false;
            case 'c':
              _setCell(
                cells,
                columnIndex,
                _valueOf(text.toString(), cellType, isDateCell),
              );
            case 'row':
              yield _SheetRow(number: rowNumber, cells: cells);
          }
        default:
          break;
      }
    }
  }

  /// Đổi nội dung thô của một ô thành văn bản mà phần đọc dùng chung hiểu được.
  String? _valueOf(String raw, String? type, bool isDateCell) {
    if (raw.isEmpty) return null;
    switch (type) {
      case 's':
        final index = int.tryParse(raw);
        return (index != null && index < sharedStrings.length)
            ? sharedStrings[index]
            : null;
      case 'inlineStr' || 'str':
        return raw;
      case 'b':
        return raw == '1' ? 'TRUE' : 'FALSE';
      case 'd':
        return raw;
      default:
        if (!isDateCell) return raw;
        final serial = double.tryParse(raw);
        return serial == null ? raw : _dateFromSerial(serial);
    }
  }

  /// Số sê-ri ngày của Excel thành `YYYY-MM-DD`.
  ///
  /// Mốc là 30/12/1899 chứ không phải 01/01/1900: Excel cố tình giữ lại lỗi coi
  /// năm 1900 là năm nhuận để tương thích ngược với Lotus 1-2-3, và mốc lệch hai
  /// ngày là cách bù đúng cho lỗi đó ở mọi ngày sau 28/02/1900 — tức mọi ngày mà
  /// một sao kê ngân hàng có thể chứa.
  static String _dateFromSerial(double serial) {
    final date = DateTime.utc(
      1899,
      12,
      30,
    ).add(Duration(days: serial.floor()));
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static void _setCell(List<String?> cells, int index, String? value) {
    while (cells.length <= index) {
      cells.add(null);
    }
    cells[index] = value;
  }

  /// `"BC12"` thành chỉ số cột 0-based.
  ///
  /// Đọc từ tham chiếu ô chứ không đếm số thẻ `<c>` đã gặp: Excel **bỏ hẳn** thẻ
  /// của ô trống, nên đếm sẽ làm mọi cột sau một ô trống lệch đi một chỗ.
  static int _columnIndexOf(String? reference) {
    if (reference == null) return 0;
    var index = 0;
    for (final unit in reference.codeUnits) {
      if (unit < 0x41 || unit > 0x5A) break;
      index = index * 26 + (unit - 0x40);
    }
    return index > 0 ? index - 1 : 0;
  }

  static String? _attribute(List<XmlEventAttribute> attributes, String name) {
    for (final attribute in attributes) {
      if (attribute.name == name) return attribute.value;
    }
    return null;
  }

  /// Sheet đầu tiên **theo thứ tự trong workbook**, không phải theo tên file.
  ///
  /// Tên file trong ZIP (`sheet1.xml`) không hứa hẹn gì về thứ tự tab mà người
  /// dùng nhìn thấy; chỉ `workbook.xml` mới nói điều đó.
  static String _firstSheetPath(Archive archive) {
    final workbook = _textOf(archive, 'xl/workbook.xml');
    final rels = _textOf(archive, 'xl/_rels/workbook.xml.rels');
    if (workbook != null && rels != null) {
      final sheet = _sheetIdPattern.firstMatch(workbook);
      final relationId = sheet?.group(1);
      if (relationId != null) {
        final target = RegExp(
          'Id="$relationId"[^>]*Target="([^"]+)"',
        ).firstMatch(rels)?.group(1);
        if (target != null) {
          return target.startsWith('/')
              ? target.substring(1)
              : 'xl/${target.replaceFirst('../', '')}';
        }
      }
    }
    // Workbook thiếu hoặc hỏng: quay về sheet đầu tiên tìm thấy, còn hơn từ chối
    // cả file vì một mảnh siêu dữ liệu.
    for (final file in archive.files) {
      if (file.name.startsWith('xl/worksheets/') &&
          file.name.endsWith('.xml')) {
        return file.name;
      }
    }
    return 'xl/worksheets/sheet1.xml';
  }

  static List<String> _readSharedStrings(Archive archive) {
    final xml = _textOf(archive, 'xl/sharedStrings.xml');
    if (xml == null) return const <String>[];

    final strings = <String>[];
    final buffer = StringBuffer();
    var insideItem = false;
    var insideText = false;
    for (final event in parseEvents(xml)) {
      switch (event) {
        case XmlStartElementEvent(:final name):
          if (name == 'si') {
            insideItem = true;
            buffer.clear();
          } else if (name == 't') {
            insideText = true;
          }
        case XmlTextEvent(:final value):
          if (insideItem && insideText) buffer.write(value);
        case XmlEndElementEvent(:final name):
          if (name == 't') {
            insideText = false;
          } else if (name == 'si') {
            insideItem = false;
            // Một chuỗi có thể bị chia thành nhiều đoạn `<r><t>` khi các phần
            // của nó được định dạng khác nhau; ghép lại mới ra chuỗi thật.
            strings.add(buffer.toString());
          }
        default:
          break;
      }
    }
    return strings;
  }

  /// Các chỉ số kiểu ô mang định dạng ngày tháng.
  static Set<int> _readDateStyles(Archive archive) {
    final xml = _textOf(archive, 'xl/styles.xml');
    if (xml == null) return const <int>{};

    final customDateFormats = <int>{
      for (final match in _numberFormatPattern.allMatches(xml))
        if (_looksLikeDateFormat(match.group(2)!))
          int.parse(match.group(1)!),
    };

    final dateStyles = <int>{};
    var insideCellFormats = false;
    var styleIndex = 0;
    for (final event in parseEvents(xml)) {
      switch (event) {
        case XmlStartElementEvent(:final name, :final attributes):
          if (name == 'cellXfs') {
            insideCellFormats = true;
          } else if (insideCellFormats && name == 'xf') {
            final formatId = int.tryParse(_attribute(attributes, 'numFmtId') ?? '');
            if (formatId != null &&
                (_builtInDateFormats.contains(formatId) ||
                    customDateFormats.contains(formatId))) {
              dateStyles.add(styleIndex);
            }
            styleIndex++;
          }
        case XmlEndElementEvent(:final name):
          if (name == 'cellXfs') insideCellFormats = false;
        default:
          break;
      }
    }
    return dateStyles;
  }

  /// Mã định dạng có chữ `y`, hoặc có cả `d` lẫn `m`, là định dạng ngày.
  ///
  /// Phần văn bản trong dấu nháy của mã định dạng bị bỏ trước khi kiểm, nếu
  /// không thì một mã tiền tệ như `#,##0 "đồng"` sẽ bị coi là ngày.
  static bool _looksLikeDateFormat(String formatCode) {
    final code = formatCode.replaceAll(_quotedTextPattern, '').toLowerCase();
    return code.contains('y') || (code.contains('d') && code.contains('m'));
  }

  static String? _textOf(Archive archive, String path) {
    final file = archive.findFile(path);
    final content = file?.readBytes();
    return content == null ? null : utf8.decode(content, allowMalformed: true);
  }

  /// Các mã định dạng ngày dựng sẵn của Excel (14–22 là ngày/giờ, 45–47 là thời
  /// lượng); chúng không xuất hiện trong `styles.xml` nên phải biết trước.
  static const Set<int> _builtInDateFormats = <int>{
    14, 15, 16, 17, 18, 19, 20, 21, 22, 45, 46, 47,
  };

  static final RegExp _sheetIdPattern = RegExp(r'<sheet[^>]*r:id="([^"]+)"');
  static final RegExp _numberFormatPattern = RegExp(
    r'<numFmt[^>]*numFmtId="(\d+)"[^>]*formatCode="([^"]*)"',
  );
  static final RegExp _quotedTextPattern = RegExp(r'"[^"]*"');
}
