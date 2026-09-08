import '../../../core/result/result.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/domain_failures.dart';
import 'view_cash_flow_dto.dart';

/// Xem thống kê dòng tiền vào/ra (UC-10).
///
/// Mọi số liệu được **tính bằng truy vấn tại thời điểm hiển thị**, không có bảng
/// tổng hợp hay cột luỹ kế nào được lưu: một con số tổng đã lưu sẽ sai ngay khi
/// bất kỳ đường nào trong sáu đường đổi dữ liệu chạy qua, và chỉ cần bỏ sót một
/// chỗ vô hiệu hoá cache là người dùng thấy số liệu sai mà không có dấu hiệu nào
/// báo (Rule – Statistics Are Always Derived, Never Stored).
///
/// Loại trừ giao dịch nội bộ đã đối soát mặc định **bật**, và trạng thái đó không
/// được ghi nhớ giữa các lần mở — thuộc về [ViewCashFlowRequest], không phải thiết
/// lập lưu trữ (UC-10).
final class ViewCashFlowUseCase {
  ViewCashFlowUseCase({
    required this._transactions,
    required this._accounts,
  });

  final TransactionRepository _transactions;
  final BankAccountRepository _accounts;

  Future<Result<CashFlowSeries>> execute(ViewCashFlowRequest request) =>
      Result.guardAsync(() async {
        switch (request.grouping) {
          case CashFlowGrouping.byPeriod:
            final buckets = await _transactions.aggregateByPeriod(
              currency: request.currency,
              period: request.period,
              dateRange: request.dateRange,
              excludeInternalTransfers: request.excludeInternalTransfers,
            );
            return CashFlowSeries(
              currency: request.currency,
              grouping: request.grouping,
              excludeInternalTransfers: request.excludeInternalTransfers,
              buckets: buckets,
            );
          case CashFlowGrouping.byAccount:
            final buckets = await _transactions.aggregateByAccount(
              currency: request.currency,
              dateRange: request.dateRange,
              excludeInternalTransfers: request.excludeInternalTransfers,
            );
            return CashFlowSeries(
              currency: request.currency,
              grouping: request.grouping,
              excludeInternalTransfers: request.excludeInternalTransfers,
              buckets: buckets,
              accountNames: await _accountNames(),
            );
        }
      }, onError: failureFromError);

  /// Các loại tiền đang có, nhiều giao dịch nhất trước — dãy tab loại tiền luôn
  /// nhìn thấy, mặc định mở ở loại tiền phổ biến nhất. Sự tồn tại của loại tiền
  /// khác phải nhìn thấy được ngay để người chủ yếu thu VND không tưởng một con
  /// số là toàn bộ dòng tiền (UC-10).
  Future<Result<List<CurrencyUsage>>> availableCurrencies() =>
      Result.guardAsync(_transactions.currencyUsage, onError: failureFromError);

  /// Có bao nhiêu tài khoản **thật sự có giao dịch** — tiền điều kiện của UC-08
  /// và là thứ quyết định Zero-effect Notice của UC-10 dẫn đi đâu.
  ///
  /// Khác với số tài khoản đã khai báo: một tài khoản vừa tạo mà chưa nhập file
  /// nào thì đối soát không có gì để ghép với nó.
  Future<Result<int>> accountsWithTransactions() => Result.guardAsync(
    _transactions.countAccountsWithTransactions,
    onError: failureFromError,
  );

  Future<Map<int, String>> _accountNames() async {
    final accounts = await _accounts.findAll();
    return <int, String>{
      for (final account in accounts)
        if (account.accountId != null) account.accountId!: account.displayName,
    };
  }
}
