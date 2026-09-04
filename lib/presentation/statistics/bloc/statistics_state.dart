import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/queries/account_activity.dart';
import '../../shell/view_models/navigation_intent.dart';
import '../view_models/cash_flow_view_model.dart';

/// Công tắc loại trừ đang bật nhưng không loại được gì — và người dùng cần làm
/// gì để nó có tác dụng (UC-10).
///
/// Tồn tại vì một cái bẫy rất dễ mắc: công tắc mặc định **bật**, nên người dùng
/// mới cài ứng dụng sẽ thấy nó bật và tin rằng chuyển khoản nội bộ đã được loại
/// khỏi con số họ đang đọc — trong khi chưa có cặp nào được xác nhận thì nó
/// chẳng loại được gì cả. Ghi chú này nói ra điều đó, và dẫn đúng chỗ cần đi.
enum ZeroEffectNotice {
  /// Không có gì để nhắc.
  none,

  /// Dưới hai tài khoản có giao dịch: đối soát chưa có gì để ghép, nên đường đi
  /// tiếp là **Nhập** thêm sao kê của tài khoản thứ hai.
  needsMoreAccounts,

  /// Đã đủ tài khoản nhưng chưa xác nhận cặp nào: đường đi tiếp là **Đối soát**.
  needsConfirmedPairs,
}

/// Trạng thái màn hình thống kê (UC-10).
final class StatisticsState {
  const StatisticsState({
    this.status = LoadStatus.initial,
    this.currencies = const <CurrencyUsage>[],
    this.currency,
    this.period = CashFlowPeriod.month,
    this.dateRange,
    this.excludeInternalTransfers = true,
    this.byPeriod,
    this.byAccount,
    this.confirmedPairCount = 0,
    this.accountsWithTransactions = 0,
    this.error,
  });

  final LoadStatus status;

  /// Các loại tiền đang có, nhiều giao dịch nhất trước.
  ///
  /// Dãy tab **luôn nhìn thấy**, kể cả khi chỉ có một loại tiền: sự tồn tại của
  /// loại tiền khác phải nhìn thấy được ngay, để người chủ yếu thu VND không
  /// tưởng một con số là toàn bộ dòng tiền (UC-10).
  final List<CurrencyUsage> currencies;

  /// Tab đang mở; `null` khi chưa có giao dịch nào.
  final Currency? currency;

  final CashFlowPeriod period;

  /// Khoảng ngày đang thu hẹp số liệu.
  ///
  /// Luôn `null` ở bản này: bản thiết kế không có ô chọn khoảng ngày ở màn
  /// Thống kê — người dùng thu hẹp bằng cách bấm vào một cột rồi khoan xuống
  /// danh sách giao dịch, nơi bộ lọc ngày đã có sẵn. Trường và sự kiện
  /// `StatisticsDateRangeChanged` vẫn ở đây vì use case nhận được nó, nên thêm
  /// ô chọn về sau chỉ là thêm widget chứ không phải sửa luồng dữ liệu.
  final DateRange? dateRange;

  /// Mặc định bật, **không** ghi nhớ giữa các lần mở màn hình (UC-10).
  final bool excludeInternalTransfers;

  /// Biểu đồ theo thời gian.
  final CashFlowChartViewModel? byPeriod;

  /// Biểu đồ theo tài khoản.
  ///
  /// Cả hai được nạp cùng lúc chứ không theo tab đang xem, vì bố cục rộng hiển
  /// thị chúng **cạnh nhau** — nạp theo tab nghĩa là ở bố cục đó lúc nào cũng có
  /// đúng một nửa màn hình đang chờ.
  final CashFlowChartViewModel? byAccount;

  final int confirmedPairCount;

  final int accountsWithTransactions;

  final FeedbackMessage? error;

  bool get isEmpty => status.isReady && currencies.isEmpty;

  /// Ghi chú "công tắc không có tác dụng" (UC-10).
  ZeroEffectNotice get zeroEffectNotice {
    if (!excludeInternalTransfers || confirmedPairCount > 0) {
      return ZeroEffectNotice.none;
    }
    return accountsWithTransactions <
            AccountActivity.minimumAccountsForReconciliation
        ? ZeroEffectNotice.needsMoreAccounts
        : ZeroEffectNotice.needsConfirmedPairs;
  }

  /// Ngữ cảnh mang sang danh sách giao dịch khi bấm vào một cột (UC-10 → UC-04).
  ///
  /// Khoảng ngày của cột do giao diện tính (nó biết cột nào vừa bị bấm và độ mịn
  /// nào đang chọn); những gì còn lại — loại tiền, tài khoản, và **trạng thái
  /// công tắc loại trừ** — lấy từ đây, để không đường điều hướng nào quên mang
  /// theo một trong ba.
  CashFlowDrillDown? drillDown({DateRange? dateRange, int? accountId}) {
    final selected = currency;
    if (selected == null) return null;
    return CashFlowDrillDown(
      currency: selected,
      excludeInternalTransfers: excludeInternalTransfers,
      dateRange: dateRange ?? this.dateRange,
      accountId: accountId,
    );
  }

  /// Yêu cầu điều hướng khi bấm vào **một cột** của biểu đồ (UC-10 → UC-04).
  ///
  /// Nhận thẳng cột chứ không nhận khoảng ngày, vì bề rộng của mốc suy ra từ độ
  /// mịn đang chọn: bấm vào một cột tháng phải mở ra cả tháng, không phải ngày
  /// đầu tháng. Cột theo tài khoản thì giữ nguyên khoảng ngày đang lọc và mang
  /// thêm tài khoản.
  OpenTransactions? drillDownForBar(CashFlowBarViewModel bar) {
    final periodStart = bar.periodStart;
    return drillDown(
      dateRange: periodStart == null
          ? dateRange
          : CashFlowDrillDown.rangeOf(periodStart, period),
      accountId: bar.accountId,
    )?.toIntent();
  }

  StatisticsState copyWith({
    LoadStatus? status,
    List<CurrencyUsage>? currencies,
    Currency? currency,
    CashFlowPeriod? period,
    DateRange? dateRange,
    bool clearDateRange = false,
    bool? excludeInternalTransfers,
    CashFlowChartViewModel? byPeriod,
    CashFlowChartViewModel? byAccount,
    int? confirmedPairCount,
    int? accountsWithTransactions,
    FeedbackMessage? error,
    bool clearError = false,
  }) => StatisticsState(
    status: status ?? this.status,
    currencies: currencies ?? this.currencies,
    currency: currency ?? this.currency,
    period: period ?? this.period,
    dateRange: clearDateRange ? null : (dateRange ?? this.dateRange),
    excludeInternalTransfers:
        excludeInternalTransfers ?? this.excludeInternalTransfers,
    byPeriod: byPeriod ?? this.byPeriod,
    byAccount: byAccount ?? this.byAccount,
    confirmedPairCount: confirmedPairCount ?? this.confirmedPairCount,
    accountsWithTransactions:
        accountsWithTransactions ?? this.accountsWithTransactions,
    error: clearError ? null : (error ?? this.error),
  );
}
