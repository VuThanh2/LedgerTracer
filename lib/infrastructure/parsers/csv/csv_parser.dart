import 'dart:convert';
import 'dart:typed_data';

import '../../../application/import/contracts/statement_parser.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../shared/statement_fields.dart';
import '../shared/tabular_statement.dart';

/// Một bản ghi CSV đã tách ô, kèm vị trí của nó trong file gốc.
final class _CsvRecord {
  const _CsvRecord({
    required this.cells,
    required this.lineNumber,
    required this.startOffset,
    required this.endOffset,
  });

  final List<String?> cells;

  /// Dòng bắt đầu bản ghi trong file gốc, đếm từ 1 — một bản ghi có thể trải
  /// nhiều dòng khi một ô được đặt trong dấu nháy.
  final int lineNumber;

  final int startOffset;
  final int endOffset;

  bool get isBlank =>
      cells.every((cell) => cell == null || cell.trim().isEmpty);
}

/// Bộ phân tích sao kê CSV — định dạng phổ biến nhất, hầu hết ngân hàng đều xuất
/// được qua Internet Banking.
///
/// **Bất biến và không giữ trạng thái** vì object này bị sao chép sang isolate
/// phân tích: nó không mở file, không giữ `SendPort`, không đụng tới repository.
/// Mọi thứ nó cần đến qua tham số.
///
/// Việc duyệt file chạy trên **bytes**, không trên một chuỗi đã giải mã sẵn:
/// `utf8.decode` cả file sẽ dựng thêm một bản sao toàn bộ nội dung trong bộ nhớ
/// isolate, ngay bên cạnh mảng bytes vốn đã có — với file hàng trăm nghìn dòng
/// thì đó là cái giá phải trả hai lần cho cùng một dữ liệu.
final class CsvParser implements StatementParser {
  const CsvParser();

  @override
  StatementFormat get format => StatementFormat.csv;

  /// Ứng viên ký tự phân tách, theo thứ tự ưu tiên khi hoà nhau.
  ///
  /// `;` đứng trước `,` là có lý do: sao kê xuất từ Excel ở các máy dùng dấu
  /// phẩy làm dấu thập phân (gồm cả Việt Nam) đều dùng `;`, và ở những file đó
  /// dấu phẩy vẫn xuất hiện dày đặc bên trong các ô số tiền.
  static const List<int> _delimiterCandidates = <int>[
    _semicolon,
    _comma,
    _tab,
    _pipe,
  ];

  static const int _quote = 0x22;
  static const int _comma = 0x2C;
  static const int _semicolon = 0x3B;
  static const int _tab = 0x09;
  static const int _pipe = 0x7C;
  static const int _lf = 0x0A;
  static const int _cr = 0x0D;

  /// Số byte đầu file dùng để đoán ký tự phân tách.
  static const int _sniffLength = 8 * 1024;

  @override
  Iterable<ParseLineResult> parseLines(Uint8List bytes) sync* {
    ColumnLayout? layout;
    for (final record in _records(bytes)) {
      if (layout == null) {
        // Mọi thứ trước dòng tiêu đề là phần giới thiệu của ngân hàng (tên chủ
        // tài khoản, số tài khoản, kỳ sao kê). Bỏ qua cho tới khi gặp một dòng
        // đủ tư cách làm tiêu đề, thay vì mặc định dòng đầu tiên là tiêu đề.
        final candidate = ColumnLayout.fromHeader(record.cells);
        if (candidate.isUsable) layout = candidate;
        continue;
      }
      if (record.isBlank) continue;
      yield TabularStatement.readRow(
        layout: layout,
        cells: record.cells,
        sourceLineNumber: record.lineNumber,
        rawLine: () => _decode(bytes, record.startOffset, record.endOffset),
      );
    }

    if (layout == null) {
      // Cả **file** không dùng được, khác hẳn một dòng không đọc được: không có
      // dòng tiêu đề thì không có cách nào biết cột nào là ngày, cột nào là số
      // tiền. Ném ra ở đây để tầng trên báo `ParsingFailure` cho riêng file này
      // (UC-02).
      throw const FormatException(
        'No header row with a date column and an amount column was found in the '
      'CSV file.',
      );
    }
  }

  /// Ước lượng bằng cách đếm ký tự xuống dòng.
  ///
  /// Cố tình **không** phân tích trước cả file để đếm cho chính xác: như vậy là
  /// trả gấp đôi chi phí đọc chỉ để lấy một con số trang trí cho thanh tiến
  /// trình. Sai số vài dòng ở đây không ai thấy (UC-02 bước 5).
  @override
  int? estimateRowCount(Uint8List bytes) {
    var lines = 0;
    for (final byte in bytes) {
      if (byte == _lf) lines++;
    }
    // Trừ dòng tiêu đề; file một dòng duy nhất không có ký tự xuống dòng nào.
    return lines > 0 ? lines - 1 : 0;
  }

  @override
  String? peekAccountNumber(Uint8List head) =>
      StatementFields.findAccountNumber(_decode(head, 0, head.length));

  /// Duyệt file thành các bản ghi, đúng theo quy ước trích dẫn của RFC 4180.
  ///
  /// Xử lý dấu nháy tử tế là bắt buộc chứ không phải cầu toàn: nội dung chuyển
  /// khoản thường xuyên chứa chính ký tự phân tách, và cắt chuỗi bằng `split`
  /// sẽ đẩy nửa sau của nội dung sang cột kế tiếp — một dòng "đọc được" nhưng
  /// mang số tiền lấy từ chỗ khác.
  Iterable<_CsvRecord> _records(Uint8List bytes) sync* {
    final start = _skipByteOrderMark(bytes);
    final delimiter = _detectDelimiter(bytes, start);

    final cells = <String?>[];
    final field = <int>[];
    var inQuotes = false;
    var lineNumber = 1;
    var recordLine = 1;
    var recordStart = start;

    for (var index = start; index < bytes.length; index++) {
      final byte = bytes[index];

      if (inQuotes) {
        if (byte == _quote) {
          // `""` bên trong một ô có nháy là một ký tự nháy thật.
          if (index + 1 < bytes.length && bytes[index + 1] == _quote) {
            field.add(_quote);
            index++;
          } else {
            inQuotes = false;
          }
        } else {
          if (byte == _lf) lineNumber++;
          field.add(byte);
        }
        continue;
      }

      if (byte == _quote) {
        inQuotes = true;
      } else if (byte == delimiter) {
        cells.add(_takeField(field));
      } else if (byte == _lf) {
        cells.add(_takeField(field));
        yield _CsvRecord(
          cells: List<String?>.of(cells),
          lineNumber: recordLine,
          startOffset: recordStart,
          endOffset: index,
        );
        cells.clear();
        lineNumber++;
        recordLine = lineNumber;
        recordStart = index + 1;
      } else if (byte != _cr) {
        field.add(byte);
      }
    }

    // Dòng cuối không kết thúc bằng ký tự xuống dòng vẫn là một bản ghi.
    if (field.isNotEmpty || cells.isNotEmpty) {
      cells.add(_takeField(field));
      yield _CsvRecord(
        cells: cells,
        lineNumber: recordLine,
        startOffset: recordStart,
        endOffset: bytes.length,
      );
    }
  }

  static String? _takeField(List<int> field) {
    final value = utf8.decode(field, allowMalformed: true).trim();
    field.clear();
    return value.isEmpty ? null : value;
  }

  /// Chọn ký tự phân tách theo số lần xuất hiện ở phần đầu file.
  ///
  /// Không hỏi người dùng và không tin vào phần mở rộng: người dùng chỉ chọn file
  /// mình đang có, việc đọc được nó là chuyện của ứng dụng (UC-02 bước 2).
  static int _detectDelimiter(Uint8List bytes, int start) {
    final end = bytes.length < start + _sniffLength
        ? bytes.length
        : start + _sniffLength;
    final counts = <int, int>{for (final candidate in _delimiterCandidates) candidate: 0};

    var inQuotes = false;
    for (var index = start; index < end; index++) {
      final byte = bytes[index];
      if (byte == _quote) {
        inQuotes = !inQuotes;
      } else if (!inQuotes && counts.containsKey(byte)) {
        counts[byte] = counts[byte]! + 1;
      }
    }

    var best = _delimiterCandidates.first;
    for (final candidate in _delimiterCandidates) {
      if (counts[candidate]! > counts[best]!) best = candidate;
    }
    // Không tìm thấy ứng viên nào thì file chỉ có một cột; lấy dấu phẩy để phần
    // sau vẫn chạy được, và dòng tiêu đề sẽ là thứ phán quyết file có dùng được
    // hay không.
    return counts[best]! > 0 ? best : _comma;
  }

  /// Bỏ qua BOM của UTF-8. Excel gắn nó vào mọi file CSV nó xuất ra, và để lại
  /// thì ký tự đầu của tên cột đầu tiên sẽ không bao giờ khớp bí danh nào.
  static int _skipByteOrderMark(Uint8List bytes) =>
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? 3
      : 0;

  static String _decode(Uint8List bytes, int start, int end) => utf8.decode(
    Uint8List.sublistView(bytes, start, end),
    allowMalformed: true,
  );
}
