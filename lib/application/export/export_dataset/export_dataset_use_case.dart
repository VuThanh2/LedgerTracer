import '../../../core/concurrency/cancellation_signal.dart';
import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/strategy_selector.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/errors/import_errors.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../../domain/repositories/import_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/services/match_predicate.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/domain_failures.dart';
import '../../statistics/view_cash_flow/view_cash_flow_dto.dart';
import 'export_dataset_dto.dart';

/// Xuất một tập con dữ liệu ra file CSV hoặc Excel (UC-11).
///
/// Bốn nguồn xuất được gom về đây thay vì rải ở từng màn hình: chúng dùng chung
/// một luồng và một bộ quy tắc, và mô tả lặp ở năm chỗ là năm bản sẽ lệch nhau.
///
/// **Không chặn giao diện** là yêu cầu của UC-11 chứ không phải tuỳ chọn — một
/// danh sách giao dịch xuất được có thể dài hàng trăm nghìn dòng. Luồng chạy
/// theo ba giai đoạn có tính chất khác hẳn nhau:
///
/// - **Gom dữ liệu** buộc phải ở luồng chính (SQLite chỉ đọc được từ đó), nên nó
///   chạy theo trang và **nhường lượt cho event loop giữa các trang** — cùng cơ
///   chế ranh giới lô mà UC-02 và UC-08 dùng, và cũng vì thế nút Huỷ phản hồi
///   trong vòng một trang chứ không tức thì. Bảng được dựng thẳng thành chuỗi
///   ngay trong vòng lặp: giữ lại cả tập Entity để đọc lần nữa ở cuối là trả giá
///   bộ nhớ hai lần cho cùng một dữ liệu.
/// - **Mã hoá thành bytes** là CPU thuần trên dữ liệu đã nạp xong, không đụng cơ
///   sở dữ liệu — đúng hình dạng cho một isolate chạy một lần.
/// - **Lưu file** là I/O của nền tảng.
///
/// Huỷ giữa chừng không cần dọn dẹp gì: xuất là thao tác **chỉ đọc**, không thay
/// đổi, không đánh dấu, không xoá bất kỳ dữ liệu nào trong ứng dụng (UC-11).
final class ExportDatasetUseCase {
  ExportDatasetUseCase({
    required this._transactions,
    required this._reconciliation,
    required this._imports,
    required this._accounts,
    required this._exporter,
    required this._fileSaver,
    required this._runner,
    required this._strategies,
    required this._now,
  });

  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final ImportRepository _imports;
  final BankAccountRepository _accounts;
  final TabularExporter _exporter;
  final FileSaver _fileSaver;
  final IsolateRunner _runner;
  final StrategySelector _strategies;
  final DateTime Function() _now;

  static const int _pageSize = 1000;
  static const String _notEncryptedNote = 'This file is not encrypted.';

  Future<Result<ExportResult>> execute(
    ExportDatasetRequest request, {
    void Function(ExportProgress progress)? onProgress,
  }) => Result.guardAsync(() async {
    final cancellation = request.cancellation;
    onProgress?.call(const ExportProgress(stage: ExportStage.collecting));

    final table = await _buildTable(request.dataset, cancellation, onProgress);
    cancellation?.throwIfCancelled();

    onProgress?.call(const ExportProgress(stage: ExportStage.encoding));
    final strategy = _strategies.adapt(
      request.strategy ?? _strategies.forFileEncoding(),
    );
    final bytes = await _runner.runOnce(
      task: encodeExportTable,
      input: EncodeTableInput(
        exporter: _exporter,
        table: table,
        format: request.dataset.format,
      ),
      strategy: strategy,
    );

    onProgress?.call(const ExportProgress(stage: ExportStage.saving));
    final saved = await _fileSaver.save(
      bytes: bytes,
      suggestedName: _suggestedName(request.dataset),
      format: request.dataset.format,
    );
    return ExportResult(file: saved, rowCount: table.rowCount);
  }, onError: failureFromError);

  Future<ExportTable> _buildTable(
    ExportRequest request,
    CancellationSignal? cancellation,
    void Function(ExportProgress progress)? onProgress,
  ) => switch (request) {
    ExportTransactions() => _transactionsTable(
      request,
      cancellation,
      onProgress,
    ),
    ExportReconciliation() => _reconciliationTable(
      request,
      cancellation,
      onProgress,
    ),
    ExportStatistics() => _statisticsTable(request),
    ExportErrorRows() => _errorRowsTable(request),
  };

  Future<ExportTable> _transactionsTable(
    ExportTransactions request,
    CancellationSignal? cancellation,
    void Function(ExportProgress progress)? onProgress,
  ) async {
    final filter = request.filter;
    final total = await _transactions.count(filter);
    final names = await _accountNames();

    final rows = <List<String>>[];
    var offset = 0;
    while (true) {
      cancellation?.throwIfCancelled();
      final page = await _transactions.findPage(
        filter: filter,
        limit: _pageSize,
        offset: offset,
      );
      if (page.isEmpty) break;

      // Chỉ báo "đã đối soát" được hỏi theo **từng trang**: hỏi một lần cho cả
      // tập nghĩa là nhét hàng trăm nghìn định danh vào một mệnh đề `IN`, thứ
      // SQLite không nhận và bộ nhớ không nên phải chịu.
      final reconciled = await _reconciliation.findPairedTransactionIds(
        <int>[
          for (final tx in page)
            if (tx.transactionId != null) tx.transactionId!,
        ],
        status: PairStatus.confirmed,
      );
      for (final tx in page) {
        rows.add(_transactionRow(tx, names, reconciled));
      }

      offset += page.length;
      onProgress?.call(
        ExportProgress(
          stage: ExportStage.collecting,
          processed: rows.length,
          total: total,
        ),
      );
      if (page.length < _pageSize) break;
      await yieldToEventLoop();
    }

    return ExportTable(
      metadata: <String>[..._filterMetadata(request, names), _notEncryptedNote],
      headers: const <String>[
        'Booking date',
        'Account',
        'Amount',
        'Currency',
        'Counterparty',
        'Memo',
        'Reconciled',
        'Source row',
      ],
      rows: rows,
    );
  }

  List<String> _transactionRow(
    Transaction tx,
    Map<int, String> names,
    Set<int> reconciled,
  ) => <String>[
    _isoDate(tx.bookingDate),
    names[tx.accountId] ?? '',
    tx.amount.toDecimalString(),
    // Mọi số tiền đều đi kèm loại tiền: một cột "1.000" trống trơn trong bảng
    // gộp nhiều loại tiền sẽ bị mặc định hiểu là VND (UC-04).
    tx.amount.currency.code,
    tx.counterpartyName ?? '',
    tx.description,
    reconciled.contains(tx.transactionId) ? 'x' : '',
    tx.sourceLineNumber?.toString() ?? '',
  ];

  Future<ExportTable> _reconciliationTable(
    ExportReconciliation request,
    CancellationSignal? cancellation,
    void Function(ExportProgress progress)? onProgress,
  ) async {
    final total = await _reconciliation.countPairs(status: request.status);
    final names = await _accountNames();

    final rows = <List<String>>[];
    var offset = 0;
    while (true) {
      cancellation?.throwIfCancelled();
      final page = await _reconciliation.findPairs(
        status: request.status,
        limit: _pageSize,
        offset: offset,
      );
      if (page.isEmpty) break;

      final transactions = await _loadTransactions(<int>[
        for (final pair in page) ...pair.transactionIds,
      ]);
      for (final pair in page) {
        final outgoing = transactions[pair.outgoingTransactionId];
        final incoming = transactions[pair.incomingTransactionId];
        // Một cặp chỉ tồn tại khi cả hai vế còn tồn tại; thiếu một vế nghĩa là
        // cặp đang trên đường bị huỷ và không thuộc về báo cáo (UC-09).
        if (outgoing == null || incoming == null) continue;
        rows.add(<String>[
          pair.status.name,
          incoming.amount.absolute.toDecimalString(),
          incoming.amount.currency.code,
          _isoDate(outgoing.bookingDate),
          names[outgoing.accountId] ?? '',
          _isoDate(incoming.bookingDate),
          names[incoming.accountId] ?? '',
          MatchPredicate.driftInDays(outgoing, incoming).toString(),
        ]);
      }

      offset += page.length;
      onProgress?.call(
        ExportProgress(
          stage: ExportStage.collecting,
          processed: rows.length,
          total: total,
        ),
      );
      if (page.length < _pageSize) break;
      await yieldToEventLoop();
    }

    return ExportTable(
      metadata: <String>[
        'Status: ${request.status == null ? 'all' : request.status!.name}',
        _notEncryptedNote,
      ],
      headers: const <String>[
        'Status',
        'Amount',
        'Currency',
        'Money out - date',
        'Money out - account',
        'Money in - date',
        'Money in - account',
        'Gap (days)',
      ],
      rows: rows,
    );
  }

  /// Thống kê đã là số liệu gom nhóm — nó nhỏ theo bản chất (mỗi mốc thời gian
  /// hoặc mỗi tài khoản một dòng), nên không có gì để phân trang hay để huỷ.
  Future<ExportTable> _statisticsTable(ExportStatistics request) async {
    final byAccount = request.grouping == CashFlowGrouping.byAccount;
    final buckets = byAccount
        ? await _transactions.aggregateByAccount(
            currency: request.currency,
            dateRange: request.dateRange,
            excludeInternalTransfers: request.excludeInternalTransfers,
          )
        : await _transactions.aggregateByPeriod(
            currency: request.currency,
            period: request.period,
            dateRange: request.dateRange,
            excludeInternalTransfers: request.excludeInternalTransfers,
          );
    final names = byAccount ? await _accountNames() : const <int, String>{};

    return ExportTable(
      metadata: <String>[
        'Currency: ${request.currency.code}',
        'Grouped by: ${byAccount ? 'account' : request.period.name}',
        if (request.dateRange != null) 'Date range: ${request.dateRange}',
        'Excluding confirmed internal transfers: '
            '${request.excludeInternalTransfers ? 'yes' : 'no'}',
        _notEncryptedNote,
      ],
      headers: <String>[
        byAccount ? 'Account' : 'Period',
        'Money in',
        'Money out',
        'Net',
        'Currency',
      ],
      rows: <List<String>>[
        for (final bucket in buckets)
          <String>[
            // Kiểu tổng đóng nên nhãn của cột lấy được mà không cần `!` nào: một
            // cột hoặc thuộc một mốc thời gian, hoặc thuộc một tài khoản.
            switch (bucket) {
              PeriodCashFlow(:final periodStart) => _isoDate(periodStart),
              AccountCashFlow(:final accountId) => names[accountId] ?? '',
            },
            bucket.inflow.toDecimalString(),
            bucket.outflow.toDecimalString(),
            bucket.net.toDecimalString(),
            request.currency.code,
          ],
      ],
    );
  }

  Future<ExportTable> _errorRowsTable(ExportErrorRows request) async {
    final record = await _imports.findFileRecordById(request.importFileRecordId);
    if (record == null) {
      throw ImportFileRecordNotFoundError(request.importFileRecordId);
    }
    final errorRows = await _imports.findErrorRows(request.importFileRecordId);
    return ExportTable(
      metadata: <String>['File: ${record.fileName}', _notEncryptedNote],
      // Số thứ tự dòng gốc và lý do là hai cột làm cho luồng "sửa trên file gốc
      // rồi nhập lại" khả thi (UC-11).
      headers: const <String>['Source row', 'Reason', 'Excerpt'],
      rows: <List<String>>[
        for (final row in errorRows)
          <String>[row.sourceLineNumber.toString(), row.reason, row.rawExcerpt],
      ],
    );
  }

  List<String> _filterMetadata(
    ExportTransactions request,
    Map<int, String> names,
  ) {
    final filter = request.filter;
    return <String>[
      if (filter.keyword != null) 'Keyword: ${filter.keyword}',
      if (filter.accountId != null)
        'Account: ${names[filter.accountId] ?? filter.accountId}',
      if (filter.dateRange != null) 'Date range: ${filter.dateRange}',
      if (filter.amountRange != null) 'Amount range: ${filter.amountRange}',
      if (filter.currency != null) 'Currency: ${filter.currency!.code}',
      if (filter.isEmpty) 'No filter applied.',
    ];
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

  /// Tên gợi ý kèm mốc thời gian: xuất hai lần cùng một loại báo cáo là việc
  /// bình thường, và tên trùng nhau nghĩa là lần sau ghi đè lần trước.
  String _suggestedName(ExportRequest request) {
    final base = switch (request) {
      ExportTransactions() => 'giao-dich',
      ExportReconciliation() => 'doi-soat',
      ExportStatistics() => 'thong-ke',
      ExportErrorRows() => 'dong-loi',
    };
    final extension = request.format == ExportFormat.csv ? 'csv' : 'xlsx';
    return '$base-${_timestamp()}.$extension';
  }

  String _timestamp() =>
      _now().toIso8601String().split('.').first.replaceAll(':', '-');

  String _isoDate(DateTime date) => date.toIso8601String().split('T').first;
}
