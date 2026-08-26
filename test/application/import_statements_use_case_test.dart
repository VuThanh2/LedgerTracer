import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/import/contracts/import_progress.dart';
import 'package:ledger_tracer/application/import/import_statements/import_statements_dto.dart';
import 'package:ledger_tracer/application/import/import_statements/import_statements_use_case.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/value_objects/import_file_status.dart';
import 'package:ledger_tracer/domain/value_objects/import_session_status.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

import '_support/fake_gateways.dart';
import '_support/fake_repositories.dart';

/// UC-02 là workload chính của đề tài, và chống trùng là quy tắc dễ hiểu sai
/// nhất trong toàn bộ hệ thống: nó là phép **đếm**, không phải phép kiểm tồn
/// tại. Hiểu sai theo hướng nào cũng hỏng — kiểm tồn tại thì nuốt mất giao dịch
/// thật, không kiểm gì thì nhân đôi dữ liệu mỗi lần nhập lại.
void main() {
  late FakeDatabase db;
  late ImportStatementsUseCase useCase;
  late int accountA;
  late int accountB;

  final now = DateTime.utc(2025, 9, 1, 12);

  setUp(() async {
    db = FakeDatabase();
    useCase = ImportStatementsUseCase(
      transactions: db.transactions,
      imports: db.imports,
      unitOfWork: db.unitOfWork,
      runner: const MainThreadRunner(PlatformCapabilities.web()),
      strategies: const StrategySelector(PlatformCapabilities.web()),
      parserFactory: FakeParserFactory(),
      now: () => now,
    );
    accountA = (await db.accounts.add(
      BankAccount.create(displayName: 'A', createdAt: now),
    )).accountId!;
    accountB = (await db.accounts.add(
      BankAccount.create(displayName: 'B', createdAt: now),
    )).accountId!;
  });

  ImportFileInput file(
    String name,
    List<String> lines, {
    required int accountId,
    StatementFormat format = StatementFormat.csv,
    bool skip = false,
  }) => ImportFileInput(
    fileName: name,
    bytes: FakeStatementParser.file(lines),
    format: format,
    accountId: accountId,
    skip: skip,
  );

  String row({
    String date = '2025-03-10',
    int amount = -100000,
    String counterparty = 'Doi tac',
    String description = 'CK tien hang',
  }) => FakeStatementParser.line(
    date: date,
    amount: amount,
    counterparty: counterparty,
    description: description,
  );

  Future<ImportSummary> run(
    List<ImportFileInput> files, {
    ConcurrencyStrategy? strategy,
    CancellationSignal? cancellation,
    void Function(ImportProgress progress)? onProgress,
  }) async {
    final result = await useCase.execute(
      ImportStatementsRequest(
        files: files,
        strategy: strategy ?? ConcurrencyStrategy.mainThread(batchSize: 2),
        cancellation: cancellation,
      ),
      onProgress: onProgress,
    );
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!;
  }

  List<Transaction> transactionsOf(int accountId) =>
      db.transactionRows.values
          .where((tx) => tx.accountId == accountId)
          .toList(growable: false);

  group('nhập một file', () {
    test('ghi đủ số dòng và ghi nhận kết quả vào lịch sử', () async {
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[
          row(date: '2025-03-10'),
          row(date: '2025-03-11'),
          row(date: '2025-03-12'),
        ], accountId: accountA),
      ]);

      expect(summary.importedCount, 3);
      expect(summary.duplicateSkippedCount, 0);
      expect(summary.errorRowCount, 0);
      expect(summary.wasCancelled, isFalse);
      expect(summary.files.single.status, ImportFileStatus.completed);
      expect(db.transactionRows.length, 3);
    });

    test('mỗi giao dịch trỏ về đúng bản ghi nhập đã sinh ra nó', () async {
      // Không có liên kết nguồn gốc thì hoàn tác phải suy đoán, và suy đoán thì
      // xoá nhầm khi hai lượt cùng tài khoản có phần thời gian giao nhau.
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[row()], accountId: accountA),
      ]);
      final recordId = summary.files.single.recordId;
      expect(
        transactionsOf(accountA).single.importFileRecordId,
        recordId,
      );
    });

    test('gán đúng tài khoản đích và giữ số thứ tự dòng gốc', () async {
      await run(<ImportFileInput>[
        file('a.csv', <String>[row(), row(date: '2025-03-11')],
            accountId: accountB),
      ]);
      final rows = transactionsOf(accountB);
      expect(rows.length, 2);
      expect(
        rows.map((tx) => tx.sourceLineNumber).toList()..sort(),
        <int>[1, 2],
      );
    });

    test('đóng lượt nhập ở trạng thái hoàn tất', () async {
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[row()], accountId: accountA),
      ]);
      expect(
        db.sessionRows[summary.sessionId]!.status,
        ImportSessionStatus.completed,
      );
      expect(db.sessionRows[summary.sessionId]!.completedAt, now);
    });

    test('file rỗng vẫn được ghi nhận là một lần nhập hoàn tất', () async {
      final summary = await run(<ImportFileInput>[
        file('rong.csv', <String>[], accountId: accountA),
      ]);
      expect(summary.importedCount, 0);
      expect(summary.files.single.status, ImportFileStatus.completed);
      expect(db.fileRecordRows.length, 1);
    });
  });

  group('chống trùng là phép đếm', () {
    test('nhập lại đúng file đó không thêm gì', () async {
      final lines = <String>[
        row(date: '2025-03-10'),
        row(date: '2025-03-11'),
      ];
      await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);
      final second = await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);

      expect(second.importedCount, 0);
      expect(second.duplicateSkippedCount, 2);
      expect(db.transactionRows.length, 2);
    });

    test('hai dòng giống hệt nhau trong cùng một file được nhập đủ', () async {
      // Hai lần thanh toán cùng số tiền, cùng nội dung, trong một ngày là hai
      // giao dịch thật. Kiểm tồn tại thay vì đếm sẽ nuốt mất một dòng.
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[row(), row()], accountId: accountA),
      ]);
      expect(summary.importedCount, 2);
      expect(summary.duplicateSkippedCount, 0);
    });

    test('nhập lại file có dòng lặp chỉ bỏ qua đúng số đã có', () async {
      final lines = <String>[row(), row()];
      await run(<ImportFileInput>[file('a.csv', lines, accountId: accountA)]);
      final second = await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);
      expect(second.importedCount, 0);
      expect(second.duplicateSkippedCount, 2);
      expect(db.transactionRows.length, 2);
    });

    test('file mở rộng chỉ nhập thêm phần chênh lệch', () async {
      // Sao kê tháng sau chứa lại phần đầu tháng trước.
      await run(<ImportFileInput>[
        file('a.csv', <String>[row(), row()], accountId: accountA),
      ]);
      final second = await run(<ImportFileInput>[
        file('a.csv', <String>[row(), row(), row()], accountId: accountA),
      ]);
      expect(second.importedCount, 1);
      expect(second.duplicateSkippedCount, 2);
      expect(db.transactionRows.length, 3);
    });

    test('đếm đúng cả khi các dòng trùng nằm vắt qua hai lô', () async {
      // Sổ chống trùng được chốt lúc gặp fingerprint lần đầu trong file; hỏi lại
      // cơ sở dữ liệu giữa chừng sẽ đếm lẫn cả những dòng chính file này vừa ghi.
      await run(<ImportFileInput>[
        file('a.csv', <String>[row()], accountId: accountA),
      ]);
      final second = await run(<ImportFileInput>[
        file('a.csv', List<String>.filled(5, row()), accountId: accountA),
      ], strategy: ConcurrencyStrategy.mainThread(batchSize: 2));
      expect(second.duplicateSkippedCount, 1);
      expect(second.importedCount, 4);
      expect(db.transactionRows.length, 5);
    });

    test('chống trùng có hiệu lực giữa hai file trong cùng một lượt', () async {
      // Hai sao kê chồng thời gian được phân tích song song nhưng ghi tuần tự,
      // nên file sau luôn nhìn thấy những gì file trước đã ghi.
      final summary = await run(<ImportFileInput>[
        file('thang1-3.csv', <String>[
          row(date: '2025-01-05'),
          row(date: '2025-02-05'),
        ], accountId: accountA),
        file('thang2-4.csv', <String>[
          row(date: '2025-02-05'),
          row(date: '2025-03-05'),
        ], accountId: accountA),
      ]);

      expect(summary.importedCount, 3);
      expect(summary.duplicateSkippedCount, 1);
      expect(db.transactionRows.length, 3);
      expect(summary.files[1].duplicateSkippedCount, 1);
    });

    test('hai file gán hai tài khoản khác nhau không bao giờ là trùng', () async {
      // Đó là hai vế của một giao dịch chuyển tiền nội bộ, thuộc nghiệp vụ đối
      // soát chứ không phải trùng lặp.
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[row(amount: -500000)], accountId: accountA),
        file('b.csv', <String>[row(amount: -500000)], accountId: accountB),
      ]);
      expect(summary.importedCount, 2);
      expect(summary.duplicateSkippedCount, 0);
    });

    test('nội dung khác nhau thì không phải trùng', () async {
      await run(<ImportFileInput>[
        file('a.csv', <String>[row(description: 'CK tien hang')],
            accountId: accountA),
      ]);
      final second = await run(<ImportFileInput>[
        file('b.csv', <String>[row(description: 'CK tien dien')],
            accountId: accountA),
      ]);
      expect(second.importedCount, 1);
    });
  });

  group('thứ tự ghi xác định được', () {
    test('ghi theo thứ tự người dùng chọn file, không theo tốc độ phân tích', () async {
      // Để thứ tự ghi phụ thuộc tốc độ phân tích thì hai lần nhập cùng một tập
      // file có thể cho hai kết quả khác nhau, và lỗi đó không tái hiện được.
      await run(<ImportFileInput>[
        file('dau.csv', <String>[row(date: '2025-01-01')], accountId: accountA),
        file('giua.csv', <String>[row(date: '2025-01-02')], accountId: accountA),
        file('cuoi.csv', <String>[row(date: '2025-01-03')], accountId: accountA),
      ]);

      final byId = db.transactionRows.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      expect(
        byId.map((entry) => entry.value.bookingDate.day).toList(),
        <int>[1, 2, 3],
      );
    });

    test('kết quả tổng kết giữ nguyên thứ tự file người dùng chọn', () async {
      final summary = await run(<ImportFileInput>[
        file('bo-qua.csv', <String>[row()], accountId: accountA, skip: true),
        file('thu-hai.csv', <String>[row(date: '2025-02-02')],
            accountId: accountA),
      ]);
      expect(
        summary.files.map((f) => f.fileName).toList(),
        <String>['bo-qua.csv', 'thu-hai.csv'],
      );
    });
  });

  group('lỗi từng dòng', () {
    test('dòng hỏng không làm dừng các dòng còn lại', () async {
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[
          row(date: '2025-03-10'),
          FakeStatementParser.brokenLine('thieu cot so tien'),
          row(date: '2025-03-12'),
        ], accountId: accountA),
      ]);

      expect(summary.importedCount, 2);
      expect(summary.errorRowCount, 1);
      expect(summary.files.single.status, ImportFileStatus.partiallyFailed);
    });

    test('dòng lỗi được lưu kèm số thứ tự dòng gốc và lý do', () async {
      // Đó là hai thứ làm cho luồng "sửa trên file gốc rồi nhập lại" khả thi.
      final summary = await run(<ImportFileInput>[
        file('a.csv', <String>[
          row(),
          FakeStatementParser.brokenLine('sai dinh dang ngay'),
        ], accountId: accountA),
      ]);

      final errors = await db.imports.findErrorRows(summary.files.single.recordId);
      expect(errors.length, 1);
      expect(errors.single.sourceLineNumber, 2);
      expect(errors.single.reason, 'sai dinh dang ngay');
      expect(errors.single.rawExcerpt, contains('sai dinh dang ngay'));
    });

    test('file hỏng hoàn toàn thành một dòng lỗi, không kéo file khác chết', () async {
      final useCaseWithBadExcel = ImportStatementsUseCase(
        transactions: db.transactions,
        imports: db.imports,
        unitOfWork: db.unitOfWork,
        runner: const MainThreadRunner(PlatformCapabilities.web()),
        strategies: const StrategySelector(PlatformCapabilities.web()),
        parserFactory: FakeParserFactory(
          explodingFormats: const <StatementFormat>{StatementFormat.excel},
        ),
        now: () => now,
      );

      final result = await useCaseWithBadExcel.execute(
        ImportStatementsRequest(
          files: <ImportFileInput>[
            file('hong.xlsx', <String>[row()],
                accountId: accountA, format: StatementFormat.excel),
            file('tot.csv', <String>[row(date: '2025-04-04')],
                accountId: accountA),
          ],
          strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
        ),
      );

      expect(result.isOk, isTrue);
      final summary = result.valueOrNull!;
      expect(summary.files[0].errorRowCount, 1);
      expect(summary.files[0].importedCount, 0);
      expect(summary.files[1].importedCount, 1);

      final errors = await db.imports.findErrorRows(summary.files[0].recordId);
      expect(errors.single.reason, contains('Không đọc được file'));
    });
  });

  group('bỏ qua file', () {
    test('file bị bỏ qua vẫn có bản ghi riêng trong lịch sử', () async {
      // "Bỏ qua file này" là một quyết định của người dùng, không phải lỗi đọc
      // file, nên nó phải hiện ra trong lịch sử với đúng nghĩa đó.
      final summary = await run(<ImportFileInput>[
        file('lech-so-tk.csv', <String>[row()],
            accountId: accountA, skip: true),
      ]);

      expect(summary.files.single.status, ImportFileStatus.skipped);
      expect(summary.importedCount, 0);
      expect(db.transactionRows, isEmpty);
      expect(db.fileRecordRows.length, 1);
    });

    test('bỏ qua một file không ảnh hưởng các file còn lại', () async {
      final summary = await run(<ImportFileInput>[
        file('bo-qua.csv', <String>[row()], accountId: accountA, skip: true),
        file('nhap.csv', <String>[row(date: '2025-05-05')],
            accountId: accountA),
      ]);
      expect(summary.importedCount, 1);
      expect(summary.files[0].status, ImportFileStatus.skipped);
      expect(summary.files[1].status, ImportFileStatus.completed);
    });
  });

  group('gián đoạn bị động — tiến trình chết, không có mã lệnh nào chạy', () {
    // Huỷ chủ động là luồng sạch vì có mã lệnh chạy tại thời điểm dừng. Khi hệ
    // điều hành kết liễu tiến trình thì không có gì chạy cả: `AppLifecycleState`
    // không được đảm bảo gọi, và trên Web `beforeunload` không cho làm việc bất
    // đồng bộ. Nên bước chốt cuối không được phép là nơi duy nhất bộ đếm đi
    // xuống cơ sở dữ liệu.

    test('bộ đếm xuống cơ sở dữ liệu theo từng lô, không đợi bước chốt', () async {
      final imported = <int>[];
      db.unitOfWork.onCommit =
          () => imported.add(db.fileRecordRows.values.single.importedCount);

      await run(
        <ImportFileInput>[
          file('a.csv', <String>[
            row(date: '2025-06-01'),
            row(date: '2025-06-02'),
            row(date: '2025-06-03'),
            row(date: '2025-06-04'),
          ], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
      );

      // Hai lô, mỗi lô hai dòng, rồi tới lần commit của bước chốt. Con số phải
      // lớn dần cùng nhịp với các dòng đã ghi — nếu nó chỉ nhảy lên ở lần cuối
      // thì một lần chết giữa chừng sẽ để lại bản ghi nói 0 trong khi bảng
      // Transaction đã có dữ liệu.
      expect(imported, <int>[2, 4, 4]);
    });

    test('bộ đếm khớp với dữ liệu đã ghi tại mọi ranh giới commit', () async {
      db.unitOfWork.onCommit = () {
        for (final record in db.fileRecordRows.values) {
          final written = db.transactionRows.values
              .where((tx) => tx.importFileRecordId == record.recordId)
              .length;
          final failed = db.errorRows
              .where((errorRow) => errorRow.recordId == record.recordId)
              .length;
          expect(record.importedCount, written, reason: record.fileName);
          expect(record.errorRowCount, failed, reason: record.fileName);
        }
      };

      await run(
        <ImportFileInput>[
          file('a.csv', <String>[
            row(date: '2025-06-01'),
            row(date: '2025-06-02'),
            FakeStatementParser.brokenLine(),
            row(date: '2025-06-03'),
          ], accountId: accountA),
          file('b.csv', <String>[
            row(date: '2025-06-01'),
            row(date: '2025-07-01'),
          ], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
      );
    });

    test('lô toàn dòng trùng vẫn ghi bộ đếm xuống, dù không thêm dòng nào', () async {
      // `duplicateSkippedCount` là bộ đếm duy nhất không đếm lại được từ đâu:
      // dòng bị bỏ vì đã có thì không nằm ở bảng nào. Bỏ qua lô không sinh ghi
      // là mất hẳn con số đó khi tiến trình chết.
      final lines = <String>[row(date: '2025-08-01'), row(date: '2025-08-02')];
      await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);

      final skipped = <int>[];
      db.unitOfWork.onCommit = () => skipped.add(
        db.fileRecordRows.values.last.duplicateSkippedCount,
      );
      await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);

      expect(db.transactionRows.length, 2);
      expect(skipped, <int>[2, 2]);
    });
  });

  group('huỷ giữa chừng', () {
    test('giữ lại phần đã ghi và bỏ hẳn file chưa bắt đầu', () async {
      final cancellation = CancellationSignal();
      final summary = await run(
        <ImportFileInput>[
          file('a.csv', <String>[
            row(date: '2025-06-01'),
            row(date: '2025-06-02'),
            row(date: '2025-06-03'),
            row(date: '2025-06-04'),
          ], accountId: accountA),
          file('b.csv', <String>[row(date: '2025-07-01')],
              accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.processedTotal >= 2) cancellation.cancel();
        },
      );

      expect(summary.wasCancelled, isTrue);
      // Lô đầu đã ghi xong thì ở lại; huỷ không phải là quay lui.
      expect(db.transactionRows.length, 2);
      expect(summary.files[0].status, ImportFileStatus.cancelled);
      expect(summary.files[1].status, ImportFileStatus.cancelled);
      expect(
        db.sessionRows[summary.sessionId]!.status,
        ImportSessionStatus.cancelled,
      );
    });

    test('nhập lại chính file đã huỷ chỉ nhận phần còn thiếu', () async {
      // Luồng này khả thi chính nhờ chống trùng: huỷ không phải rollback.
      final cancellation = CancellationSignal();
      final lines = <String>[
        row(date: '2025-06-01'),
        row(date: '2025-06-02'),
        row(date: '2025-06-03'),
        row(date: '2025-06-04'),
      ];
      await run(
        <ImportFileInput>[file('a.csv', lines, accountId: accountA)],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
        cancellation: cancellation,
        onProgress: (progress) {
          if (progress.processedTotal >= 2) cancellation.cancel();
        },
      );
      expect(db.transactionRows.length, 2);

      final retry = await run(<ImportFileInput>[
        file('a.csv', lines, accountId: accountA),
      ]);

      expect(retry.duplicateSkippedCount, 2);
      expect(retry.importedCount, 2);
      expect(db.transactionRows.length, 4);
      // Ghi nhận thành một lượt mới, không nối vào lượt đã huỷ.
      expect(db.sessionRows.length, 2);
    });

    test('huỷ trước khi bắt đầu thì không ghi gì cả', () async {
      final summary = await run(
        <ImportFileInput>[
          file('a.csv', <String>[row()], accountId: accountA),
        ],
        cancellation: CancellationSignal.cancelled(),
      );
      expect(db.transactionRows, isEmpty);
      expect(summary.files.single.status, ImportFileStatus.cancelled);
    });
  });

  group('tiến trình', () {
    test('số file đã xong chỉ tăng khi một file thật sự kết thúc', () async {
      // Báo cáo tiến trình không đi qua cổng giao hàng, nên không thể suy ra số
      // file đã xong từ chỉ số của lô vừa tới.
      final completed = <int>[];
      await run(
        <ImportFileInput>[
          file('a.csv', <String>[row(date: '2025-01-01'), row(date: '2025-01-02')],
              accountId: accountA),
          file('b.csv', <String>[row(date: '2025-02-01')], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 1),
        onProgress: (progress) => completed.add(progress.completedFiles),
      );

      // Không bao giờ lùi, và không bao giờ vượt quá số file.
      expect(completed, isNotEmpty);
      for (var i = 1; i < completed.length; i++) {
        expect(completed[i], greaterThanOrEqualTo(completed[i - 1]));
      }
      expect(completed.last, lessThanOrEqualTo(2));
      expect(completed.first, 0);
    });

    test('tổng số dòng cộng dồn không đếm trùng', () async {
      final totals = <int>[];
      await run(
        <ImportFileInput>[
          file('a.csv', <String>[
            row(date: '2025-01-01'),
            row(date: '2025-01-02'),
          ], accountId: accountA),
          file('b.csv', <String>[
            row(date: '2025-02-01'),
            row(date: '2025-02-02'),
          ], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 1),
        onProgress: (progress) => totals.add(progress.processedTotal),
      );
      expect(totals.last, 4);
      for (var i = 1; i < totals.length; i++) {
        expect(totals[i], greaterThanOrEqualTo(totals[i - 1]));
      }
    });

    test('báo được tổng số dòng của file nên thanh tiến trình có tỷ lệ', () async {
      final fractions = <double?>[];
      await run(
        <ImportFileInput>[
          file('a.csv', <String>[
            row(date: '2025-01-01'),
            row(date: '2025-01-02'),
            row(date: '2025-01-03'),
            row(date: '2025-01-04'),
          ], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.mainThread(batchSize: 2),
        onProgress: (progress) => fractions.add(progress.fileFraction),
      );
      expect(fractions.last, 1.0);
      expect(fractions.every((f) => f != null), isTrue);
    });

    test('nói đúng chế độ chạy để giao diện không giấu giới hạn của Web', () async {
      ImportProgress? last;
      final summary = await run(
        <ImportFileInput>[
          file('a.csv', <String>[row()], accountId: accountA),
        ],
        onProgress: (progress) => last = progress,
      );
      expect(last!.mode, ExecutionMode.mainThread);
      expect(last!.isBackground, isFalse);
      expect(summary.mode, ExecutionMode.mainThread);
    });
  });

  group('chiến lược concurrency', () {
    test('tự chọn khi giao diện không truyền gì', () async {
      final result = await useCase.execute(
        ImportStatementsRequest(
          files: <ImportFileInput>[
            file('a.csv', <String>[row()], accountId: accountA),
          ],
        ),
      );
      expect(result.isOk, isTrue);
      expect(result.valueOrNull!.mode, ExecutionMode.mainThread);
    });

    test('hạ chiến lược isolate về luồng chính khi nền tảng không có isolate', () async {
      // Nếu không có chốt chặn này, giao diện có thể yêu cầu một cấu hình không
      // thực hiện nổi và các file sẽ chen nhau trên luồng chính.
      final summary = await run(
        <ImportFileInput>[
          file('a.csv', <String>[row()], accountId: accountA),
          file('b.csv', <String>[row(date: '2025-08-08')], accountId: accountA),
        ],
        strategy: ConcurrencyStrategy.parallelIsolates(
          parallelism: 4,
          batchSize: 2,
        ),
      );
      expect(summary.mode, ExecutionMode.mainThread);
      expect(summary.importedCount, 2);
    });
  });
}
