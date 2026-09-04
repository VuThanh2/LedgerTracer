import '../../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';
import '../../../domain/value_objects/money.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/money_formatter.dart';
import '../../shell/view_models/navigation_intent.dart';
import '../../transactions/view_models/transaction_context.dart';
import '../../transactions/view_models/transaction_filter_draft.dart';

/// Một cột của biểu đồ dòng tiền (UC-10).
///
/// Mang theo cả chữ lẫn số: chữ để vẽ nhãn, số để tính chiều cao cột. Giữ lại
/// `minorUnits` chứ không đọc ngược từ chuỗi đã định dạng — chuỗi đã có dấu phân
/// nhóm và dấu, và phân tích ngược nó là chỗ một dấu chấm biến một triệu thành
/// một.
final class CashFlowBarViewModel {
  const CashFlowBarViewModel({
    required this.label,
    required this.inflowText,
    required this.outflowText,
    required this.netText,
    required this.inflowMinorUnits,
    required this.outflowMinorUnits,
    required this.netMinorUnits,
    this.periodStart,
    this.accountId,
  });

  final String label;

  final String inflowText;

  /// Tiền ra **giữ nguyên dấu âm**, đúng như tầng dưới trả về: nhờ vậy "ròng"
  /// chỉ là một phép cộng, và dấu trên nhãn không phải một quy ước riêng của
  /// giao diện.
  final String outflowText;

  final String netText;

  final int inflowMinorUnits;
  final int outflowMinorUnits;
  final int netMinorUnits;

  /// Mốc thời gian của cột, khi gom theo thời gian — đi kèm khi khoan xuống danh
  /// sách giao dịch (UC-10 → UC-04).
  final DateTime? periodStart;

  /// Tài khoản của cột, khi gom theo tài khoản.
  final int? accountId;

  /// Bề rộng cột lớn nhất mà cột này cần, để chuẩn hoá thang đo.
  int get magnitude => inflowMinorUnits.abs() > outflowMinorUnits.abs()
      ? inflowMinorUnits.abs()
      : outflowMinorUnits.abs();
}

/// Một biểu đồ hoàn chỉnh: các cột, thang đo, và tổng cộng.
final class CashFlowChartViewModel {
  const CashFlowChartViewModel({
    required this.grouping,
    required this.currencyCode,
    required this.bars,
    required this.maxMagnitude,
    required this.totalInflowText,
    required this.totalOutflowText,
    required this.totalNetText,
  });

  factory CashFlowChartViewModel.of(
    CashFlowSeries series, {
    required CashFlowPeriod period,
  }) {
    final bars = <CashFlowBarViewModel>[
      for (final bucket in series.buckets)
        CashFlowBarViewModel(
          // Kiểu tổng đóng nên nhãn lấy được mà không cần một dấu `!` nào: một
          // cột hoặc thuộc một mốc thời gian, hoặc thuộc một tài khoản.
          label: switch (bucket) {
            PeriodCashFlow(:final periodStart) => DateFormatter.period(
              periodStart,
              period,
            ),
            AccountCashFlow(:final accountId) =>
              series.accountNames[accountId] ?? '',
          },
          inflowText: MoneyFormatter.signed(bucket.inflow),
          outflowText: MoneyFormatter.signed(bucket.outflow),
          netText: MoneyFormatter.signed(bucket.net),
          inflowMinorUnits: bucket.inflow.minorUnits,
          outflowMinorUnits: bucket.outflow.minorUnits,
          netMinorUnits: bucket.net.minorUnits,
          periodStart: switch (bucket) {
            PeriodCashFlow(:final periodStart) => periodStart,
            AccountCashFlow() => null,
          },
          accountId: switch (bucket) {
            PeriodCashFlow() => null,
            AccountCashFlow(:final accountId) => accountId,
          },
        ),
    ];

    // Cộng dồn bằng `Money` chứ không bằng `int` trần: phép cộng của nó từ chối
    // hai loại tiền khác nhau, nên một lỗi gom nhóm sẽ nổ ra ngay tại đây thay
    // vì đi tiếp thành một con số tổng vô nghĩa.
    var inflow = Money.zero(series.currency);
    var outflow = Money.zero(series.currency);
    var maxMagnitude = 0;
    for (final bar in bars) {
      inflow += Money(bar.inflowMinorUnits, series.currency);
      outflow += Money(bar.outflowMinorUnits, series.currency);
      if (bar.magnitude > maxMagnitude) maxMagnitude = bar.magnitude;
    }

    return CashFlowChartViewModel(
      grouping: series.grouping,
      currencyCode: series.currency.code,
      bars: bars,
      maxMagnitude: maxMagnitude,
      totalInflowText: MoneyFormatter.signedWithCurrency(inflow),
      totalOutflowText: MoneyFormatter.signedWithCurrency(outflow),
      totalNetText: MoneyFormatter.signedWithCurrency(inflow + outflow),
    );
  }

  final CashFlowGrouping grouping;

  /// Mọi số tiền hiển thị đều kèm mã loại tiền: số liệu của các loại tiền khác
  /// nhau không bao giờ cộng gộp và không quy đổi (UC-10).
  final String currencyCode;

  final List<CashFlowBarViewModel> bars;

  /// Giá trị tuyệt đối lớn nhất trong biểu đồ — mẫu số của thang đo. `0` khi
  /// không có dữ liệu, và giao diện phải tránh chia cho nó.
  final int maxMagnitude;

  final String totalInflowText;
  final String totalOutflowText;
  final String totalNetText;

  bool get isEmpty => bars.isEmpty;
}

/// Ngữ cảnh mà một lần khoan xuống mang sang danh sách giao dịch (UC-10 →
/// UC-04).
///
/// Ba thứ đi cùng nhau và phải đi cùng nhau: khoảng ngày của cột, loại tiền của
/// tab đang mở, và **trạng thái công tắc loại trừ**. Thiếu bất kỳ cái nào thì
/// tập dữ liệu ở màn hình đích không còn trùng với con số người dùng vừa bấm
/// vào, và họ sẽ tin là một trong hai màn hình đang sai.
final class CashFlowDrillDown {
  const CashFlowDrillDown({
    required this.currency,
    required this.excludeInternalTransfers,
    this.dateRange,
    this.accountId,
  });

  final Currency currency;
  final bool excludeInternalTransfers;
  final DateRange? dateRange;
  final int? accountId;

  /// Đổi thành yêu cầu điều hướng sang danh sách giao dịch.
  ///
  /// Phép đổi nằm ở đây chứ không ở giao diện, và đó là điểm mấu chốt: chỗ nào
  /// tự ghép tay một `OpenTransactions` cũng có thể quên một trong ba mảnh ngữ
  /// cảnh, và thiếu mảnh nào thì tập dữ liệu ở màn hình đích không còn trùng với
  /// con số người dùng vừa bấm vào — họ sẽ tin là một trong hai màn hình đang
  /// sai. Một hàm duy nhất thì không quên được.
  ///
  /// [TransactionFilterDraft.filterByCurrency] bật lên là bắt buộc: loại tiền ở
  /// đây là **tiêu chí** người dùng đã chọn qua tab, không phải giá trị điền sẵn
  /// của ô loại tiền.
  OpenTransactions toIntent() => OpenTransactions(
    context: TransactionContext.fromStatistics(
      excludeInternalTransfers: excludeInternalTransfers,
    ),
    draft: TransactionFilterDraft(
      accountId: accountId,
      dateFrom: dateRange?.from,
      dateTo: dateRange?.to,
      currency: currency,
      filterByCurrency: true,
    ),
  );

  /// Khoảng ngày mà **một cột** của biểu đồ theo thời gian đại diện.
  ///
  /// Cột chỉ mang ngày đầu mốc, nên khoan xuống bằng đúng ngày đó sẽ trả về một
  /// ngày trong khi người dùng vừa bấm vào cả một tháng. Đây là nơi duy nhất
  /// dựng lại bề rộng của mốc, và nó phải trùng với cách tầng dưới gom nhóm.
  static DateRange rangeOf(DateTime periodStart, CashFlowPeriod period) {
    final start = DateRange.dateOnly(periodStart);
    return switch (period) {
      CashFlowPeriod.day => DateRange.singleDay(start),
      // Ngày 0 của tháng kế tiếp chính là ngày cuối của tháng này — không phải
      // đếm tay 28/29/30/31.
      CashFlowPeriod.month => DateRange(
        from: DateTime.utc(start.year, start.month, 1),
        to: DateTime.utc(start.year, start.month + 1, 0),
      ),
      CashFlowPeriod.year => DateRange(
        from: DateTime.utc(start.year, 1, 1),
        to: DateTime.utc(start.year, 12, 31),
      ),
    };
  }
}
