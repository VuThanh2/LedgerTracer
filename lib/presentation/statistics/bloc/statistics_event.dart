import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';

/// Những gì xảy ra trên màn hình thống kê dòng tiền (UC-10).
sealed class StatisticsEvent {
  const StatisticsEvent();
}

/// Mở màn hình.
///
/// Công tắc loại trừ giao dịch nội bộ **luôn** bật lại ở đây và không bao giờ
/// được ghi nhớ giữa các lần mở: nó thuộc về một lần xem, không phải một thiết
/// lập. Nhớ nó nghĩa là người dùng mở màn hình ra và thấy một con số đã bị thu
/// hẹp bởi một lựa chọn họ đã quên là mình từng bấm (UC-10).
final class StatisticsStarted extends StatisticsEvent {
  const StatisticsStarted();
}

/// Đổi tab loại tiền. Các loại tiền không bao giờ cộng gộp và không quy đổi.
final class StatisticsCurrencySelected extends StatisticsEvent {
  const StatisticsCurrencySelected(this.currency);

  final Currency currency;
}

/// Đổi độ mịn thời gian của biểu đồ theo thời gian (mặc định theo tháng).
final class StatisticsPeriodChanged extends StatisticsEvent {
  const StatisticsPeriodChanged(this.period);

  final CashFlowPeriod period;
}

/// Thu hẹp theo khoảng ngày; `null` để bỏ.
final class StatisticsDateRangeChanged extends StatisticsEvent {
  const StatisticsDateRangeChanged(this.dateRange);

  final DateRange? dateRange;
}

/// Bật/tắt công tắc loại trừ giao dịch nội bộ đã đối soát. Biểu đồ cập nhật
/// ngay (UC-10).
final class StatisticsInternalTransfersToggled extends StatisticsEvent {
  const StatisticsInternalTransfersToggled(this.exclude);

  final bool exclude;
}
