import '../../../core/concurrency/execution_mode.dart';
import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/progress_report.dart';
import '../../../core/concurrency/strategy_selector.dart';
import '../../../core/concurrency/workload_scheduler.dart';
import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/import_error_row.dart';
import '../../../domain/entities/import_file_record.dart';
import '../../../domain/entities/import_session.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/import_repository.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/fingerprint.dart';
import '../../shared/domain_failures.dart';
import '../contracts/import_progress.dart';
import '../contracts/parse_batch.dart';
import '../contracts/statement_parser.dart';
import '../mappers/parsed_row_mapper.dart';
import '../workloads/parse_statement_workload.dart';
import 'import_statements_dto.dart';

/// Nhập một lượt gồm một hoặc nhiều file sao kê (UC-02).
///
/// Đây là chỗ hai giai đoạn của một lượt nhập được nối lại: **phân tích chạy song
/// song** trong các isolate (một file một isolate), còn **đối chiếu chống trùng
/// và ghi chạy tuần tự** trên luồng chính. [WorkloadScheduler] giữ đúng cặp tính
/// chất đó — sản xuất song song, tiêu thụ theo thứ tự người dùng chọn file — nên
/// mỗi lô khi tới lượt ghi luôn nhìn thấy đầy đủ những gì đã ghi trước, kể cả từ
/// file khác trong cùng lượt (Rule – Write Order Is Deterministic).
///
/// Chống trùng là phép **đếm**, không phải phép kiểm tồn tại: đã có `n` bản ghi
/// cùng fingerprint, file mang tới `m`, chỉ nhập thêm `m - n`. Hai dòng giống hệt
/// nhau trong cùng một file là hai giao dịch thật và phải được nhập đủ, nên bộ
/// đếm được chốt một lần cho mỗi fingerprint lúc gặp đầu tiên trong file rồi tự
/// theo dõi, không hỏi lại cơ sở dữ liệu — hỏi lại giữa file sẽ đếm lẫn cả những
/// dòng chính file này vừa ghi (UC-02).
///
/// Nhận diện định dạng và cảnh báo lệch số tài khoản đã xong trước khi tới đây;
/// use case này chỉ lo phân tích → chống trùng → ghi → lịch sử.
final class ImportStatementsUseCase {
  ImportStatementsUseCase({
    required this._transactions,
    required this._imports,
    required this._unitOfWork,
    required this._runner,
    required this._strategies,
    required this._parserFactory,
    required this._now,
  });

  final TransactionRepository _transactions;
  final ImportRepository _imports;
  final UnitOfWork _unitOfWork;
  final IsolateRunner _runner;
  final StrategySelector _strategies;
  final StatementParserFactory _parserFactory;
  final DateTime Function() _now;

  Future<Result<ImportSummary>> execute(
    ImportStatementsRequest request, {
    void Function(ImportProgress progress)? onProgress,
  }) => Result.guardAsync(
    () => _run(request, onProgress),
    onError: failureFromError,
  );

  Future<ImportSummary> _run(
    ImportStatementsRequest request,
    void Function(ImportProgress progress)? onProgress,
  ) async {
    final importedAt = _now();
    // Chiến lược là quyết định của tầng này, không của giao diện: nó phụ thuộc
    // vào số file và vào khả năng của nền tảng. `adapt` là chốt chặn cuối — một
    // chiến lược dùng isolate được truyền vào trên Web sẽ bị hạ về luồng chính
    // với parallelism 1, đúng chiều suy biến mà UC-14 mô tả (mất song song, các
    // file phân tích nối tiếp nhau).
    final strategy = _strategies.adapt(
      request.strategy ??
          _strategies.forStatementImport(fileCount: request.files.length),
    );
    final mode = _runner.effectiveMode(strategy);

    final session = await _imports.addSession(ImportSession.started(importedAt));
    final sessionId = session.sessionId!;

    // Mở một bản ghi cho **mọi** file — kể cả file bị bỏ qua — để lịch sử phản
    // ánh trung thực cả lượt (UC-02, UC-03). File bị bỏ qua được chốt ngay; file
    // còn lại đi vào scheduler theo đúng thứ tự chọn.
    final orderedResults = <FileImportSummary?>[];
    final workItems = <_FileWorkItem>[];
    for (var orderIndex = 0; orderIndex < request.files.length; orderIndex++) {
      final file = request.files[orderIndex];
      final record = await _imports.addFileRecord(
        ImportFileRecord.started(
          sessionId: sessionId,
          accountId: file.accountId,
          fileName: file.fileName,
          detectedFormat: file.format,
          orderIndex: orderIndex,
        ),
      );
      if (file.skip) {
        final skipped = record.skipped();
        await _imports.updateFileRecord(skipped);
        orderedResults.add(_summaryOf(skipped));
      } else {
        // Chỗ trống, điền sau khi ghi xong; giữ đúng vị trí theo thứ tự chọn.
        orderedResults.add(null);
        workItems.add(
          _FileWorkItem(
            file: file,
            record: record,
            importedAt: importedAt,
            slot: orderIndex,
          ),
        );
      }
    }

    final tally = _SessionProgress();
    final scheduler = WorkloadScheduler(_runner);
    final outcomes = await scheduler.runAll<ParseStatementInput, ParseBatch>(
      entryPoint: parseStatementWorkload,
      inputs: <ParseStatementInput>[
        for (final item in workItems)
          ParseStatementInput(
            parser: _parserFactory.parserFor(item.file.format),
            bytes: item.file.bytes,
            batchSize: strategy.batchSize,
          ),
      ],
      strategy: strategy,
      onOutput: (index, input, batch) => _writeBatch(workItems[index], batch),
      onProgress: onProgress == null
          ? null
          : (index, input, progress) {
              tally.record(index, progress);
              onProgress(_progressOf(workItems, index, progress, tally, mode));
            },
      // Chỉ kết cục mới nói được một file đã xong; báo cáo tiến trình thì không,
      // vì nhiều file chạy song song và không đi qua cổng giao hàng.
      onOutcome: onProgress == null ? null : (_) => tally.completeOne(),
      cancellation: request.cancellation,
    );

    for (final outcome in outcomes) {
      final item = workItems[outcome.index];
      final finished = await _finalizeFile(item, outcome);
      orderedResults[item.slot] = _summaryOf(finished);
    }

    final wasCancelled = request.cancellation?.isCancelled ?? false;
    await _imports.updateSession(
      wasCancelled ? session.cancel(_now()) : session.complete(_now()),
    );

    return ImportSummary(
      sessionId: sessionId,
      files: <FileImportSummary>[for (final result in orderedResults) result!],
      mode: mode,
      wasCancelled: wasCancelled,
    );
  }

  /// Đối chiếu chống trùng rồi ghi đúng một lô, trong một ranh giới transaction:
  /// một lô là một đơn vị ghi trọn vẹn, và các lô đã commit trước đó vẫn giữ
  /// nguyên nếu người dùng huỷ ở lô sau (UC-02 bước 7).
  Future<void> _writeBatch(_FileWorkItem item, ParseBatch batch) async {
    final state = item.state;
    final candidates = <Transaction>[
      for (final row in batch.rows)
        ParsedRowMapper.toTransaction(
          row,
          accountId: item.file.accountId,
          importFileRecordId: item.record.recordId!,
          importedAt: item.importedAt,
        ),
    ];

    // Chốt số bản ghi đã có cho những fingerprint lần đầu gặp trong file này. Chỉ
    // hỏi cơ sở dữ liệu một lần cho mỗi fingerprint — lúc chưa có dòng nào của
    // chính file này mang nó được ghi — rồi tự đếm bằng [state].
    final unknown = <Fingerprint>{
      for (final tx in candidates)
        if (!state.existing.containsKey(tx.fingerprint)) tx.fingerprint,
    };
    if (unknown.isNotEmpty) {
      final counts = await _transactions.countByFingerprint(
        accountId: item.file.accountId,
        fingerprints: unknown,
      );
      for (final fingerprint in unknown) {
        state.existing[fingerprint] = counts[fingerprint] ?? 0;
      }
    }

    final toInsert = <Transaction>[];
    for (final tx in candidates) {
      final fingerprint = tx.fingerprint;
      final consumed = state.consumed[fingerprint] ?? 0;
      final existing = state.existing[fingerprint] ?? 0;
      state.consumed[fingerprint] = consumed + 1;
      if (consumed < existing) {
        // Khớp một bản ghi đã có (lượt trước, hoặc file trước trong lượt này).
        state.duplicateSkippedCount++;
      } else {
        toInsert.add(tx);
      }
    }

    final errorRows = <ImportErrorRow>[
      for (final error in batch.errors)
        ParsedRowMapper.toErrorRow(
          error,
          importFileRecordId: item.record.recordId!,
        ),
    ];

    if (toInsert.isNotEmpty || errorRows.isNotEmpty) {
      await _unitOfWork.transaction(() async {
        if (toInsert.isNotEmpty) await _transactions.addAll(toInsert);
        if (errorRows.isNotEmpty) await _imports.addErrorRows(errorRows);
      });
    }
    state.importedCount += toInsert.length;
    state.errorRowCount += errorRows.length;
  }

  Future<ImportFileRecord> _finalizeFile(
    _FileWorkItem item,
    WorkloadOutcome<ParseStatementInput> outcome,
  ) async {
    // File hỏng tới mức không tách được dòng nào (ParsingFailure) đi về như một
    // workload thất bại; ghi lại thành một dòng lỗi để nó vẫn hiện trong lịch sử
    // và không kéo cả lượt chết theo (UC-02).
    if (outcome.status == WorkloadStatus.failed) {
      await _imports.addErrorRows(<ImportErrorRow>[
        ImportErrorRow.from(
          recordId: item.record.recordId!,
          sourceLineNumber: 0,
          rawLine: item.file.fileName,
          reason: 'Không đọc được file: ${outcome.error}',
        ),
      ]);
      item.state.errorRowCount++;
    }

    final wasCancelled =
        outcome.status == WorkloadStatus.cancelled ||
        outcome.status == WorkloadStatus.skipped;

    final finished = item.record.finished(
      importedCount: item.state.importedCount,
      duplicateSkippedCount: item.state.duplicateSkippedCount,
      errorRowCount: item.state.errorRowCount,
      wasCancelled: wasCancelled,
    );
    await _imports.updateFileRecord(finished);
    return finished;
  }

  ImportProgress _progressOf(
    List<_FileWorkItem> items,
    int index,
    ProgressReport progress,
    _SessionProgress tally,
    ExecutionMode mode,
  ) => ImportProgress(
    fileCount: items.length,
    completedFiles: tally.completedFiles,
    reportingFileIndex: index,
    reportingFileName: items[index].file.fileName,
    processedInFile: progress.processed,
    totalInFile: progress.total,
    processedTotal: tally.processedTotal,
    mode: mode,
  );

  FileImportSummary _summaryOf(ImportFileRecord record) => FileImportSummary(
    recordId: record.recordId!,
    fileName: record.fileName,
    accountId: record.accountId,
    status: record.status,
    importedCount: record.importedCount,
    duplicateSkippedCount: record.duplicateSkippedCount,
    errorRowCount: record.errorRowCount,
  );
}

/// Cộng dồn tiến trình của cả lượt.
///
/// Cần thiết vì báo cáo tiến trình **không** đi qua cổng giao hàng của
/// [WorkloadScheduler]: trên native nhiều isolate cùng báo về, xen kẽ nhau và
/// không theo thứ tự file. Cộng dồn ngây thơ các con số ấy sẽ đếm trùng, nên mỗi
/// file được nhớ **con số mới nhất của riêng nó** rồi cộng lại.
final class _SessionProgress {
  final Map<int, int> _processedByFile = <int, int>{};

  int _completedFiles = 0;

  int get completedFiles => _completedFiles;

  int get processedTotal =>
      _processedByFile.values.fold(0, (total, rows) => total + rows);

  void record(int index, ProgressReport progress) =>
      _processedByFile[index] = progress.processed;

  void completeOne() => _completedFiles++;
}

/// Trạng thái ghi của một file trong lượt: bộ đếm kết quả và sổ chống trùng.
final class _FileWriteState {
  int importedCount = 0;
  int duplicateSkippedCount = 0;
  int errorRowCount = 0;

  /// Số bản ghi đã có cho mỗi fingerprint, chốt lúc gặp đầu tiên trong file.
  final Map<Fingerprint, int> existing = <Fingerprint, int>{};

  /// Số lần fingerprint đã xuất hiện trong file cho tới giờ.
  final Map<Fingerprint, int> consumed = <Fingerprint, int>{};
}

final class _FileWorkItem {
  _FileWorkItem({
    required this.file,
    required this.record,
    required this.importedAt,
    required this.slot,
  });

  final ImportFileInput file;
  final ImportFileRecord record;
  final DateTime importedAt;

  /// Vị trí trong danh sách kết quả theo thứ tự người dùng chọn file.
  final int slot;

  final _FileWriteState state = _FileWriteState();
}
