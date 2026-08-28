import 'dart:convert';
import 'dart:typed_data';

import '../../application/export/export_dataset/export_dataset_dto.dart';

/// Biến một [ExportTable] thành bytes CSV (UC-11).
///
/// File xuất **không được mã hoá**: nó tồn tại để mở bằng Excel hoặc gửi cho kế
/// toán, và mã hoá sẽ triệt tiêu chính mục đích đó. Nguyên tắc riêng tư ngăn dữ
/// liệu bị gửi tới bên thứ ba, không ngăn người dùng lấy dữ liệu của chính họ
/// ra (khác hẳn file sao lưu ở UC-13).
abstract final class CsvExporter {
  static Uint8List encode(ExportTable table) {
    final buffer = StringBuffer()
      // Gợi ý ký tự phân tách cho Excel, bắt buộc phải là dòng đầu tiên.
      //
      // Không phải trang trí: Excel chạy trên máy dùng dấu phẩy làm dấu thập
      // phân — mặc định của Windows tiếng Việt — sẽ dồn cả file vào một cột nếu
      // không có dòng này. Một file xuất mà kế toán mở ra thấy một cột là một
      // file xuất hỏng, dù nội dung đúng đến đâu.
      ..writeln('sep=$_separator')
      // Các tiêu chí đang áp dụng, **kèm loại tiền**: thiếu chúng thì người nhận
      // file không có cách nào biết dữ liệu đã bị thu hẹp bởi điều kiện gì, và
      // một bảng số liệu không ghi đơn vị tiền tệ sẽ bị mặc định hiểu là VND.
      ..writeAll(table.metadata.map((line) => '${_escape('# $line')}\n'))
      ..writeln(table.headers.map(_escape).join(_separator));
    for (final row in table.rows) {
      buffer.writeln(row.map(_escape).join(_separator));
    }

    // BOM của UTF-8: không có nó, Excel đọc file theo bảng mã hệ thống và mọi
    // dấu tiếng Việt trong nội dung chuyển khoản thành ký tự rác.
    return Uint8List.fromList(<int>[
      ..._byteOrderMark,
      ...utf8.encode(buffer.toString()),
    ]);
  }

  /// Đặt một ô vào dấu nháy khi nó chứa ký tự phân tách, dấu nháy hoặc xuống
  /// dòng — đúng quy ước RFC 4180 mà `CsvParser` đọc lại được.
  static String _escape(String value) {
    if (!value.contains(_separator) &&
        !value.contains('"') &&
        !value.contains('\n') &&
        !value.contains('\r')) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  static const String _separator = ',';
  static const List<int> _byteOrderMark = <int>[0xEF, 0xBB, 0xBF];
}
