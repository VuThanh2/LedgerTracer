import 'package:flutter/widgets.dart';

import '../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../application/diagnostics/run_benchmark/run_benchmark_use_case.dart';
import '../application/export/export_dataset/export_dataset_use_case.dart';
import '../application/import/import_statements/import_statements_use_case.dart';
import '../application/import/prepare_import/prepare_import_dto.dart';
import '../application/import/prepare_import/prepare_import_use_case.dart';
import '../application/import/recover_interrupted_imports/recover_interrupted_imports_use_case.dart';
import '../application/import/revert_import/revert_import_use_case.dart';
import '../application/reconciliation/confirm_pair/confirm_pair_use_case.dart';
import '../application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import '../application/reconciliation/reject_pair/reject_pair_use_case.dart';
import '../application/reconciliation/run_reconciliation/run_reconciliation_use_case.dart';
import '../application/settings/app_lock/app_lock_use_case.dart';
import '../application/settings/backup_restore/backup_restore_use_case.dart';
import '../application/settings/reset_app/reset_app_use_case.dart';
import '../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import '../application/transactions/delete_transaction/delete_transaction_use_case.dart';
import '../application/transactions/edit_transaction/edit_transaction_use_case.dart';
import '../application/transactions/query_transactions/query_transactions_use_case.dart';
import '../core/concurrency/isolate_runner.dart';
import '../core/concurrency/platform_capabilities.dart';
import '../core/concurrency/strategy_selector.dart';
import '../infrastructure/backup/backup_codec.dart';
import '../infrastructure/database/app_database.dart';
import '../infrastructure/database/sqlite_app_data_store.dart';
import '../infrastructure/export/spreadsheet_exporter.dart';
import '../infrastructure/parsers/format_detector.dart';
import '../infrastructure/parsers/statement_parser_factory.dart';
import '../infrastructure/platform/biometric_service.dart';
import '../infrastructure/platform/file_picker_service.dart';
import '../infrastructure/platform/file_saver_service.dart';
import '../infrastructure/repositories/sqlite_app_settings_repository.dart';
import '../infrastructure/repositories/sqlite_bank_account_repository.dart';
import '../infrastructure/repositories/sqlite_import_repository.dart';
import '../infrastructure/repositories/sqlite_reconciliation_repository.dart';
import '../infrastructure/repositories/sqlite_transaction_repository.dart';
import '../infrastructure/security/pbkdf2_pin_hasher.dart';
import '../presentation/import/ports/statement_file_picker.dart';
import '../presentation/settings/ports/backup_file_picker.dart';

/// Composition root: nơi **duy nhất** biết cả bốn tầng cùng lúc.
///
/// Mọi phép nối ngược chiều phụ thuộc dồn về đây — repository SQLite gắn vào
/// interface của Domain, `FilePickerService` của Infrastructure gắn vào cổng
/// [StatementFilePicker] của Presentation. Nhờ vậy không tầng nào khác phải biết
/// tên một lớp cụ thể của tầng dưới, và đổi một hiện thực chỉ là sửa một dòng ở
/// file này.
final class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.capabilities,
    required this.queryTransactions,
    required this.editTransaction,
    required this.deleteTransaction,
    required this.manageAccounts,
    required this.prepareImport,
    required this.importStatements,
    required this.revertImport,
    required this.recoverImports,
    required this.runReconciliation,
    required this.listMatchAlternatives,
    required this.confirmPair,
    required this.rejectPair,
    required this.viewCashFlow,
    required this.exportDataset,
    required this.appLock,
    required this.resetApp,
    required this.backupRestore,
    required this.runBenchmark,
    required this.statementFilePicker,
    required this.backupFilePicker,
  });

  /// Mở cơ sở dữ liệu rồi dựng toàn bộ đồ thị phụ thuộc.
  ///
  /// Bất đồng bộ vì việc mở cơ sở dữ liệu là bất đồng bộ, và vì đó là thứ duy
  /// nhất trong đồ thị này cần chờ: mọi use case còn lại chỉ là phép gán.
  static Future<AppDependencies> bootstrap() async {
    final database = await AppDatabase.open();
    final runner = createIsolateRunner();
    final capabilities = runner.capabilities;
    final strategies = StrategySelector(capabilities);
    DateTime now() => DateTime.now();

    final accounts = SqliteBankAccountRepository(database);
    final transactions = SqliteTransactionRepository(database);
    final reconciliation = SqliteReconciliationRepository(database);
    final imports = SqliteImportRepository(database);
    final settings = SqliteAppSettingsRepository(database);
    final dataStore = SqliteAppDataStore(db: database, now: now);

    const fileSaver = PlatformFileSaverService();
    const parserFactory = DefaultStatementParserFactory();
    const filePicker = FilePickerService();

    return AppDependencies._(
      database: database,
      capabilities: capabilities,
      queryTransactions: QueryTransactionsUseCase(
        transactions: transactions,
        reconciliation: reconciliation,
        accounts: accounts,
      ),
      editTransaction: EditTransactionUseCase(
        transactions: transactions,
        reconciliation: reconciliation,
        unitOfWork: database,
      ),
      deleteTransaction: DeleteTransactionUseCase(
        transactions: transactions,
        reconciliation: reconciliation,
        unitOfWork: database,
      ),
      manageAccounts: ManageAccountsUseCase(
        accounts: accounts,
        transactions: transactions,
        reconciliation: reconciliation,
        imports: imports,
        unitOfWork: database,
        now: now,
      ),
      prepareImport: PrepareImportUseCase(
        accounts: accounts,
        detector: const ContentStatementFormatDetector(),
        parserFactory: parserFactory,
      ),
      importStatements: ImportStatementsUseCase(
        transactions: transactions,
        imports: imports,
        unitOfWork: database,
        runner: runner,
        strategies: strategies,
        parserFactory: parserFactory,
        now: now,
      ),
      revertImport: RevertImportUseCase(
        imports: imports,
        transactions: transactions,
        reconciliation: reconciliation,
        unitOfWork: database,
        now: now,
      ),
      recoverImports: RecoverInterruptedImportsUseCase(
        imports: imports,
        unitOfWork: database,
      ),
      runReconciliation: RunReconciliationUseCase(
        reconciliation: reconciliation,
        settings: settings,
        runner: runner,
        strategies: strategies,
        now: now,
      ),
      listMatchAlternatives: ListMatchAlternativesUseCase(
        reconciliation: reconciliation,
        transactions: transactions,
        accounts: accounts,
        settings: settings,
      ),
      confirmPair: ConfirmPairUseCase(reconciliation: reconciliation, now: now),
      rejectPair: RejectPairUseCase(
        reconciliation: reconciliation,
        unitOfWork: database,
        now: now,
      ),
      viewCashFlow: ViewCashFlowUseCase(
        transactions: transactions,
        accounts: accounts,
      ),
      exportDataset: ExportDatasetUseCase(
        transactions: transactions,
        reconciliation: reconciliation,
        imports: imports,
        accounts: accounts,
        exporter: const SpreadsheetExporter(),
        fileSaver: fileSaver,
        runner: runner,
        strategies: strategies,
        now: now,
      ),
      appLock: AppLockUseCase(
        settings: settings,
        hasher: const Pbkdf2PinHasher(),
        biometric: LocalAuthBiometricAuthenticator(),
      ),
      resetApp: ResetAppUseCase(store: dataStore),
      backupRestore: BackupRestoreUseCase(
        store: dataStore,
        codec: const AesGcmBackupCodec(),
        writer: fileSaver,
        now: now,
      ),
      runBenchmark: RunBenchmarkUseCase(runner: runner),
      statementFilePicker: const _PickerStatementAdapter(filePicker),
      backupFilePicker: const _PickerBackupAdapter(filePicker),
    );
  }

  final AppDatabase database;

  /// Nền tảng có isolate hay không — thứ quyết định mọi cảnh báo suy biến của
  /// UC-14 và các chiến lược đồng thời khả dụng ở màn Diagnostics.
  final PlatformCapabilities capabilities;

  final QueryTransactionsUseCase queryTransactions;
  final EditTransactionUseCase editTransaction;
  final DeleteTransactionUseCase deleteTransaction;
  final ManageAccountsUseCase manageAccounts;

  final PrepareImportUseCase prepareImport;
  final ImportStatementsUseCase importStatements;
  final RevertImportUseCase revertImport;
  final RecoverInterruptedImportsUseCase recoverImports;

  final RunReconciliationUseCase runReconciliation;
  final ListMatchAlternativesUseCase listMatchAlternatives;
  final ConfirmPairUseCase confirmPair;
  final RejectPairUseCase rejectPair;

  final ViewCashFlowUseCase viewCashFlow;
  final ExportDatasetUseCase exportDataset;

  final AppLockUseCase appLock;
  final ResetAppUseCase resetApp;
  final BackupRestoreUseCase backupRestore;

  final RunBenchmarkUseCase runBenchmark;

  final StatementFilePicker statementFilePicker;
  final BackupFilePicker backupFilePicker;

  Future<void> dispose() => database.close();
}

/// Cổng chọn file sao kê của Presentation, hiện thực bằng `file_picker`.
///
/// Adapter mỏng chứ không để BLoC gọi thẳng `FilePickerService`: cổng là thứ cho
/// phép test bloc nhập không cần một hộp thoại hệ thống, và nó cũng là chỗ duy
/// nhất phải sửa nếu về sau đổi sang cơ chế kéo–thả của trình duyệt.
final class _PickerStatementAdapter implements StatementFilePicker {
  const _PickerStatementAdapter(this._picker);

  final FilePickerService _picker;

  @override
  Future<List<PickedFile>> pickStatements() => _picker.pickStatements();
}

/// Cổng chọn file sao lưu (UC-13).
final class _PickerBackupAdapter implements BackupFilePicker {
  const _PickerBackupAdapter(this._picker);

  final FilePickerService _picker;

  @override
  Future<PickedFile?> pickBackup() => _picker.pickBackup();
}

/// Đưa [AppDependencies] xuống cây widget.
///
/// Một [InheritedWidget] thay vì một service locator toàn cục: đồ thị phụ thuộc
/// khi ấy có vòng đời gắn với cây widget, nên test dựng được một cây với đồ thị
/// giả mà không phải dọn trạng thái tĩnh giữa các bài test.
class DependencyScope extends InheritedWidget {
  const DependencyScope({
    required this.dependencies,
    required super.child,
    super.key,
  });

  final AppDependencies dependencies;

  static AppDependencies of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DependencyScope>();
    assert(scope != null, 'No DependencyScope above this widget.');
    return scope!.dependencies;
  }

  @override
  bool updateShouldNotify(DependencyScope oldWidget) =>
      oldWidget.dependencies != dependencies;
}
