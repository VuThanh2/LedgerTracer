import '../../../core/result/result.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/domain_failures.dart';
import 'query_transactions_dto.dart';

/// Đường đọc danh sách giao dịch: duyệt, tìm kiếm và lọc dùng chung một truy vấn
/// (UC-04, UC-06, UC-07).
///
/// Đọc bằng **truy vấn trực tiếp theo trang**, không nạp aggregate — đó là điều
/// kiện để một danh sách hàng trăm nghìn dòng cuộn được. Chỉ báo "đã đối soát" và
/// tên tài khoản được ghép thêm bằng hai truy vấn phụ gọn (một cho cả trang), để
/// mỗi dòng đọc hiểu được mà không phải nhét quan hệ vào trong aggregate
/// Transaction.
final class QueryTransactionsUseCase {
  QueryTransactionsUseCase({
    required this._transactions,
    required this._reconciliation,
    required this._accounts,
  });

  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final BankAccountRepository _accounts;

  Future<Result<TransactionsPage>> execute(QueryTransactionsRequest request) =>
      Result.guardAsync(() async {
        final page = await _transactions.findPage(
          filter: request.filter,
          limit: request.limit,
          offset: request.offset,
        );
        final total = await _transactions.count(request.filter);

        final ids = <int>[
          for (final tx in page)
            if (tx.transactionId != null) tx.transactionId!,
        ];
        // Chỉ báo gắn với cặp **đã xác nhận**: gợi ý chưa có hiệu lực nghiệp vụ
        // nên chưa phải "đã đối soát" (UC-09).
        final reconciled = await _reconciliation.findPairedTransactionIds(
          ids,
          status: PairStatus.confirmed,
        );
        final names = await _accountNames();

        return TransactionsPage(
          items: <TransactionListItem>[
            for (final tx in page)
              TransactionListItem(
                transaction: tx,
                accountDisplayName: names[tx.accountId] ?? '',
                isReconciled: reconciled.contains(tx.transactionId),
              ),
          ],
          totalCount: total,
          offset: request.offset,
        );
      }, onError: failureFromError);

  /// Các loại tiền đang có, nhiều giao dịch nhất trước — để bộ lọc số tiền mặc
  /// định đúng loại tiền phổ biến nhất (UC-07) và màn hình thống kê chọn tab
  /// (UC-10).
  Future<Result<List<CurrencyUsage>>> availableCurrencies() =>
      Result.guardAsync(_transactions.currencyUsage, onError: failureFromError);

  /// Nạp đầy đủ một giao dịch cho màn hình chi tiết (UC-04 bước 4).
  Future<Result<Transaction?>> findById(int transactionId) => Result.guardAsync(
    () => _transactions.findById(transactionId),
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
