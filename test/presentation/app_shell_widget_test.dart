import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/application/accounts/manage_accounts/manage_accounts_use_case.dart';
import 'package:ledger_tracer/application/export/export_dataset/export_dataset_use_case.dart';
import 'package:ledger_tracer/application/import/import_statements/import_statements_use_case.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_dto.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_use_case.dart';
import 'package:ledger_tracer/application/import/recover_interrupted_imports/recover_interrupted_imports_use_case.dart';
import 'package:ledger_tracer/application/import/revert_import/revert_import_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/confirm_pair/confirm_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/list_match_alternatives/list_match_alternatives_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/reject_pair/reject_pair_use_case.dart';
import 'package:ledger_tracer/application/reconciliation/run_reconciliation/run_reconciliation_use_case.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import 'package:ledger_tracer/application/transactions/delete_transaction/delete_transaction_use_case.dart';
import 'package:ledger_tracer/application/transactions/query_transactions/query_transactions_use_case.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_bloc.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_event.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_history_bloc.dart';
import 'package:ledger_tracer/presentation/import/ports/statement_file_picker.dart';
import 'package:ledger_tracer/presentation/reconciliation/bloc/reconciliation_bloc.dart';
import 'package:ledger_tracer/presentation/shared/export/bloc/export_bloc.dart';
import 'package:ledger_tracer/presentation/shared/widgets/section_card.dart';
import 'package:ledger_tracer/presentation/shell/app_shell.dart';
import 'package:ledger_tracer/presentation/shell/bloc/app_shell_bloc.dart';
import 'package:ledger_tracer/presentation/statistics/bloc/statistics_bloc.dart';
import 'package:ledger_tracer/presentation/transactions/bloc/transactions_bloc.dart';
import 'package:ledger_tracer/presentation/transactions/widgets/transaction_row_tile.dart';

import '_support/presentation_fixtures.dart';

/// Dựng khung ứng dụng thật, trên use case thật, trên cơ sở dữ liệu giả.
///
/// Bài test này không kiểm một widget lẻ mà kiểm **những thứ chỉ hỏng khi ráp**:
/// thiếu một `BlocProvider` ở phía trên, tràn layout ở một breakpoint, hoặc một
/// tab không dựng nổi. Ba lỗi đó không hiện ra ở phân tích tĩnh và cũng không
/// hiện ra ở test BLoC, vì cả hai đều không dựng cây widget.
///
/// Cùng một cây được bơm ở hai kích thước: bản hẹp có bottom nav và danh sách
/// dạng card, bản rộng có nav rail và bảng. Đó là hai hình thái mà thiết kế yêu
/// cầu, nên cả hai đều phải dựng được.
void main() {
  late FakeDatabase db;
  late Seed seed;

  DateTime now() => Seed.defaultNow;

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);

    final operating = await seed.account('Tài khoản vận hành');
    final savings = await seed.account('Tài khoản thu hộ');
    final recordA = await seed.fileRecord(accountId: operating, name: 'a.csv');
    final recordB = await seed.fileRecord(accountId: savings, name: 'b.csv');

    for (var i = 0; i < 6; i++) {
      await seed.transaction(
        accountId: operating,
        recordId: recordA,
        amount: -1000000 * (i + 1),
        bookingDate: DateTime.utc(2025, 8, 20 + i),
      );
      await seed.transaction(
        accountId: savings,
        recordId: recordB,
        amount: 1000000 * (i + 1),
        bookingDate: DateTime.utc(2025, 8, 20 + i),
      );
    }
    await seed.closeRecord(recordA);
    await seed.closeRecord(recordB);
  });

  Widget buildShell() {
    final runner = MainThreadRunner(const PlatformCapabilities.web());
    final strategies = StrategySelector(runner.capabilities);
    final manageAccounts = ManageAccountsUseCase(
      accounts: db.accounts,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      now: now,
    );
    final viewCashFlow = ViewCashFlowUseCase(
      transactions: db.transactions,
      accounts: db.accounts,
    );
    final listPairs = ListMatchAlternativesUseCase(
      reconciliation: db.reconciliation,
      transactions: db.transactions,
      accounts: db.accounts,
      settings: db.settings,
    );

    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppShellBloc>(
          create: (_) => AppShellBloc(
            recoverImports: RecoverInterruptedImportsUseCase(
              imports: db.imports,
              unitOfWork: db.unitOfWork,
            ),
            capabilities: runner.capabilities,
          ),
        ),
        BlocProvider<TransactionsBloc>(
          create: (_) => TransactionsBloc(
            queryTransactions: QueryTransactionsUseCase(
              transactions: db.transactions,
              reconciliation: db.reconciliation,
              accounts: db.accounts,
            ),
            deleteTransaction: DeleteTransactionUseCase(
              transactions: db.transactions,
              reconciliation: db.reconciliation,
              unitOfWork: db.unitOfWork,
            ),
            manageAccounts: manageAccounts,
          ),
        ),
        BlocProvider<ImportBloc>(
          create: (_) => ImportBloc(
            prepareImport: PrepareImportUseCase(
              accounts: db.accounts,
              detector: FakeFormatDetector(),
              parserFactory: FakeParserFactory(),
            ),
            importStatements: ImportStatementsUseCase(
              transactions: db.transactions,
              imports: db.imports,
              unitOfWork: db.unitOfWork,
              runner: runner,
              strategies: strategies,
              parserFactory: FakeParserFactory(),
              now: now,
            ),
            manageAccounts: manageAccounts,
            viewCashFlow: viewCashFlow,
            filePicker: const _NoFilePicker(),
            capabilities: runner.capabilities,
          )..add(const ImportStarted()),
        ),
        BlocProvider<ImportHistoryBloc>(
          create: (_) => ImportHistoryBloc(
            revertImport: RevertImportUseCase(
              imports: db.imports,
              transactions: db.transactions,
              reconciliation: db.reconciliation,
              unitOfWork: db.unitOfWork,
              now: now,
            ),
            manageAccounts: manageAccounts,
          ),
        ),
        BlocProvider<ReconciliationBloc>(
          create: (_) => ReconciliationBloc(
            runReconciliation: RunReconciliationUseCase(
              reconciliation: db.reconciliation,
              settings: db.settings,
              runner: runner,
              strategies: strategies,
              now: now,
            ),
            listPairs: listPairs,
            confirmPair: ConfirmPairUseCase(
              reconciliation: db.reconciliation,
              now: now,
            ),
            rejectPair: RejectPairUseCase(
              reconciliation: db.reconciliation,
              unitOfWork: db.unitOfWork,
              now: now,
            ),
            manageAccounts: manageAccounts,
            viewCashFlow: viewCashFlow,
            capabilities: runner.capabilities,
          ),
        ),
        BlocProvider<StatisticsBloc>(
          create: (_) =>
              StatisticsBloc(viewCashFlow: viewCashFlow, listPairs: listPairs),
        ),
        BlocProvider<ExportBloc>(
          create: (_) => ExportBloc(
            exportDataset: ExportDatasetUseCase(
              transactions: db.transactions,
              reconciliation: db.reconciliation,
              imports: db.imports,
              accounts: db.accounts,
              exporter: FakeTabularExporter(),
              fileSaver: FakeFileSaver(),
              runner: runner,
              strategies: strategies,
              now: now,
            ),
          ),
        ),
      ],
      child: MaterialApp(theme: LedgerTheme.light(), home: const AppShell()),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();
  }

  testWidgets('bản rộng dựng bảng giao dịch và nav rail có nhãn', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    // Nav rail ở breakpoint Expanded hiện đủ bốn nhãn.
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Reconcile'), findsOneWidget);

    // Header bảng chỉ tồn tại ở hình thái bảng.
    expect(find.text('COUNTERPARTY'), findsOneWidget);
    expect(find.text('Tài khoản vận hành'), findsWidgets);

    // Dòng bảng phải giữ được mật độ đã thiết kế. Cột ngày từng hẹp tới mức
    // `dd/MM/yyyy` gãy làm hai dòng, và mỗi dòng cao thêm một nửa — bảng vẫn
    // dựng được, không test nào đỏ, nhưng đúng cái mật độ mà nó tồn tại để có
    // thì mất.
    // Dòng bảng phải giữ được mật độ đã thiết kế. Cột ngày từng hẹp tới mức
    // `dd/MM/yyyy` gãy làm hai dòng, và mỗi dòng cao thêm một nửa — bảng vẫn
    // dựng được, không test nào đỏ, nhưng đúng cái mật độ mà nó tồn tại để có
    // thì mất.
    final rowHeight = tester
        .getSize(find.byType(TransactionRowTile).first)
        .height;
    expect(rowHeight, lessThanOrEqualTo(40));
  });

  testWidgets('bản hẹp dựng danh sách card và bottom nav', (tester) async {
    await pumpAt(tester, const Size(400, 800));

    // Ở Compact bảng biến thành card, nên header cột không còn.
    expect(find.text('COUNTERPARTY'), findsNothing);
    expect(find.text('Doi tac'), findsWidgets);

    // Bốn ô nav viết hoa ở thanh đáy.
    expect(find.text('TRANSACTIONS'), findsOneWidget);
    expect(find.text('STATISTICS'), findsOneWidget);
  });

  testWidgets('chuyển sang tab Thống kê dựng được biểu đồ', (tester) async {
    await pumpAt(tester, const Size(1440, 900));

    await tester.tap(find.text('Statistics').first);
    await tester.pumpAndSettle();

    expect(find.text('By period'), findsOneWidget);
    expect(find.text('By account'), findsOneWidget);
    // Dãy tab loại tiền luôn hiện, kể cả khi chỉ có một loại tiền.
    expect(find.text('VND'), findsWidgets);
  });

  testWidgets(
    'tab Thống kê ở bản rộng: hai card biểu đồ cao bằng nhau, chú thích '
    'thẳng hàng',
    (tester) async {
      await pumpAt(tester, const Size(1440, 900));

      await tester.tap(find.text('Statistics').first);
      await tester.pumpAndSettle();

      Finder card(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byType(SectionCard),
      );
      final period = tester.getRect(card('By period'));
      final account = tester.getRect(card('By account'));
      expect(account.top, period.top);
      expect(account.height, period.height);
      expect(account.width, period.width);

      // Chú thích "In" của hai biểu đồ nằm trên cùng một đường ngang.
      final legends = find.text('In');
      expect(legends, findsNWidgets(2));
      expect(
        tester.getTopLeft(legends.at(0)).dy,
        tester.getTopLeft(legends.at(1)).dy,
      );
    },
  );

  for (final size in const <Size>[Size(1440, 900), Size(800, 1600)]) {
    testWidgets(
      'tab Thống kê dựng đủ hai biểu đồ khi có kỳ không phát sinh tiền ra '
      '(${size.width.toInt()}px)',
      (tester) async {
        // Kỳ có một chiều bằng 0 từng làm `FractionallySizedBox(heightFactor:
        // 0)` trả chiều cao nội tại NaN, và `IntrinsicHeight` bọc hai card ở
        // bản rộng gãy theo — cả vùng biểu đồ biến mất. Dữ liệu ở `setUp`
        // không có kỳ nào như vậy nên không bắt được.
        await tester.runAsync(() async {
          for (var a = 0; a < 4; a++) {
            final account = await seed.account('Tài khoản phụ $a');
            final record = await seed.fileRecord(
              accountId: account,
              name: 'phu-$a.csv',
            );
            for (var month = 1; month <= 12; month++) {
              await seed.transaction(
                accountId: account,
                recordId: record,
                amount: 500000 * month,
                bookingDate: DateTime.utc(2025, month, 3),
              );
              if (month.isEven) {
                await seed.transaction(
                  accountId: account,
                  recordId: record,
                  amount: -300000 * month,
                  bookingDate: DateTime.utc(2025, month, 9),
                );
              }
            }
            await seed.closeRecord(record);
          }
        });
        await pumpAt(tester, size);

        // Medium chỉ có icon trên nav rail.
        await tester.tap(
          size.width >= 1024
              ? find.text('Statistics').first
              : find.byIcon(Icons.bar_chart).first,
        );
        await tester.pumpAndSettle();

        // Theo ngày đã bị bỏ khỏi màn hình này: chỉ còn tháng và năm.
        expect(find.text('By day'), findsNothing);

        for (final period in const <String>['By year', 'By month']) {
          await tester.tap(find.text(period));
          await tester.pumpAndSettle();
          // Mỗi biểu đồ có một chú thích "In": thấy đủ hai là cả hai đã dựng.
          expect(find.text('In'), findsNWidgets(2), reason: period);
        }
      },
    );
  }

  testWidgets('tab Thống kê ở bản hẹp: ba số tổng gọn lại thành một dòng', (
    tester,
  ) async {
    await pumpAt(tester, const Size(400, 800));

    await tester.tap(find.text('STATISTICS'));
    await tester.pumpAndSettle();

    // Ba ô tổng xếp dọc theo kiểu hai dòng chiếm gần trọn màn hình đầu tiên của
    // điện thoại, nên hai biểu đồ — thứ màn hình này thật sự phục vụ — nằm dưới
    // đường gấp. Ở bản hẹp nhãn và số về cùng một dòng, và chiều cao ô phải nói
    // lên điều đó.
    final tile = find.ancestor(
      of: find.text('MONEY IN'),
      matching: find.byType(Container),
    );
    expect(tester.getSize(tile.first).height, lessThanOrEqualTo(60));
  });

  testWidgets('bản hẹp: tab mới chỉ nạp dữ liệu sau khi chuyển cảnh xong', (
    tester,
  ) async {
    await pumpAt(tester, const Size(400, 800));

    await tester.tap(find.text('STATISTICS'));
    // Giữa chuyển cảnh: trang đã được dựng để trượt vào, nhưng chưa đọc cơ sở
    // dữ liệu — đọc rồi dựng lại cả trang lúc này là thứ làm animation khựng.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('MONEY IN'), findsNothing);

    // Chuyển cảnh xong thì dữ liệu mới được nạp.
    await tester.pumpAndSettle();
    expect(find.text('MONEY IN'), findsOneWidget);
  });

  testWidgets('tab Nhập dựng stepper và khoá nút đi tiếp khi chưa có file', (
    tester,
  ) async {
    await pumpAt(tester, const Size(400, 800));

    await tester.tap(find.text('IMPORT'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Choose statement files'), findsOneWidget);

    // Chưa có file nào đọc được, nên nút đi tiếp phải xám và lý do phải nói
    // thành lời chứ không để người dùng tự đoán.
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Assign accounts'),
    );
    expect(next.onPressed, isNull);
    expect(find.text('No readable file yet.'), findsOneWidget);
  });

  testWidgets('tab Đối soát nói rõ điều kiện thay vì khoá nút Chạy', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    await tester.tap(find.text('Reconcile').first);
    await tester.pumpAndSettle();

    // Hai tài khoản đều có giao dịch, nên màn này chạy được và hiện đủ ba nhóm.
    expect(find.textContaining('Awaiting decision'), findsOneWidget);
    expect(find.textContaining('Rejected'), findsOneWidget);
    expect(find.text('Run scan'), findsOneWidget);
  });
}

/// Không có hộp thoại chọn file trong test: bấm nút chọn file ở đây không phải
/// điều bài test này kiểm.
final class _NoFilePicker implements StatementFilePicker {
  const _NoFilePicker();

  @override
  Future<List<PickedFile>> pickStatements() async => const <PickedFile>[];
}
