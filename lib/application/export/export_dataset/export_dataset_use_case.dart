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

/// Xuất một tập dữ liệu ra file CSV hoặc Excel (UC-11).
///
/// Xuất là thao tác **chỉ đọc**: không thay đổi, không đánh dấu, không xoá gì.
/// File xuất **không mã hoá** — nó tồn tại để mở bằng công cụ khác, khác hẳn file
/// sao lưu ở UC-13. Bốn nguồn dữ liệu dùng chung một luồng và một bộ quy tắc, đặt
/// tập trung ở đây để năm màn hình nguồn tham chiếu thay vì mỗi nơi mô tả lại rồi
/// lệch nhau.
///
/// File phải phản ánh đúng trạng thái người dùng đang xem; các tiêu chí đang áp
/// dụng, **kèm loại tiền**, được ghi ở đầu file — thiếu chúng thì người nhận
/// không biết dữ liệu đã bị thu hẹp bởi điều kiện gì, và một bảng số không ghi
/// đơn vị tiền tệ sẽ bị mặc định hiểu là VND.
final class ExportDatasetUseCase {
  ExportDatasetUseCase({
    required this._transactions,
    required this._reconciliation,
    required this._imports,
    required this._accounts,
    required this._exporter,
    required this._fileSaver,
  });

  final TransactionRepository _transactions;
  final ReconciliationRepository _reconciliation;
  final ImportRepository _imports;
  final BankAccountRepository _accounts;
  final TabularExporter _exporter;
  final FileSaver _fileSaver;

  static const int _pageSize = 1000;
  static const String _notEncryptedNote = 'File này không được mã hoá.';

  Future<Result<ExportResult>> execute(ExportRequest request) =>
      Result.guardAsync(() async {
        final table = await _buildTable(request);
        final bytes = await _exporter.toBytes(table, request.format);
        final saved = await _fileSaver.save(
          bytes: bytes,
          suggestedName: _suggestedName(request),
          format: request.format,
        );
        return ExportResult(file: saved, rowCount: table.rowCount);
      }, onError: failureFromError);

  Future<ExportTable> _buildTable(ExportRequest request) => switch (request) {
    ExportTransactions() => _transactionsTable(request),
    ExportReconciliation() => _reconciliationTable(request),
    ExportStatistics() => _statisticsTable(request),
    ExportErrorRows() => _errorRowsTable(request),
  };

  Future<ExportTable> _transactionsTable(ExportTransactions request) async {
    final filter = request.filter;
    final total = await _transactions.count(filter);
    final rows = <Transaction>[];
    var offset = 0;
    while (rows.length < total) {
      final page = await _transactions.findPage(
        filter: filter,
        limit: _pageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      rows.addAll(page);
      offset += page.length;
    }

    final names = await _accountNames();
    final reconciled = await _reconciliation.findPairedTransactionIds(
      <int>[
        for (final tx in rows)
          if (tx.transactionId != null) tx.transactionId!,
      ],
      status: PairStatus.confirmed,
    );

    return ExportTable(
      metadata: <String>[..._filterMetadata(request, names), _notEncryptedNote],
      headers: const <String>[
        'Ngày ghi nhận',
        'Tài khoản',
        'Số tiền',
        'Loại tiền',
        'Người chuyển/nhận',
        'Nội dung',
        'Đã đối soát',
        'Dòng gốc',
      ],
      rows: <List<String>>[
        for (final tx in rows)
          <String>[
            _isoDate(tx.bookingDate),
            names[tx.accountId] ?? '',
            tx.amount.toDecimalString(),
            tx.amount.currency.code,
            tx.counterpartyName ?? '',
            tx.description,
            reconciled.contains(tx.transactionId) ? 'x' : '',
            tx.sourceLineNumber?.toString() ?? '',
          ],
      ],
    );
  }

  Future<ExportTable> _reconciliationTable(ExportReconciliation request) async {
    final pairs = <_PairRow>[];
    var offset = 0;
    while (true) {
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
        if (outgoing != null && incoming != null) {
          pairs.add(_PairRow(pair.status, outgoing, incoming));
        }
      }
      offset += page.length;
      if (page.length < _pageSize) break;
    }

    final names = await _accountNames();
    return ExportTable(
      metadata: <String>[
        'Trạng thái: ${request.status == null ? 'tất cả' : request.status!.name}',
        _notEncryptedNote,
      ],
      headers: const <String>[
        'Trạng thái',
        'Số tiền',
        'Loại tiền',
        'Chuyển ra - Ngày',
        'Chuyển ra - Tài khoản',
        'Nhận vào - Ngày',
        'Nhận vào - Tài khoản',
        'Lệch (ngày)',
      ],
      rows: <List<String>>[
        for (final row in pairs)
          <String>[
            row.status.name,
            row.incoming.amount.absolute.toDecimalString(),
            row.incoming.amount.currency.code,
            _isoDate(row.outgoing.bookingDate),
            names[row.outgoing.accountId] ?? '',
            _isoDate(row.incoming.bookingDate),
            names[row.incoming.accountId] ?? '',
            MatchPredicate.driftInDays(row.outgoing, row.incoming).toString(),
          ],
      ],
    );
  }

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
        'Loại tiền: ${request.currency.code}',
        'Gom nhóm theo: ${byAccount ? 'tài khoản' : request.period.name}',
        if (request.dateRange != null) 'Khoảng ngày: ${request.dateRange}',
        'Loại trừ giao dịch nội bộ đã đối soát: '
            '${request.excludeInternalTransfers ? 'có' : 'không'}',
        _notEncryptedNote,
      ],
      headers: <String>[
        byAccount ? 'Tài khoản' : 'Mốc thời gian',
        'Tiền vào',
        'Tiền ra',
        'Ròng',
        'Loại tiền',
      ],
      rows: <List<String>>[
        for (final bucket in buckets)
          <String>[
            byAccount
                ? (names[bucket.accountId] ?? '')
                : _isoDate(bucket.periodStart!),
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
      headers: const <String>['Dòng gốc', 'Lý do', 'Trích đoạn'],
      rows: <List<String>>[
        for (final row in errorRows)
          <String>[
            row.sourceLineNumber.toString(),
            row.reason,
            row.rawExcerpt,
          ],
      ],
    );
  }

  List<String> _filterMetadata(
    ExportTransactions request,
    Map<int, String> names,
  ) {
    final filter = request.filter;
    return <String>[
      if (filter.keyword != null) 'Từ khoá: ${filter.keyword}',
      if (filter.accountId != null)
        'Tài khoản: ${names[filter.accountId] ?? filter.accountId}',
      if (filter.dateRange != null) 'Khoảng ngày: ${filter.dateRange}',
      if (filter.amountRange != null) 'Khoảng số tiền: ${filter.amountRange}',
      if (filter.currency != null) 'Loại tiền: ${filter.currency!.code}',
      if (filter.isEmpty) 'Không áp dụng bộ lọc nào.',
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

  String _suggestedName(ExportRequest request) {
    final base = switch (request) {
      ExportTransactions() => 'giao-dich',
      ExportReconciliation() => 'doi-soat',
      ExportStatistics() => 'thong-ke',
      ExportErrorRows() => 'dong-loi',
    };
    final extension = request.format == ExportFormat.csv ? 'csv' : 'xlsx';
    return '$base.$extension';
  }

  String _isoDate(DateTime date) => date.toIso8601String().split('T').first;
}

/// Một cặp đã dựng đủ hai vế, chỉ dùng trong lúc dựng bảng xuất.
final class _PairRow {
  const _PairRow(this.status, this.outgoing, this.incoming);

  final PairStatus status;
  final Transaction outgoing;
  final Transaction incoming;
}
