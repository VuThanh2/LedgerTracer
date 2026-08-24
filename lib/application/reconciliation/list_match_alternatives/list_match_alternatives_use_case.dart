import '../../../core/result/result.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/errors/reconciliation_errors.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/services/match_predicate.dart';
import '../../../domain/value_objects/match_window.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/domain_failures.dart';
import 'list_match_alternatives_dto.dart';

/// Đường đọc của màn hình đối soát (UC-09): danh sách cặp, danh sách "Đã từ
/// chối", và các ứng viên ghép thay thế của một cặp.
///
/// Danh sách ứng viên thay thế được **tính lại lúc hiển thị** bằng chính
/// [MatchPredicate] mà lần quét dùng, không lưu sẵn thành bản ghi — lưu sẵn là
/// tạo một projection hỏng ngay khi bất kỳ cặp nào đổi trạng thái. Cùng một điều
/// kiện ghép cặp phục vụ cả lần quét theo lô lẫn màn hình này, nên một ứng viên
/// không bao giờ hiện ở chỗ này mà vắng ở chỗ kia (Rule – Suggested Is Not
/// Confirmed).
final class ListMatchAlternativesUseCase {
  ListMatchAlternativesUseCase({
    required this._reconciliation,
    required this._transactions,
    required this._accounts,
    required this._settings,
  });

  final ReconciliationRepository _reconciliation;
  final TransactionRepository _transactions;
  final BankAccountRepository _accounts;
  final AppSettingsRepository _settings;

  /// Một trang danh sách cặp, thu hẹp được theo trạng thái (UC-09 bước 1).
  Future<Result<PairsPage>> pairs({
    PairStatus? status,
    required int limit,
    required int offset,
  }) => Result.guardAsync(() async {
    final pairs = await _reconciliation.findPairs(
      status: status,
      limit: limit,
      offset: offset,
    );
    final total = await _reconciliation.countPairs(status: status);

    final transactions = await _loadTransactions(<int>[
      for (final pair in pairs) ...pair.transactionIds,
    ]);
    final names = await _accountNames();

    return PairsPage(
      items: <PairView>[
        for (final pair in pairs)
          if (_viewOf(pair, transactions, names) case final PairView view) view,
      ],
      totalCount: total,
      offset: offset,
    );
  }, onError: failureFromError);

  /// Danh sách "Đã từ chối" (UC-09 bước 5).
  Future<Result<RejectedPage>> rejected({
    required int limit,
    required int offset,
  }) => Result.guardAsync(() async {
    final rejections = await _reconciliation.findRejections(
      limit: limit,
      offset: offset,
    );
    final transactions = await _loadTransactions(<int>[
      for (final rejection in rejections)
        ...<int>[rejection.transactionAId, rejection.transactionBId],
    ]);
    return RejectedPage(
      items: <RejectedView>[
        for (final rejection in rejections)
          RejectedView(
            rejection: rejection,
            transactionA: transactions[rejection.transactionAId],
            transactionB: transactions[rejection.transactionBId],
          ),
      ],
      hasMore: rejections.length == limit,
      offset: offset,
    );
  }, onError: failureFromError);

  /// Các ứng viên ghép thay thế của một cặp, tính lại từ điều kiện ghép cặp
  /// (UC-09). Cặp đang chọn đã bị loại khỏi cả hai danh sách.
  Future<Result<MatchAlternativesView>> alternativesForPair(int pairId) =>
      Result.guardAsync(() async {
        final pair = await _reconciliation.findPairById(pairId);
        if (pair == null) throw PairNotFoundError(pairId);

        final window = (await _settings.load()).matchWindow;
        final transactions = await _loadTransactions(pair.transactionIds);
        final names = await _accountNames();
        final view = _viewOf(pair, transactions, names);
        if (view == null) throw PairNotFoundError(pairId);

        return MatchAlternativesView(
          pair: view,
          alternativesForOutgoing: await _alternativesFor(
            view.outgoing,
            exclude: view.incoming.transactionId,
            window: window,
          ),
          alternativesForIncoming: await _alternativesFor(
            view.incoming,
            exclude: view.outgoing.transactionId,
            window: window,
          ),
        );
      }, onError: failureFromError);

  Future<List<Transaction>> _alternativesFor(
    Transaction anchor, {
    required int? exclude,
    required MatchWindow window,
  }) async {
    // Cổng lưu trữ đã thu hẹp bằng các cột có chỉ mục và đã bỏ anchor, các dòng
    // đã thuộc cặp khác, và các dòng đã bị từ chối với anchor; vị từ mới có tiếng
    // nói cuối về khả năng ghép.
    final candidates = await _reconciliation.findMatchCandidates(
      anchor: anchor,
      window: window,
    );
    return <Transaction>[
      for (final candidate in MatchPredicate.alternativesFor(
        anchor,
        candidates,
        window,
      ))
        if (candidate.transactionId != exclude) candidate,
    ];
  }

  PairView? _viewOf(
    ReconciliationPair pair,
    Map<int, Transaction> transactions,
    Map<int, String> names,
  ) {
    final outgoing = transactions[pair.outgoingTransactionId];
    final incoming = transactions[pair.incomingTransactionId];
    // Bất biến bảo đảm cả hai vế còn tồn tại; nếu một vế đã biến mất thì cặp lẽ
    // ra đã bị huỷ, nên bỏ qua thay vì dựng một dòng nửa vời.
    if (outgoing == null || incoming == null) return null;
    return PairView(
      pair: pair,
      outgoing: outgoing,
      incoming: incoming,
      driftInDays: MatchPredicate.driftInDays(outgoing, incoming),
      outgoingAccountName: names[outgoing.accountId] ?? '',
      incomingAccountName: names[incoming.accountId] ?? '',
    );
  }

  Future<Map<int, Transaction>> _loadTransactions(Iterable<int> ids) async {
    final distinct = ids.toSet();
    if (distinct.isEmpty) return const <int, Transaction>{};
    final loaded = await _transactions.findByIds(distinct);
    return <int, Transaction>{
      for (final tx in loaded)
        if (tx.transactionId != null) tx.transactionId!: tx,
    };
  }

  Future<Map<int, String>> _accountNames() async {
    final accounts = await _accounts.findAll();
    return <int, String>{
      for (final account in accounts)
        if (account.accountId != null) account.accountId!: account.displayName,
    };
  }
}
