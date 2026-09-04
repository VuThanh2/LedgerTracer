import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/accounts/manage_accounts/manage_accounts_use_case.dart';
import 'package:ledger_tracer/application/import/import_statements/import_statements_use_case.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_dto.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_use_case.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_bloc.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_event.dart';
import 'package:ledger_tracer/presentation/import/bloc/import_state.dart';
import 'package:ledger_tracer/presentation/import/ports/statement_file_picker.dart';
import 'package:ledger_tracer/presentation/import/view_models/import_file_entry.dart';

import '_support/presentation_fixtures.dart';

/// Bộ chọn file giả: trả về đúng những gì test đã đặt sẵn.
///
/// Cổng này được khai báo ở tầng Presentation chính là để có chỗ cắm bản giả
/// vào — một BLoC gọi thẳng `FilePickerService` sẽ không test được nếu không có
/// hộp thoại thật của nền tảng.
final class FakeFilePicker implements StatementFilePicker {
  FakeFilePicker(this.files);

  List<PickedFile> files;

  int callCount = 0;

  @override
  Future<List<PickedFile>> pickStatements() async {
    callCount++;
    return files;
  }
}

void main() {
  late FakeDatabase db;
  late Seed seed;
  late FakeFilePicker picker;
  late ImportBloc bloc;

  late int accountA;
  late int accountB;

  const capabilities = PlatformCapabilities.web();
  final now = Seed.defaultNow;

  ImportBloc build() => ImportBloc(
    prepareImport: PrepareImportUseCase(
      accounts: db.accounts,
      detector: const FakeFormatDetector(),
      parserFactory: FakeParserFactory(),
    ),
    importStatements: ImportStatementsUseCase(
      transactions: db.transactions,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      runner: const MainThreadRunner(capabilities),
      strategies: const StrategySelector(capabilities),
      parserFactory: FakeParserFactory(),
      now: () => now,
    ),
    manageAccounts: ManageAccountsUseCase(
      accounts: db.accounts,
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      now: () => now,
    ),
    viewCashFlow: ViewCashFlowUseCase(
      transactions: db.transactions,
      accounts: db.accounts,
    ),
    filePicker: picker,
    capabilities: capabilities,
  );

  PickedFile pick(String name, {String? accountNumber, int rows = 2}) =>
      PickedFile(
        fileName: name,
        bytes: FakeStatementParser.file(<String>[
          if (accountNumber != null)
            '${FakeStatementParser.accountNumberPrefix}$accountNumber',
          for (var i = 0; i < rows; i++)
            FakeStatementParser.line(date: '2025-03-1$i', amount: -1000),
        ]),
      );

  Future<ImportState> waitFor(bool Function(ImportState state) match) =>
      bloc.stream.firstWhere(match);

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    picker = FakeFilePicker(const <PickedFile>[]);
    accountA = await seed.account('Vietinbank vận hành');
    accountB = await seed.account('Ví thu hộ');
  });

  tearDown(() => bloc.close());

  group('bước 1 — chọn file', () {
    test('file lạ về như dữ liệu, không kéo theo file còn lại', () async {
      picker.files = <PickedFile>[pick('sao-ke.csv'), pick('anh.png')];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      final state = await waitFor((state) => state.files.length == 2);

      expect(state.recognizedFiles, hasLength(1));
      expect(state.unrecognizedFiles, hasLength(1));
      expect(state.unrecognizedFiles.single.unrecognizedReason, isNotEmpty);
      // Vẫn đi tiếp được: một file lạ không chặn cả lượt.
      expect(state.canAssignAccounts, isTrue);
    });

    test('chọn thêm thì cộng dồn, không thay thế', () async {
      picker.files = <PickedFile>[pick('thang-01.csv')];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.length == 1);

      picker.files = <PickedFile>[pick('thang-02.csv')];
      bloc.add(const ImportFilesPickRequested());
      final state = await waitFor((state) => state.files.length == 2);

      expect(
        state.files.map((file) => file.fileName),
        <String>['thang-01.csv', 'thang-02.csv'],
      );
    });

    test('chọn lại đúng file đã có thì không nhân đôi', () async {
      picker.files = <PickedFile>[pick('thang-01.csv')];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.length == 1);

      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => picker.callCount == 2 && !state.isPicking);
      expect(bloc.state.files, hasLength(1));
    });

    test('đóng hộp thoại mà không chọn gì thì không có gì xảy ra', () async {
      picker.files = const <PickedFile>[];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => picker.callCount == 1 && !state.isPicking);

      expect(bloc.state.files, isEmpty);
      expect(bloc.state.error, isNull);
    });
  });

  group('bước 2 — gán tài khoản', () {
    Future<void> pickOne(String name, {String? accountNumber}) async {
      picker.files = <PickedFile>[pick(name, accountNumber: accountNumber)];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.isNotEmpty);
    }

    test('chưa gán tài khoản thì chặn không cho chạy', () async {
      await pickOne('sao-ke.csv');
      expect(bloc.state.canRun, isFalse);
      expect(bloc.state.unassignedCount, 1);

      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.csv', accountId: accountA),
      );
      final state = await waitFor((state) => state.canRun);
      expect(state.unassignedCount, 0);
    });

    test(
      'số tài khoản lệch phải được trả lời trước khi đi tiếp',
      () async {
        // Tài khoản đích đã ghi nhận một số khác với số nhúng trong file.
        await db.accounts.update(
          db.accountRows[accountA]!.withAccountNumber('111222333'),
        );
        await pickOne('sao-ke.sta', accountNumber: '999888777');

        bloc.add(
          ImportFileAccountAssigned(
            fileName: 'sao-ke.sta',
            accountId: accountA,
          ),
        );
        var state = await waitFor((state) => state.files.first.check != null);

        expect(state.files.first.hasUnresolvedMismatch, isTrue);
        // Cảnh báo **chặn cứng** bước 3: đi tiếp khi nó còn treo là nhập sao kê
        // của tài khoản này vào tài khoản khác mà không ai biết.
        expect(state.canRun, isFalse);
        expect(state.unresolvedMismatchCount, 1);

        bloc.add(
          const ImportMismatchResolved(
            fileName: 'sao-ke.sta',
            decision: MismatchDecision.importAnyway,
          ),
        );
        state = await waitFor((state) => state.canRun);
        expect(state.files.first.isSkipped, isFalse);
      },
    );

    test('gán lại tài khoản khác thì quyết định cũ bị xoá', () async {
      await db.accounts.update(
        db.accountRows[accountA]!.withAccountNumber('111222333'),
      );
      await pickOne('sao-ke.sta', accountNumber: '999888777');

      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.sta', accountId: accountA),
      );
      await waitFor((state) => state.files.first.hasUnresolvedMismatch);
      bloc.add(
        const ImportMismatchResolved(
          fileName: 'sao-ke.sta',
          decision: MismatchDecision.skipFile,
        ),
      );
      await waitFor((state) => state.files.first.isSkipped);

      // Tài khoản B chưa có số nào, nên phán quyết đổi hẳn sang "sẽ học".
      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.sta', accountId: accountB),
      );
      final state = await waitFor(
        (state) => state.files.first.accountId == accountB,
      );
      expect(state.files.first.decision, isNull);
      expect(state.files.first.willLearnAccountNumber, isTrue);
    });

    test('tạo tài khoản ngay tại chỗ rồi gán luôn cho file', () async {
      await pickOne('sao-ke.csv');

      bloc.add(
        const ImportAccountCreated(
          displayName: 'Techcombank lương',
          assignToFileName: 'sao-ke.csv',
        ),
      );
      final state = await waitFor((state) => state.canRun);

      expect(state.accounts.map((account) => account.displayName),
          contains('Techcombank lương'));
      expect(state.files.first.accountId, isNotNull);
    });
  });

  group('bước 3–4 — chạy và tổng kết', () {
    test('nhập xong thì ghi giao dịch và dựng bảng tổng kết', () async {
      picker.files = <PickedFile>[pick('sao-ke.csv', rows: 3)];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.isNotEmpty);

      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.csv', accountId: accountA),
      );
      await waitFor((state) => state.canRun);

      bloc.add(const ImportRunRequested());
      final state = await waitFor(
        (state) => state.step == ImportStep.summary,
      );

      expect(state.summary!.files, hasLength(1));
      expect(state.summary!.importedText, '3');
      expect(state.summary!.wasCancelled, isFalse);
      // Web không có isolate; bảng tổng kết phải nói đúng điều đã xảy ra.
      expect(state.summary!.ranInBackground, isFalse);
      expect(db.transactionRows, hasLength(3));
    });

    test('số tài khoản học được từ file được ghi nhận trước khi nhập', () async {
      picker.files = <PickedFile>[
        pick('sao-ke.sta', accountNumber: '0011 2233 4455'),
      ];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.isNotEmpty);

      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.sta', accountId: accountA),
      );
      await waitFor((state) => state.files.first.willLearnAccountNumber);
      expect(db.accountRows[accountA]!.hasAccountNumber, isFalse);

      bloc.add(const ImportRunRequested());
      await waitFor((state) => state.step == ImportStep.summary);

      // Số được chuẩn hoá khi ghi nhận, để lần đối chiếu sau là so hai chuỗi
      // cùng dạng.
      expect(db.accountRows[accountA]!.accountNumber, '001122334455');
    });

    test('file bị bỏ qua vẫn có mặt trong lịch sử với trạng thái riêng', () async {
      await db.accounts.update(
        db.accountRows[accountA]!.withAccountNumber('111222333'),
      );
      picker.files = <PickedFile>[
        pick('sao-ke.sta', accountNumber: '999888777'),
      ];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.isNotEmpty);

      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.sta', accountId: accountA),
      );
      await waitFor((state) => state.files.first.hasUnresolvedMismatch);
      bloc.add(
        const ImportMismatchResolved(
          fileName: 'sao-ke.sta',
          decision: MismatchDecision.skipFile,
        ),
      );
      await waitFor((state) => state.canRun);

      bloc.add(const ImportRunRequested());
      final state = await waitFor(
        (state) => state.step == ImportStep.summary,
      );

      expect(state.summary!.files.single.statusLabel, 'Đã bỏ qua');
      expect(db.transactionRows, isEmpty);
      // Bỏ qua là một **quyết định**, không phải lỗi đọc file: lượt nhập vẫn ghi
      // nhận nó để lịch sử phản ánh trung thực cả lượt.
      expect(db.fileRecordRows, hasLength(1));
      // Số tài khoản đã ghi nhận **không** bị ghi đè bởi lựa chọn ở bước 4.
      expect(db.accountRows[accountA]!.accountNumber, '111222333');
    });

    test(
      'nút "Chạy đối soát" chỉ hiện khi đã đủ hai tài khoản có giao dịch',
      () async {
        // Lượt đầu: mới một tài khoản có giao dịch, chưa có gì để ghép.
        picker.files = <PickedFile>[pick('a.csv')];
        bloc = build();
        bloc.add(const ImportStarted());
        bloc.add(const ImportFilesPickRequested());
        await waitFor((state) => state.files.isNotEmpty);
        bloc.add(
          ImportFileAccountAssigned(fileName: 'a.csv', accountId: accountA),
        );
        await waitFor((state) => state.canRun);
        bloc.add(const ImportRunRequested());
        var state = await waitFor((s) => s.step == ImportStep.summary);
        expect(state.accountsWithTransactions, 1);
        expect(state.canGoToReconciliation, isFalse);

        // Lượt hai vào tài khoản khác: chính lượt vừa rồi là lượt làm cho điều
        // kiện thành đúng, nên con số phải được đọc **sau** khi ghi xong.
        bloc.add(const ImportReset());
        await waitFor((s) => s.step == ImportStep.pickFiles);
        picker.files = <PickedFile>[pick('b.csv')];
        bloc.add(const ImportFilesPickRequested());
        await waitFor((s) => s.files.isNotEmpty);
        bloc.add(
          ImportFileAccountAssigned(fileName: 'b.csv', accountId: accountB),
        );
        await waitFor((s) => s.canRun);
        bloc.add(const ImportRunRequested());
        state = await waitFor((s) => s.step == ImportStep.summary);

        expect(state.accountsWithTransactions, 2);
        expect(state.canGoToReconciliation, isTrue);
      },
    );

    test('bắt đầu lượt mới thì xoá sạch stepper nhưng giữ tài khoản', () async {
      picker.files = <PickedFile>[pick('sao-ke.csv')];
      bloc = build();
      bloc.add(const ImportStarted());
      bloc.add(const ImportFilesPickRequested());
      await waitFor((state) => state.files.isNotEmpty);
      bloc.add(
        ImportFileAccountAssigned(fileName: 'sao-ke.csv', accountId: accountA),
      );
      await waitFor((state) => state.canRun);
      bloc.add(const ImportRunRequested());
      await waitFor((state) => state.step == ImportStep.summary);

      bloc.add(const ImportReset());
      final state = await waitFor(
        (state) => state.step == ImportStep.pickFiles,
      );
      expect(state.files, isEmpty);
      expect(state.summary, isNull);
      expect(state.accounts, hasLength(2));
    });
  });
}
