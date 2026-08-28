import 'dart:typed_data';

import '../../application/export/export_dataset/export_dataset_dto.dart';
import 'csv_exporter.dart';
import 'excel_exporter.dart';

/// Hiện thực [TabularExporter]: chọn bộ mã hoá theo định dạng người dùng đã chọn
/// (UC-11 bước 2).
///
/// **Ràng buộc bắt buộc — object này đi qua ranh giới isolate**, cùng lý do và
/// cùng điều kiện với `StatementParser`: bất biến, không giữ tài nguyên gắn với
/// luồng gốc, không phụ thuộc container DI. Vì thế nó là một lớp hằng chỉ gồm
/// một phép rẽ nhánh, và cả hai bộ mã hoá đều là hàm thuần.
///
/// Việc đẩy phép mã hoá ra khỏi luồng giao diện **không** phải việc của lớp này:
/// nó chỉ là một phép biến đổi thuần và đồng bộ. Chính sách concurrency cho cả
/// ba workload của ứng dụng nằm ở tầng Application — để mỗi hiện thực
/// Infrastructure tự xoay xở là có ba chính sách khác nhau ở ba chỗ không ai
/// nhìn thấy cùng lúc.
final class SpreadsheetExporter implements TabularExporter {
  const SpreadsheetExporter();

  @override
  Uint8List toBytes(ExportTable table, ExportFormat format) =>
      switch (format) {
        ExportFormat.csv => CsvExporter.encode(table),
        ExportFormat.excel => ExcelExporter.encode(table),
      };
}
