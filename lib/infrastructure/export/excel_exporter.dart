import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../application/export/export_dataset/export_dataset_dto.dart';

/// Biến một [ExportTable] thành bytes `.xlsx` (UC-11).
///
/// Dựng thẳng gói OOXML tối thiểu thay vì mượn một thư viện bảng tính đầy đủ.
/// Lý do là phạm vi: thứ cần xuất ra là một bảng chữ nhật gồm vài dòng chú thích,
/// một dòng tiêu đề và các dòng dữ liệu — không định dạng, không công thức, không
/// nhiều sheet. Một thư viện tổng quát sẽ kéo theo cả một mô hình workbook trong
/// bộ nhớ cho đúng thứ mà năm file XML cố định giải quyết được.
///
/// Chuỗi được ghi thẳng vào ô (`inlineStr`) thay vì qua bảng chuỗi dùng chung:
/// bảng dùng chung chỉ có lợi khi cùng một chuỗi lặp lại nhiều lần, còn nội dung
/// chuyển khoản thì gần như dòng nào cũng khác dòng nào.
abstract final class ExcelExporter {
  static Uint8List encode(ExportTable table) {
    final rows = <List<String>>[
      // Chú thích đi vào chính bảng tính, mỗi dòng một ô: người nhận file phải
      // đọc được các tiêu chí đang áp dụng ngay khi mở file, không phải qua một
      // kênh khác (UC-11).
      for (final line in table.metadata) <String>[line],
      table.headers,
      ...table.rows,
    ];

    final archive = Archive()
      ..addFile(ArchiveFile.string('[Content_Types].xml', _contentTypes))
      ..addFile(ArchiveFile.string('_rels/.rels', _rootRelationships))
      ..addFile(ArchiveFile.string('xl/workbook.xml', _workbook))
      ..addFile(
        ArchiveFile.string('xl/_rels/workbook.xml.rels', _workbookRelationships),
      )
      ..addFile(
        ArchiveFile.string('xl/worksheets/sheet1.xml', _sheetXml(rows)),
      );
    return ZipEncoder().encodeBytes(archive);
  }

  static String _sheetXml(List<List<String>> rows) {
    final buffer = StringBuffer()
      ..write(_xmlDeclaration)
      ..write(
        '<worksheet xmlns="http://schemas.openxmlformats.org/'
        'spreadsheetml/2006/main"><sheetData>',
      );
    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final cells = rows[rowIndex];
      buffer.write('<row r="${rowIndex + 1}">');
      for (var columnIndex = 0; columnIndex < cells.length; columnIndex++) {
        buffer.write(
          _cellXml(cells[columnIndex], rowIndex + 1, columnIndex),
        );
      }
      buffer.write('</row>');
    }
    return (buffer..write('</sheetData></worksheet>')).toString();
  }

  static String _cellXml(String value, int rowNumber, int columnIndex) {
    final reference = '${_columnName(columnIndex)}$rowNumber';
    if (value.isEmpty) return '<c r="$reference"/>';
    if (_numberPattern.hasMatch(value)) {
      // Ghi số thành số để kế toán cộng được ngay trong Excel. Mẫu khớp cố ý
      // loại các chuỗi có số 0 đứng đầu: số tài khoản `0011000` là một nhãn, và
      // để Excel hiểu nó là số 11000 thì file xuất đã làm hỏng dữ liệu.
      return '<c r="$reference"><v>$value</v></c>';
    }
    return '<c r="$reference" t="inlineStr"><is><t xml:space="preserve">'
        '${_escape(value)}</t></is></c>';
  }

  /// Chỉ số cột 0-based thành tên cột của Excel (`0` → `A`, `26` → `AA`).
  static String _columnName(int index) {
    final letters = StringBuffer();
    var remaining = index + 1;
    while (remaining > 0) {
      final digit = (remaining - 1) % 26;
      letters.write(String.fromCharCode(0x41 + digit));
      remaining = (remaining - 1) ~/ 26;
    }
    return String.fromCharCodes(letters.toString().codeUnits.reversed);
  }

  /// Thoát năm ký tự XML, cộng thêm các ký tự điều khiển.
  ///
  /// Nội dung chuyển khoản đến từ file của ngân hàng và không có gì bảo đảm nó
  /// sạch; một ký tự điều khiển lọt vào sẽ làm cả file `.xlsx` không mở được, và
  /// lỗi hiện ra ở Excel chứ không ở đây.
  static String _escape(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      switch (rune) {
        case 0x26:
          buffer.write('&amp;');
        case 0x3C:
          buffer.write('&lt;');
        case 0x3E:
          buffer.write('&gt;');
        case 0x22:
          buffer.write('&quot;');
        case 0x27:
          buffer.write('&apos;');
        default:
          if (rune == 0x09 || rune == 0x0A || rune == 0x0D || rune >= 0x20) {
            buffer.write(String.fromCharCode(rune));
          }
      }
    }
    return buffer.toString();
  }

  static const String _xmlDeclaration =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>';

  static const String _contentTypes =
      '$_xmlDeclaration'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/'
      'content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-'
      'package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.'
      'openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/'
      'vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
      '</Types>';

  static const String _rootRelationships =
      '$_xmlDeclaration'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/officeDocument" Target="xl/'
      'workbook.xml"/>'
      '</Relationships>';

  static const String _workbook =
      '$_xmlDeclaration'
      '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/'
      'main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/'
      'relationships">'
      '<sheets><sheet name="LedgerTracer" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';

  static const String _workbookRelationships =
      '$_xmlDeclaration'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/'
      'relationships">'
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/'
      'officeDocument/2006/relationships/worksheet" Target="worksheets/'
      'sheet1.xml"/>'
      '</Relationships>';

  /// Số nguyên hoặc số thập phân, không có số 0 vô nghĩa đứng đầu.
  static final RegExp _numberPattern = RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?$');
}
