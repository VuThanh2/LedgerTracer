import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/export/export_dataset/export_dataset_dto.dart';
import 'package:ledger_tracer/application/export/export_dataset/export_dataset_use_case.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import 'package:ledger_tracer/application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/domain/entities/import_error_row.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/pair_status.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';

import '_support/fake_gateways.dart';
import '_support/fake_repositories.dart';
import '_support/seed.dart';

void main() {
  late FakeDatabase db;
  late Seed seed;
  late FakeFileSaver fileSaver;
  late ExportDatasetUseCase exportDataset;
  late ViewCashFlowUseCase viewCashFlow;

  late int accountA;
  late int accountB;
  late int recordA;
  late int recordB;

  final now = DateTime.utc(2025, 11, 2, 8, 45, 30);

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    fileSaver = FakeFileSaver();
    exportDataset = ExportDatasetUseCase(
      transactions: db.transactions,
      reconciliation: db.reconciliation,
      imports: db.imports,
      accounts: db.accounts,
      exporter: const FakeTabularExporter(),
      fileSaver: fileSaver,
      runner: const MainThreadRunner(PlatformCapabilities.web()),
      strategies: const StrategySelector(PlatformCapabilities.web()),
      now: () => now,
    );
    viewCashFlow = ViewCashFlowUseCase(
      transactions: db.transactions,
      accounts: db.accounts,
    );

    accountA = await seed.account('Tài khoản vận hành');
    accountB = await seed.account('Ví thu hộ');
    recordA = await seed.fileRecord(accountId: accountA);
    recordB = await seed.fileRecord(accountId: accountB);
  });

  Future<int> tx({
    int? account,
    int? record,
    int amount = -500000,
    int month = 3,
    int day = 10,
    Currency currency = Currency.vnd,
    String description = 'CK tien hang',
  }) => seed.transaction(
    accountId: account ?? accountA,
    recordId: record ?? recordA,
    amount: amount,
    bookingDate: DateTime.utc(2025, month, day),
    currency: currency,
    description: description,
  );

  String contentOf(ExportResult result) =>
      FakeTabularExporter.decode(fileSaver.savedBytes.last);

  group('xuất dữ liệu (UC-11)', () {
    test('xuất danh sách giao dịch kèm loại tiền ở từng dòng', () async {
      // Một cột "1.000" trống trơn trong bảng gộp nhiều loại tiền sẽ bị mặc định
      // hiểu là VND.
      await tx(amount: -500000);
      await tx(amount: -100, currency: Currency.usd, day: 11);

      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );

      expect(result.isOk, isTrue);
      final content = contentOf(result.valueOrNull!);
      expect(content, contains('VND'));
      expect(content, contains('USD'));
      expect(result.valueOrNull!.rowCount, 2);
    });

    test('ghi rõ file không được mã hoá ngay ở đầu file', () async {
      await tx();
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(contentOf(result.valueOrNull!), contains('không được mã hoá'));
    });

    test('phản ánh đúng bộ lọc đang áp dụng, và ghi tiêu chí ở đầu file', () async {
      // Không ghi thì người nhận file không có cách nào biết dữ liệu đã bị thu
      // hẹp bởi điều kiện gì.
      await tx(day: 5, description: 'CK tien hang');
      await tx(day: 25, description: 'Tra no');

      final result = await exportDataset.execute(
        ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter(
              keyword: SearchText.query('tien hang'),
              dateRange: DateRange(
                from: DateTime.utc(2025, 3, 1),
                to: DateTime.utc(2025, 3, 10),
              ),
            ),
            format: ExportFormat.csv,
          ),
        ),
      );

      expect(result.valueOrNull!.rowCount, 1);
      final content = contentOf(result.valueOrNull!);
      expect(content, contains('Từ khoá'));
      expect(content, contains('Khoảng ngày'));
    });

    test('nói rõ khi không có bộ lọc nào', () async {
      await tx();
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(
        contentOf(result.valueOrNull!),
        contains('Không áp dụng bộ lọc nào'),
      );
    });

    test('đánh dấu đúng những dòng thuộc cặp đã xác nhận', () async {
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);
      await tx(day: 20, amount: -1);

      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );

      final dataLines = contentOf(result.valueOrNull!)
          .split('\n')
          .where((line) => line.contains('2025-'))
          .toList();
      expect(dataLines.where((line) => line.contains(';x;')).length, 2);
    });

    test('gom đủ mọi trang, không dừng ở trang đầu', () async {
      // Một danh sách xuất được có thể dài hàng trăm nghìn dòng; dừng ở trang
      // đầu là mất dữ liệu mà không có dấu hiệu nào báo.
      for (var day = 1; day <= 25; day++) {
        await tx(day: day, amount: -1000 - day);
      }
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(result.valueOrNull!.rowCount, 25);
    });

    test('xuất kết quả đối soát kèm độ lệch ngày', () async {
      final out = await tx(day: 10);
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 500000,
        day: 13,
      );
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportReconciliation(
            status: PairStatus.confirmed,
            format: ExportFormat.csv,
          ),
        ),
      );

      expect(result.valueOrNull!.rowCount, 1);
      final content = contentOf(result.valueOrNull!);
      expect(content, contains('Tài khoản vận hành'));
      expect(content, contains('Ví thu hộ'));
      expect(content.trim().split('\n').last, endsWith(';3'));
    });

    test('xuất thống kê ghi rõ loại tiền và trạng thái tuỳ chọn loại trừ', () async {
      await tx(amount: 1000000);
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportStatistics(
            currency: Currency.vnd,
            grouping: CashFlowGrouping.byPeriod,
            format: ExportFormat.csv,
          ),
        ),
      );
      final content = contentOf(result.valueOrNull!);
      expect(content, contains('Loại tiền: VND'));
      expect(content, contains('Loại trừ giao dịch nội bộ đã đối soát: có'));
    });

    test('xuất thống kê theo tài khoản dùng tên tài khoản làm nhãn cột', () async {
      await tx(amount: 1000000);
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportStatistics(
            currency: Currency.vnd,
            grouping: CashFlowGrouping.byAccount,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(contentOf(result.valueOrNull!), contains('Tài khoản vận hành'));
    });

    test('xuất dòng lỗi kèm số thứ tự dòng gốc và lý do', () async {
      // Hai cột này là thứ làm cho luồng "sửa trên file gốc rồi nhập lại" khả
      // thi, và luồng đó khả thi nhờ chống trùng ở UC-02.
      await db.imports.addErrorRows(<ImportErrorRow>[
        ImportErrorRow.from(
          recordId: recordA,
          sourceLineNumber: 42,
          rawLine: '2025-13-45;abc;;',
          reason: 'Ngày không hợp lệ',
        ),
        ImportErrorRow.from(
          recordId: recordA,
          sourceLineNumber: 7,
          rawLine: ';;;',
          reason: 'Thiếu số tiền',
        ),
      ]);

      final result = await exportDataset.execute(
        ExportDatasetRequest(
          dataset: ExportErrorRows(
            importFileRecordId: recordA,
            format: ExportFormat.csv,
          ),
        ),
      );

      expect(result.valueOrNull!.rowCount, 2);
      final content = contentOf(result.valueOrNull!);
      expect(content, contains('Dòng gốc'));
      expect(content, contains('42;Ngày không hợp lệ'));
      expect(content, contains('7;Thiếu số tiền'));
      // Tên file gốc nằm ở phần đầu để người dùng biết sửa file nào.
      expect(content, contains('seed.csv'));
    });

    test('dòng lỗi vẫn xuất lại được sau khi lượt nhập đã bị hoàn tác', () async {
      // Bản ghi đã hoàn tác ở lại lịch sử chính vì lý do này.
      await db.imports.addErrorRows(<ImportErrorRow>[
        ImportErrorRow.from(
          recordId: recordA,
          sourceLineNumber: 1,
          rawLine: 'x',
          reason: 'r',
        ),
      ]);
      await tx();
      await seed.closeRecord(recordA);
      await db.imports.updateFileRecord(
        db.fileRecordRows[recordA]!.revert(now),
      );

      final result = await exportDataset.execute(
        ExportDatasetRequest(
          dataset: ExportErrorRows(
            importFileRecordId: recordA,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(result.valueOrNull!.rowCount, 1);
    });

    test('xuất dòng lỗi của một bản ghi không tồn tại báo không tìm thấy', () async {
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportErrorRows(
            importFileRecordId: 999999,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });

    test('tên file gợi ý kèm mốc thời gian nên không ghi đè lần xuất trước', () async {
      await tx();
      await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );
      expect(fileSaver.savedNames.single, startsWith('giao-dich-'));
      expect(fileSaver.savedNames.single, contains('2025-11-02'));
      expect(fileSaver.savedNames.single, endsWith('.csv'));
      expect(fileSaver.savedNames.single.contains(':'), isFalse);
    });

    test('định dạng Excel đổi cả phần mở rộng lẫn cách mã hoá', () async {
      await tx();
      final result = await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.excel,
          ),
        ),
      );
      expect(fileSaver.savedNames.single, endsWith('.xlsx'));
      expect(contentOf(result.valueOrNull!), contains('format=excel'));
    });

    test('báo tiến trình qua ba giai đoạn', () async {
      for (var day = 1; day <= 3; day++) {
        await tx(day: day, amount: -1000 - day);
      }
      final stages = <ExportStage>[];
      await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
        onProgress: (progress) => stages.add(progress.stage),
      );

      expect(stages.first, ExportStage.collecting);
      expect(stages, contains(ExportStage.encoding));
      expect(stages.last, ExportStage.saving);
    });

    test('tiến trình gom dữ liệu có tỷ lệ vì tổng số dòng biết trước', () async {
      for (var day = 1; day <= 3; day++) {
        await tx(day: day, amount: -1000 - day);
      }
      final fractions = <double?>[];
      await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
        onProgress: (progress) {
          if (progress.stage == ExportStage.collecting) {
            fractions.add(progress.fraction);
          }
        },
      );
      expect(fractions.last, 1.0);
    });

    test('huỷ giữa chừng dừng lại và không lưu file nào', () async {
      // Xuất là thao tác chỉ đọc nên huỷ không cần dọn dẹp gì.
      await tx();
      final result = await exportDataset.execute(
        ExportDatasetRequest(
          dataset: const ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
          cancellation: CancellationSignal.cancelled(),
        ),
      );

      expect(result.failureOrNull, isA<CancelledFailure>());
      expect(fileSaver.savedNames, isEmpty);
    });

    test('xuất không thay đổi bất kỳ dữ liệu nào', () async {
      final out = await tx();
      final into = await tx(account: accountB, record: recordB, amount: 500000);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);
      final before = db.snapshot();

      await exportDataset.execute(
        const ExportDatasetRequest(
          dataset: ExportTransactions(
            filter: TransactionFilter.none,
            format: ExportFormat.csv,
          ),
        ),
      );

      expect(db.transactionRows.length, before.transactions.length);
      expect(db.pairRows.length, before.pairs.length);
      expect(db.rejectionRows.length, before.rejections.length);
    });
  });

  group('thống kê dòng tiền (UC-10)', () {
    test('gom theo tháng, tách tiền vào và tiền ra', () async {
      await tx(month: 1, amount: 1000000);
      await tx(month: 1, amount: -400000, day: 20);
      await tx(month: 2, amount: 500000);

      final result = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.vnd),
      );

      final buckets = result.valueOrNull!.buckets.cast<PeriodCashFlow>();
      expect(buckets.length, 2);
      expect(buckets.first.periodStart, DateTime.utc(2025, 1));
      expect(buckets.first.inflow, const Money(1000000, Currency.vnd));
      expect(buckets.first.outflow, const Money(-400000, Currency.vnd));
      expect(buckets.first.net, const Money(600000, Currency.vnd));
    });

    test('tách riêng theo từng loại tiền, không bao giờ cộng gộp', () async {
      // Tỷ giá đòi hỏi nguồn dữ liệu ngoài, trái với nguyên tắc offline.
      await tx(amount: 1000000);
      await tx(amount: 100, currency: Currency.usd, day: 11);

      final vnd = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.vnd),
      );
      final usd = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.usd),
      );

      expect(
        vnd.valueOrNull!.buckets.single.inflow,
        const Money(1000000, Currency.vnd),
      );
      expect(
        usd.valueOrNull!.buckets.single.inflow,
        const Money(100, Currency.usd),
      );
    });

    test('loại trừ giao dịch nội bộ đã xác nhận, mặc định bật', () async {
      final out = await tx(amount: -500000);
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 500000,
        day: 11,
      );
      await tx(amount: 900000, day: 20);
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      final excluded = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.vnd),
      );
      expect(excluded.valueOrNull!.excludeInternalTransfers, isTrue);
      expect(
        excluded.valueOrNull!.buckets.single.inflow,
        const Money(900000, Currency.vnd),
      );
      expect(
        excluded.valueOrNull!.buckets.single.outflow,
        const Money(0, Currency.vnd),
      );
    });

    test('tắt loại trừ cho ra tổng thô trùng với sao kê gốc', () async {
      // Chênh lệch giữa hai chế độ chính là thứ cho thấy đối soát đã làm được gì.
      final out = await tx(amount: -500000);
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 500000,
        day: 11,
      );
      await seed.pair(outgoingId: out, incomingId: into, confirmed: true);

      final raw = await viewCashFlow.execute(
        const ViewCashFlowRequest(
          currency: Currency.vnd,
          excludeInternalTransfers: false,
        ),
      );
      expect(
        raw.valueOrNull!.buckets.single.inflow,
        const Money(500000, Currency.vnd),
      );
      expect(
        raw.valueOrNull!.buckets.single.outflow,
        const Money(-500000, Currency.vnd),
      );
    });

    test('cặp mới chỉ là gợi ý thì chưa bị loại khỏi số liệu', () async {
      // Gợi ý không được ảnh hưởng tới số liệu tài chính cho tới khi người dùng
      // xác nhận.
      final out = await tx(amount: -500000);
      final into = await tx(
        account: accountB,
        record: recordB,
        amount: 500000,
        day: 11,
      );
      await seed.pair(outgoingId: out, incomingId: into);

      final result = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.vnd),
      );
      expect(
        result.valueOrNull!.buckets.single.outflow,
        const Money(-500000, Currency.vnd),
      );
    });

    test('gom theo tài khoản kèm tên để biểu đồ đọc được', () async {
      await tx(amount: 1000000);
      await tx(account: accountB, record: recordB, amount: 200000);

      final result = await viewCashFlow.execute(
        const ViewCashFlowRequest(
          currency: Currency.vnd,
          grouping: CashFlowGrouping.byAccount,
        ),
      );

      final buckets = result.valueOrNull!.buckets.cast<AccountCashFlow>();
      expect(buckets.length, 2);
      expect(
        result.valueOrNull!.accountNames[buckets.first.accountId],
        'Tài khoản vận hành',
      );
    });

    test('thu hẹp được theo khoảng ngày', () async {
      await tx(month: 1, amount: 100);
      await tx(month: 6, amount: 200);

      final result = await viewCashFlow.execute(
        ViewCashFlowRequest(
          currency: Currency.vnd,
          dateRange: DateRange(
            from: DateTime.utc(2025, 1, 1),
            to: DateTime.utc(2025, 1, 31),
          ),
        ),
      );
      expect(result.valueOrNull!.buckets.length, 1);
    });

    test('gom theo ngày và theo năm cũng đúng', () async {
      await tx(month: 1, day: 5, amount: 100);
      await tx(month: 1, day: 6, amount: 200);

      final byDay = await viewCashFlow.execute(
        const ViewCashFlowRequest(
          currency: Currency.vnd,
          period: CashFlowPeriod.day,
        ),
      );
      expect(byDay.valueOrNull!.buckets.length, 2);

      final byYear = await viewCashFlow.execute(
        const ViewCashFlowRequest(
          currency: Currency.vnd,
          period: CashFlowPeriod.year,
        ),
      );
      expect(byYear.valueOrNull!.buckets.length, 1);
    });

    test('không có dữ liệu thì trả về rỗng chứ không nổ', () async {
      final result = await viewCashFlow.execute(
        const ViewCashFlowRequest(currency: Currency.vnd),
      );
      expect(result.valueOrNull!.buckets, isEmpty);
    });
  });
}
