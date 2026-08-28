import 'dart:convert';
import 'dart:typed_data';

import '../../application/import/contracts/statement_parser.dart';
import '../../domain/value_objects/statement_format.dart';

/// Nhận diện định dạng của một file người dùng vừa chọn (UC-02 bước 2).
///
/// Người dùng chỉ chọn file mình đang có sẵn và không bao giờ phải biết hay quan
/// tâm tới định dạng kỹ thuật bên dưới. Vì vậy phán quyết dựa trên **nội dung**
/// trước; phần mở rộng chỉ là gợi ý phụ, vì nó có thể sai, có thể bị đổi, và có
/// thể không có.
///
/// `null` là câu trả lời hợp lệ và quan trọng: nó nói "file này không thuộc bốn
/// định dạng được hỗ trợ", và luồng nhập biến nó thành một `UnrecognizedFile`
/// hiển thị riêng nó là lỗi — chứ không kéo theo những file còn lại trong cùng
/// lượt (UC-02).
final class ContentStatementFormatDetector
    implements StatementFormatDetector {
  const ContentStatementFormatDetector();

  @override
  StatementFormat? detect({
    required String fileName,
    required Uint8List head,
  }) {
    if (_startsWith(head, _zipSignature)) {
      // ZIP là vỏ của rất nhiều thứ (`.docx`, `.odt`, `.apk`); chỉ khi bên trong
      // có thư mục `xl/` thì đây mới là workbook Excel.
      return _looksLikeSpreadsheet(head) ? StatementFormat.excel : null;
    }
    // `.xls` đời cũ (OLE2) nằm ngoài phạm vi — xem ghi chú giới hạn ở
    // `ExcelParser`. Nhận ra nó ở đây để trả `null` một cách có chủ đích thay vì
    // để nó rơi vào nhánh CSV rồi hỏng theo kiểu khó hiểu.
    if (_startsWith(head, _ole2Signature)) return null;

    final text = utf8.decode(head, allowMalformed: true);
    final trimmed = text.trimLeft();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      // `{1:` mở đầu một khối SWIFT, không phải một object JSON.
      return trimmed.startsWith('{1:')
          ? StatementFormat.mt940
          : StatementFormat.json;
    }
    if (_mt940Pattern.hasMatch(text)) return StatementFormat.mt940;
    if (_looksLikeText(head)) return StatementFormat.csv;

    // Nội dung không kết luận được thì mới tới lượt tên file: một file CSV rỗng
    // hoặc chỉ có phần giới thiệu vẫn nên được nhận là CSV để luồng nhập báo
    // đúng "không tìm thấy dòng tiêu đề" thay vì "không nhận ra định dạng".
    return _formatFromExtension(fileName);
  }

  static bool _looksLikeSpreadsheet(Uint8List head) {
    final text = latin1.decode(head, allowInvalid: true);
    return text.contains('xl/') || text.contains('workbook.xml');
  }

  /// File có phải văn bản không, đo bằng sự vắng mặt của byte 0.
  ///
  /// Đủ để tách một file nhị phân lạ khỏi một file CSV; kết luận cuối cùng "đây
  /// có phải sao kê không" vẫn thuộc về parser, nơi dòng tiêu đề là bằng chứng.
  static bool _looksLikeText(Uint8List head) {
    final limit = head.length < _textProbeLength ? head.length : _textProbeLength;
    for (var index = 0; index < limit; index++) {
      if (head[index] == 0) return false;
    }
    return limit > 0;
  }

  static StatementFormat? _formatFromExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0) return null;
    return switch (fileName.substring(dot + 1).toLowerCase()) {
      'csv' || 'txt' || 'tsv' => StatementFormat.csv,
      'json' => StatementFormat.json,
      'sta' || 'mt940' || 'swi' => StatementFormat.mt940,
      'xlsx' => StatementFormat.excel,
      _ => null,
    };
  }

  static bool _startsWith(Uint8List bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  static const int _textProbeLength = 4096;

  static const List<int> _zipSignature = <int>[0x50, 0x4B, 0x03, 0x04];

  /// Chữ ký của tài liệu OLE2 — vỏ của `.xls`, `.doc` đời cũ.
  static const List<int> _ole2Signature = <int>[
    0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1,
  ];

  /// Trường bắt buộc của MT940: mã tham chiếu, số tài khoản, hoặc dòng giao
  /// dịch, mỗi cái ở đầu một dòng.
  static final RegExp _mt940Pattern = RegExp(
    r'(^|\n):(20|25|28C?|61):',
  );
}
