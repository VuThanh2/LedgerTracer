import 'dart:typed_data';

import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../statistics/view_cash_flow/view_cash_flow_dto.dart';

/// Định dạng file xuất (UC-11). Không có định dạng mã hoá ở đây: file xuất tồn
/// tại để mở bằng Excel hoặc gửi cho kế toán, khác hẳn file sao lưu ở UC-13.
enum ExportFormat { csv, excel }

/// Nguồn dữ liệu xuất, cùng bốn điểm vào của UC-11. Là kiểu tổng đóng nên use
/// case `switch` được vét cạn.
///
/// File xuất phải phản ánh **đúng trạng thái người dùng đang xem**: danh sách
/// giao dịch theo từ khoá và bộ lọc đang áp dụng, thống kê theo loại tiền và tuỳ
/// chọn loại trừ đang bật. Các tiêu chí đó, **kèm loại tiền**, được ghi ở đầu
/// file để người nhận biết dữ liệu đã bị thu hẹp bởi điều kiện gì.
sealed class ExportRequest {
  const ExportRequest(this.format);

  final ExportFormat format;
}

/// Danh sách giao dịch theo bộ lọc đang áp dụng (UC-04, UC-06, UC-07).
final class ExportTransactions extends ExportRequest {
  const ExportTransactions({
    required this.filter,
    required ExportFormat format,
  }) : super(format);

  final TransactionFilter filter;
}

/// Kết quả đối soát (UC-09).
final class ExportReconciliation extends ExportRequest {
  const ExportReconciliation({this.status, required ExportFormat format})
    : super(format);

  final PairStatus? status;
}

/// Số liệu thống kê theo loại tiền đang mở và trạng thái tuỳ chọn loại trừ
/// (UC-10).
final class ExportStatistics extends ExportRequest {
  const ExportStatistics({
    required this.currency,
    required this.grouping,
    this.period = CashFlowPeriod.month,
    this.dateRange,
    this.excludeInternalTransfers = true,
    required ExportFormat format,
  }) : super(format);

  final Currency currency;
  final CashFlowGrouping grouping;
  final CashFlowPeriod period;
  final DateRange? dateRange;
  final bool excludeInternalTransfers;
}

/// Danh sách dòng lỗi của một lượt nhập (UC-02 bước 8, UC-03).
final class ExportErrorRows extends ExportRequest {
  const ExportErrorRows({
    required this.importFileRecordId,
    required ExportFormat format,
  }) : super(format);

  final int importFileRecordId;
}

/// Bảng dữ liệu trung gian: mấy dòng chú thích ở đầu, một dòng tiêu đề cột, rồi
/// các dòng dữ liệu đã thành chuỗi.
///
/// Tầng Application dựng bảng vì nó biết cột nào và chú thích gì; biến bảng thành
/// bytes CSV/Excel là việc của Infrastructure qua [TabularExporter]. Chia thế này
/// giữ cho Application không dính tới chi tiết định dạng file.
final class ExportTable {
  const ExportTable({
    required this.metadata,
    required this.headers,
    required this.rows,
  });

  /// Các tiêu chí đang áp dụng, kèm loại tiền — ghi ở đầu file (UC-11).
  final List<String> metadata;

  final List<String> headers;

  final List<List<String>> rows;

  int get rowCount => rows.length;
}

/// File đã lưu về thiết bị hoặc đã đẩy qua cơ chế tải xuống của trình duyệt.
final class SavedFile {
  const SavedFile({this.path, required this.viaBrowserDownload});

  /// Đường dẫn trên thiết bị (Android). `null` trên Web — trình duyệt không cho
  /// chọn đường dẫn lưu (UC-11).
  final String? path;

  final bool viaBrowserDownload;
}

/// Kết quả một lần xuất, cho giao diện báo đã xuất bao nhiêu dòng và ra đâu.
final class ExportResult {
  const ExportResult({required this.file, required this.rowCount});

  final SavedFile file;
  final int rowCount;
}

/// Biến [ExportTable] thành bytes theo định dạng, không mã hoá (UC-11). Hiện thực
/// ở Infrastructure và tự lo việc đẩy phần nặng ra khỏi luồng giao diện nếu cần.
abstract interface class TabularExporter {
  Future<Uint8List> toBytes(ExportTable table, ExportFormat format);
}

/// Lưu bytes thành file. Trên Android người dùng chọn vị trí; trên Web file đi
/// qua cơ chế tải xuống (UC-11).
abstract interface class FileSaver {
  Future<SavedFile> save({
    required Uint8List bytes,
    required String suggestedName,
    required ExportFormat format,
  });
}
