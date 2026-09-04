import 'dart:convert';
import 'dart:typed_data';

import '../../../application/import/contracts/parse_error.dart';
import '../../../application/import/contracts/parsed_row.dart';
import '../../../application/import/contracts/statement_parser.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../shared/statement_fields.dart';

/// Một trường MT940 đã gom đủ các dòng nối tiếp của nó.
final class _SwiftField {
  const _SwiftField({
    required this.tag,
    required this.value,
    required this.lineNumber,
  });

  /// Mã trường, ví dụ `25`, `61`, `86`.
  final String tag;

  /// Nội dung trường, các dòng nối tiếp đã được ghép bằng `\n`.
  final String value;

  /// Dòng mở đầu trường trong file gốc, đếm từ 1.
  final int lineNumber;
}

/// Bộ phân tích MT940 — chuẩn điện SWIFT mà nhiều ngân hàng cung cấp riêng cho
/// khách hàng doanh nghiệp để tích hợp phần mềm kế toán và đối soát tự động.
///
/// Đây là định dạng duy nhất trong bốn định dạng **luôn** mang số tài khoản
/// (trường `:25:`), nên nó cũng là định dạng mà cảnh báo gán nhầm tài khoản đích
/// ở UC-02 bước 4 phát huy tác dụng rõ nhất.
///
/// **Bất biến và không giữ trạng thái**: object này bị sao chép sang isolate
/// phân tích.
final class Mt940Parser implements StatementParser {
  const Mt940Parser();

  @override
  StatementFormat get format => StatementFormat.mt940;

  static const String _accountTag = '25';
  static const String _openingBalanceTag = '60';
  static const String _statementLineTag = '61';
  static const String _informationTag = '86';

  @override
  Iterable<ParseLineResult> parseLines(Uint8List bytes) sync* {
    // Loại tiền là thuộc tính của **trang sao kê**, đọc từ số dư đầu kỳ, chứ
    // không phải của từng dòng: MT940 chỉ ghi ký tự thứ ba của mã tiền vào từng
    // dòng `:61:`. Mặc định VND khi nguồn không nêu (UC-02).
    var currency = Currency.fallback;
    _SwiftField? pendingLine;
    var information = <String>[];
    var sawStatementLine = false;

    for (final field in _fields(bytes)) {
      switch (field.tag) {
        case _statementLineTag:
          // Dòng trước đó đã gom đủ phần diễn giải của nó khi gặp dòng mới.
          if (pendingLine != null) {
            yield _readStatementLine(pendingLine, information, currency);
          }
          pendingLine = field;
          information = <String>[];
          sawStatementLine = true;
        case _informationTag:
          // `:86:` luôn thuộc về `:61:` đứng ngay trước nó; đứng một mình thì nó
          // là thông tin của cả trang và không có dòng nào để gắn vào.
          if (pendingLine != null) information.add(field.value);
        case _openingBalanceTag:
          currency = _currencyOf(field.value) ?? currency;
        default:
          break;
      }
    }
    if (pendingLine != null) {
      yield _readStatementLine(pendingLine, information, currency);
    }

    if (!sawStatementLine) {
      // Cả **file** không dùng được: không có trường `:61:` nào thì đây không
      // phải một sao kê MT940, dù phần đầu có trông giống đến đâu (UC-02).
      throw const FormatException(
        'The MT940 file holds no transaction line (:61:).',
      );
    }
  }

  /// Ước lượng bằng số lần trường `:61:` mở đầu một dòng — rẻ và đúng bằng số
  /// giao dịch của file.
  @override
  int? estimateRowCount(Uint8List bytes) {
    var count = 0;
    for (final line in _lines(bytes)) {
      if (line.text.startsWith(':$_statementLineTag:')) count++;
    }
    return count;
  }

  /// Số tài khoản nằm ở trường `:25:`, ngay đầu file.
  ///
  /// Phần sau dấu `/` là mã tiền của tài khoản (`VN0011000412345/USD`), không
  /// phải một phần của số tài khoản, nên nó bị cắt bỏ trước khi trả về.
  @override
  String? peekAccountNumber(Uint8List head) {
    for (final field in _fields(head)) {
      if (field.tag != _accountTag) continue;
      final value = field.value.split('\n').first.trim();
      final slash = value.indexOf('/');
      final number = (slash < 0 ? value : value.substring(0, slash)).trim();
      return number.isEmpty ? null : number;
    }
    return null;
  }

  /// Dựng một [ParsedRow] từ trường `:61:` và các trường `:86:` đi kèm.
  static ParseLineResult _readStatementLine(
    _SwiftField field,
    List<String> information,
    Currency currency,
  ) {
    final content = field.value.split('\n');
    final match = _statementLinePattern.firstMatch(content.first.trim());
    if (match == null) {
      return ParseLineResult.failed(
        ParseError(
          sourceLineNumber: field.lineNumber,
          rawLine: field.value,
          reason: 'This :61: line does not follow the MT940 structure.',
        ),
      );
    }

    try {
      // Ký hiệu D/C của MT940 được đổi ngay thành **dấu** của số tiền: bốn parser
      // khác nhau chỉ đổ chung vào một mô hình được khi chiều tiền đã được chuẩn
      // hoá tại chỗ (Rule – The Sign Carries the Direction).
      final mark = match.group(3)!;
      final amount = StatementFields.parseExactAmount(
        _decimalOf(match.group(5)!),
        currency,
        negative: mark.endsWith('D'),
      );
      return ParseLineResult.parsed(
        ParsedRow(
          bookingDate: StatementFields.parseDate(_isoDateOf(match.group(1)!)),
          // `R` là bút toán đảo (reversal): tiền đi ngược chiều ký hiệu D/C.
          amount: mark.startsWith('R') ? -amount : amount,
          // MT940 không có trường tên đối tác riêng; tên nếu có thì nằm lẫn
          // trong phần diễn giải. Bịa ra một cách tách tên là tự tạo dữ liệu —
          // ứng dụng không có căn cứ nào để xác minh nội dung giao dịch.
          description: _descriptionOf(information, match.group(7)),
          sourceLineNumber: field.lineNumber,
        ),
      );
    } on StatementFieldException catch (error) {
      return ParseLineResult.failed(
        ParseError(
          sourceLineNumber: field.lineNumber,
          rawLine: field.value,
          reason: error.reason,
        ),
      );
    }
  }

  /// Số tiền của MT940 thành dạng chính tắc.
  ///
  /// Dấu phẩy luôn là dấu thập phân trong SWIFT, và nó **bắt buộc phải có** kể
  /// cả khi không có phần lẻ: `1500000,` là một triệu rưỡi viết đúng chuẩn. Cắt
  /// dấu ngăn cách trống ở cuối là bước không thể bỏ — để nguyên thì mọi dòng
  /// của một sao kê VND (loại tiền không có phần lẻ) đều thành dòng lỗi.
  static String _decimalOf(String raw) {
    final decimal = raw.replaceAll(',', '.');
    return decimal.endsWith('.')
        ? decimal.substring(0, decimal.length - 1)
        : decimal;
  }

  /// Diễn giải lấy từ `:86:`; khi trường đó vắng mặt thì dùng phần tham chiếu
  /// của chính `:61:` — có còn hơn để trống một cột mà người dùng cần để nhận ra
  /// giao dịch.
  static String _descriptionOf(List<String> information, String? reference) {
    final joined = information.join(' ').replaceAll('\n', ' ').trim();
    if (joined.isNotEmpty) return joined;
    return reference?.trim() ?? '';
  }

  /// `YYMMDD` của SWIFT thành `YYYY-MM-DD`.
  ///
  /// Năm được mở về thế kỷ 21 ngay tại đây thay vì để [StatementFields.parseDate]
  /// đoán: chuỗi `23-01-02` sẽ bị đọc là ngày-tháng-năm theo quy ước sao kê Việt
  /// Nam, trong khi MT940 luôn là năm-tháng-ngày. Sao kê là dữ liệu quá khứ gần,
  /// nên `23` là 2023.
  static String _isoDateOf(String yymmdd) =>
      '20${yymmdd.substring(0, 2)}-${yymmdd.substring(2, 4)}-'
      '${yymmdd.substring(4, 6)}';

  /// Mã tiền trong trường số dư: `C230101VND1234,56`.
  static Currency? _currencyOf(String balanceField) {
    final match = _balancePattern.firstMatch(balanceField.trim());
    return match == null ? null : Currency.tryParse(match.group(1));
  }

  /// Gom các dòng của file thành trường; dòng không mở đầu bằng `:tag:` là dòng
  /// nối tiếp của trường ngay trước nó.
  static Iterable<_SwiftField> _fields(Uint8List bytes) sync* {
    String? tag;
    var buffer = <String>[];
    var startLine = 0;

    for (final line in _lines(bytes)) {
      final match = _tagPattern.firstMatch(line.text);
      if (match != null) {
        if (tag != null) {
          yield _SwiftField(
            tag: tag,
            value: buffer.join('\n'),
            lineNumber: startLine,
          );
        }
        tag = match.group(1);
        buffer = <String>[match.group(3) ?? ''];
        startLine = line.number;
        continue;
      }
      // Dòng bao bọc của khối SWIFT (`{1:...}`, `-}`) nằm ngoài mọi trường.
      if (tag != null) buffer.add(line.text);
    }
    if (tag != null) {
      yield _SwiftField(
        tag: tag,
        value: buffer.join('\n'),
        lineNumber: startLine,
      );
    }
  }

  /// Duyệt file thành từng dòng, giải mã theo từng dòng một.
  ///
  /// Không giải mã cả file thành một chuỗi: làm vậy sẽ dựng thêm một bản sao
  /// toàn bộ nội dung ngay bên cạnh mảng bytes vốn đã nằm trong bộ nhớ isolate.
  static Iterable<({int number, String text})> _lines(Uint8List bytes) sync* {
    var number = 1;
    var start = 0;
    for (var index = 0; index <= bytes.length; index++) {
      if (index < bytes.length && bytes[index] != _lf) continue;
      var end = index;
      if (end > start && bytes[end - 1] == _cr) end--;
      if (end > start || index < bytes.length) {
        yield (
          number: number,
          text: utf8.decode(
            Uint8List.sublistView(bytes, start, end),
            allowMalformed: true,
          ),
        );
      }
      number++;
      start = index + 1;
    }
  }

  static const int _lf = 0x0A;
  static const int _cr = 0x0D;

  /// Mã trường gồm hai chữ số và một chữ cái phụ tuỳ chọn (`:60F:` là số dư đầu
  /// kỳ, `:60M:` là số dư đầu kỳ của trang tiếp theo). Chữ cái phụ được tách
  /// riêng vì nó phân biệt *biến thể* của cùng một trường, không phải một trường
  /// khác — gộp vào mã sẽ khiến `:60F:` và `:60M:` trông như hai thứ không liên
  /// quan.
  static final RegExp _tagPattern = RegExp(r'^:(\d{2})([A-Z]?):(.*)$');

  /// Ngày giá trị • ngày ghi sổ • ký hiệu nợ/có • mã quỹ • số tiền • mã loại
  /// giao dịch • phần tham chiếu.
  static final RegExp _statementLinePattern = RegExp(
    r'^(\d{6})(\d{4})?([RE]?[CD])([A-Z])?(\d[\d,]*)([NFS][A-Z0-9]{3})?(.*)$',
  );

  static final RegExp _balancePattern = RegExp(r'^[CD]\d{6}([A-Z]{3})');
}
