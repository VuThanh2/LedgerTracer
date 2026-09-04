import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';

/// Trục gom nhóm của biểu đồ dòng tiền: theo thời gian hay theo tài khoản (UC-10
/// bước 2–3).
enum CashFlowGrouping { byPeriod, byAccount }

/// Tiêu chí một lần xem thống kê dòng tiền (UC-10).
///
/// Số liệu luôn tính cho **đúng một loại tiền** — các loại tiền khác nhau không
/// bao giờ cộng gộp và không quy đổi (Rule – Currency Belongs to the Transaction
/// and Never Mixes).
final class ViewCashFlowRequest {
  const ViewCashFlowRequest({
    required this.currency,
    this.grouping = CashFlowGrouping.byPeriod,
    this.period = CashFlowPeriod.month,
    this.dateRange,
    this.excludeInternalTransfers = true,
  });

  final Currency currency;

  final CashFlowGrouping grouping;

  /// Độ mịn thời gian khi gom theo thời gian; bỏ qua khi gom theo tài khoản.
  final CashFlowPeriod period;

  final DateRange? dateRange;

  /// Loại trừ các cặp nội bộ **đã xác nhận** khỏi số tổng. Mặc định bật, vì dòng
  /// tiền thực với bên ngoài mới là con số người dùng cần; trạng thái này không
  /// được ghi nhớ giữa các lần mở màn hình (UC-10).
  final bool excludeInternalTransfers;
}

/// Kết quả thống kê cho một loại tiền và một trục gom nhóm.
final class CashFlowSeries {
  const CashFlowSeries({
    required this.currency,
    required this.grouping,
    required this.excludeInternalTransfers,
    required this.buckets,
    this.accountNames = const <int, String>{},
  });

  final Currency currency;

  final CashFlowGrouping grouping;

  final bool excludeInternalTransfers;

  final List<CashFlowBucket> buckets;

  /// Tên tài khoản cho từng cột khi gom theo tài khoản; rỗng khi gom theo thời
  /// gian. Mỗi số tiền hiển thị vẫn phải kèm mã loại tiền (UC-04, UC-10).
  final Map<int, String> accountNames;
}
