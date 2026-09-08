import '../../../../application/export/export_dataset/export_dataset_dto.dart';
import '../../../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../../domain/value_objects/currency.dart';
import '../../../../domain/value_objects/date_range.dart';
import '../../../../domain/value_objects/pair_status.dart';
import '../../../transactions/view_models/filter_chip_view_model.dart';
import '../../../transactions/view_models/transaction_context.dart';

/// Điểm vào của Export Dialog: **cái gì** đang được xuất (UC-11).
///
/// Dialog có năm điểm vào và chỉ một luồng, nên thứ khác nhau giữa chúng được gói
/// vào đúng một kiểu tổng đóng. Định dạng file (CSV/Excel) **không** nằm ở đây:
/// nó là thứ người dùng chọn **trong** dialog, còn cái này là thứ họ mang tới.
///
/// [criteriaLines] là bản **xem trước** các tiêu chí, hiện trong dialog trước khi
/// người dùng bấm xuất. Nó nằm ở tầng Presentation vì đúng nơi này mới biết người
/// dùng đang **nhìn thấy** gì — chip nào đang bật, nhóm phán quyết nào đang chọn.
///
/// Phần đầu file thật sự do `ExportDatasetUseCase` tự dựng từ chính bộ tiêu chí
/// nó chạy, chứ không nhận chuỗi từ đây: một danh sách chữ đi kèm có thể lệch
/// khỏi truy vấn thực sự mà không có gì báo. Hai bên vì thế phải nói cùng một
/// điều — thêm tiêu chí mới thì sửa cả hai.
sealed class ExportSource {
  const ExportSource();

  /// Nhãn ngắn cho tiêu đề dialog.
  String get title;

  /// Các tiêu chí đang áp dụng, để dialog hiện ra trước khi người dùng bấm xuất.
  List<String> get criteriaLines;

  ExportRequest toRequest(ExportFormat format);
}

/// Xuất danh sách giao dịch đang xem (UC-04, UC-06, UC-07 → UC-11).
final class ExportTransactionsSource extends ExportSource {
  const ExportTransactionsSource({
    required this.filter,
    required this.context,
    required this.chips,
  });

  final TransactionFilter filter;

  final TransactionContext context;

  /// Chip đang hiển thị, dùng nguyên vẹn làm danh sách tiêu chí — cùng một nguồn
  /// sự thật với thanh chip trên màn hình, nên file xuất không bao giờ mô tả một
  /// tập dữ liệu khác thứ người dùng đang nhìn.
  final List<FilterChipViewModel> chips;

  @override
  String get title => 'Export transactions';

  @override
  List<String> get criteriaLines => chips.isEmpty
      ? const <String>['No filter applied.']
      : <String>[for (final chip in chips) chip.label];

  /// Bộ lọc gửi xuống use case, đã gộp cả ngữ cảnh.
  ///
  /// Đây là **cùng một** bộ tiêu chí mà danh sách đang hiển thị dùng, nên file
  /// xuất không bao giờ rộng hơn thứ người dùng vừa nhìn, và [criteriaLines] ghi
  /// ở đầu file mô tả đúng tập dữ liệu bên dưới nó (UC-11).
  @override
  ExportRequest toRequest(ExportFormat format) =>
      ExportTransactions(filter: context.narrow(filter), format: format);
}

/// Xuất kết quả đối soát (UC-09 → UC-11).
final class ExportReconciliationSource extends ExportSource {
  const ExportReconciliationSource({required this.status, this.groupLabel});

  /// Nhóm phán quyết đang chọn; `null` để xuất tất cả.
  final PairStatus? status;

  final String? groupLabel;

  @override
  String get title => 'Export reconciliation results';

  @override
  List<String> get criteriaLines => <String>['Group: ${groupLabel ?? 'all'}'];

  @override
  ExportRequest toRequest(ExportFormat format) =>
      ExportReconciliation(status: status, format: format);
}

/// Xuất số liệu thống kê (UC-10 → UC-11).
final class ExportStatisticsSource extends ExportSource {
  const ExportStatisticsSource({
    required this.currency,
    required this.grouping,
    required this.period,
    required this.dateRange,
    required this.excludeInternalTransfers,
  });

  final Currency currency;
  final CashFlowGrouping grouping;
  final CashFlowPeriod period;
  final DateRange? dateRange;

  /// Trạng thái công tắc loại trừ. Ở nguồn xuất này nó **đi được** vào file, vì
  /// đường đọc thống kê nhận nó như một tham số thật.
  final bool excludeInternalTransfers;

  @override
  String get title => 'Export statistics';

  @override
  List<String> get criteriaLines => <String>[
    'Currency: ${currency.code}',
    'Grouped by: '
        '${grouping == CashFlowGrouping.byAccount ? 'account' : period.name}',
    if (dateRange != null) 'Date range: $dateRange',
    'Excluding confirmed internal transfers: '
        '${excludeInternalTransfers ? 'yes' : 'no'}',
  ];

  @override
  ExportRequest toRequest(ExportFormat format) => ExportStatistics(
    currency: currency,
    grouping: grouping,
    period: period,
    dateRange: dateRange,
    excludeInternalTransfers: excludeInternalTransfers,
    format: format,
  );
}

/// Xuất danh sách dòng lỗi của một bản ghi nhập (UC-02 bước 8, UC-03 → UC-11).
///
/// Số thứ tự dòng gốc và lý do là hai cột làm cho luồng "sửa trên file gốc rồi
/// nhập lại" khả thi — đó là lý do nguồn xuất này tồn tại.
final class ExportErrorRowsSource extends ExportSource {
  const ExportErrorRowsSource({
    required this.importFileRecordId,
    required this.fileName,
  });

  final int importFileRecordId;
  final String fileName;

  @override
  String get title => 'Export error rows';

  @override
  List<String> get criteriaLines => <String>['File: $fileName'];

  @override
  ExportRequest toRequest(ExportFormat format) =>
      ExportErrorRows(importFileRecordId: importFileRecordId, format: format);
}
