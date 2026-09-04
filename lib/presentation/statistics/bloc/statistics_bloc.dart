import 'package:bloc/bloc.dart';

import '../../../application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import '../../../core/result/result.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/queries/account_activity.dart';
import '../view_models/cash_flow_view_model.dart';
import 'statistics_event.dart';
import 'statistics_state.dart';

/// Màn hình thống kê dòng tiền vào/ra (UC-10).
///
/// Mọi số liệu được **tính bằng truy vấn tại thời điểm hiển thị**; BLoC này
/// không giữ bất kỳ con số tổng nào qua các lần đọc, và đó là đi theo một luật
/// đã có ở tầng dưới chứ không phải một lựa chọn về hiệu năng: một con số tổng
/// đã lưu sẽ sai ngay khi bất kỳ đường nào thay đổi dữ liệu chạy qua, và chỉ cần
/// bỏ sót một chỗ vô hiệu hoá cache là người dùng thấy số liệu sai mà không có
/// dấu hiệu nào báo.
///
/// Hai biểu đồ được đọc **cùng lúc** trong mỗi lần làm mới. Bố cục rộng hiển thị
/// chúng cạnh nhau, nên đọc riêng từng cái theo tab nghĩa là ở bố cục đó lúc nào
/// cũng có nửa màn hình đang chờ.
final class StatisticsBloc extends Bloc<StatisticsEvent, StatisticsState> {
  StatisticsBloc({
    required ViewCashFlowUseCase viewCashFlow,
    required ListMatchAlternativesUseCase listPairs,
  }) : _cashFlow = viewCashFlow,
       _pairs = listPairs,
       super(const StatisticsState()) {
    on<StatisticsStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    // Bốn điều khiển còn lại đều **thay thế** thứ đang xem, nên lượt đọc cũ
    // không còn ai cần: bấm nhanh qua ba tab loại tiền chỉ nên tốn một lượt đọc
    // hoàn tất, không phải ba.
    on<StatisticsCurrencySelected>(
      _onCurrencySelected,
      transformer: EventTransformers.restartable(),
    );
    on<StatisticsPeriodChanged>(
      _onPeriodChanged,
      transformer: EventTransformers.restartable(),
    );
    on<StatisticsDateRangeChanged>(
      _onDateRangeChanged,
      transformer: EventTransformers.restartable(),
    );
    on<StatisticsInternalTransfersToggled>(
      _onExcludeToggled,
      transformer: EventTransformers.restartable(),
    );
  }

  final ViewCashFlowUseCase _cashFlow;
  final ListMatchAlternativesUseCase _pairs;

  Future<void> _onStarted(
    StatisticsStarted event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearError: true));

    final currencies = await _cashFlow.availableCurrencies();
    switch (currencies) {
      case Err<List<CurrencyUsage>>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            error: FailurePresenter.of(failure, context: 'statistics'),
          ),
        );
        return;
      case Ok<List<CurrencyUsage>>(:final value):
        if (value.isEmpty) {
          // Chưa có giao dịch nào: không có tab nào để mở và không có gì để vẽ.
          // Vẫn là `ready` — "chưa có dữ liệu" là một câu trả lời hoàn chỉnh.
          emit(
            state.copyWith(
              status: LoadStatus.ready,
              currencies: value,
              accountsWithTransactions: 0,
              confirmedPairCount: 0,
            ),
          );
          return;
        }
        emit(
          state.copyWith(
            currencies: value,
            // Mặc định mở ở loại tiền phổ biến nhất; giữ tab cũ nếu nó vẫn còn
            // tồn tại, để một lần làm mới không kéo người dùng về tab khác.
            currency: _keepOrDefault(value),
            // Công tắc luôn trở về mặc định **bật** mỗi lần mở màn hình.
            excludeInternalTransfers: true,
          ),
        );
    }

    await _refreshContext(emit);
    await _refreshCharts(emit);
  }

  Future<void> _onCurrencySelected(
    StatisticsCurrencySelected event,
    Emitter<StatisticsState> emit,
  ) async {
    if (event.currency == state.currency) return;
    emit(state.copyWith(currency: event.currency));
    await _refreshCharts(emit);
  }

  Future<void> _onPeriodChanged(
    StatisticsPeriodChanged event,
    Emitter<StatisticsState> emit,
  ) async {
    if (event.period == state.period) return;
    emit(state.copyWith(period: event.period));
    await _refreshCharts(emit);
  }

  Future<void> _onDateRangeChanged(
    StatisticsDateRangeChanged event,
    Emitter<StatisticsState> emit,
  ) async {
    emit(
      state.copyWith(
        dateRange: event.dateRange,
        clearDateRange: event.dateRange == null,
      ),
    );
    await _refreshCharts(emit);
  }

  Future<void> _onExcludeToggled(
    StatisticsInternalTransfersToggled event,
    Emitter<StatisticsState> emit,
  ) async {
    if (event.exclude == state.excludeInternalTransfers) return;
    emit(state.copyWith(excludeInternalTransfers: event.exclude));
    await _refreshCharts(emit);
  }

  /// Hai con số nuôi Zero-effect Notice.
  ///
  /// Đọc một lần lúc mở chứ không mỗi lần đổi công tắc: chúng không phụ thuộc
  /// vào loại tiền, khoảng ngày hay công tắc — chúng chỉ đổi khi người dùng đi
  /// sang màn hình khác và làm gì đó ở đấy.
  Future<void> _refreshContext(Emitter<StatisticsState> emit) async {
    final confirmed = await _pairs.pairs(
      status: PairStatus.confirmed,
      limit: 1,
      offset: 0,
    );
    final accounts = await AccountActivity.countAccountsWithTransactions(
      _cashFlow,
    );
    emit(
      state.copyWith(
        confirmedPairCount: confirmed.valueOrNull?.totalCount ?? 0,
        accountsWithTransactions: accounts,
      ),
    );
  }

  Future<void> _refreshCharts(Emitter<StatisticsState> emit) async {
    final currency = state.currency;
    if (currency == null) return;
    emit(state.copyWith(status: LoadStatus.loading, clearError: true));

    final byPeriod = await _cashFlow.execute(
      ViewCashFlowRequest(
        currency: currency,
        grouping: CashFlowGrouping.byPeriod,
        period: state.period,
        dateRange: state.dateRange,
        excludeInternalTransfers: state.excludeInternalTransfers,
      ),
    );
    final byAccount = await _cashFlow.execute(
      ViewCashFlowRequest(
        currency: currency,
        grouping: CashFlowGrouping.byAccount,
        dateRange: state.dateRange,
        excludeInternalTransfers: state.excludeInternalTransfers,
      ),
    );

    final failure = byPeriod.failureOrNull ?? byAccount.failureOrNull;
    if (failure != null) {
      emit(
        state.copyWith(
          status: LoadStatus.failed,
          error: FailurePresenter.of(failure, context: 'statistics'),
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: LoadStatus.ready,
        byPeriod: CashFlowChartViewModel.of(
          byPeriod.valueOrNull!,
          period: state.period,
        ),
        byAccount: CashFlowChartViewModel.of(
          byAccount.valueOrNull!,
          period: state.period,
        ),
      ),
    );
  }

  /// Giữ tab đang mở nếu loại tiền đó vẫn còn dữ liệu; nếu không thì về loại
  /// tiền phổ biến nhất.
  Currency _keepOrDefault(List<CurrencyUsage> usage) {
    final current = state.currency;
    if (current != null) {
      for (final CurrencyUsage(:currency) in usage) {
        if (currency == current) return current;
      }
    }
    return usage.first.currency;
  }
}
