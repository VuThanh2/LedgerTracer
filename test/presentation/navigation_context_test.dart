import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/export/export_dataset/export_dataset_dto.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/presentation/shared/bloc/load_status.dart';
import 'package:ledger_tracer/presentation/shared/export/view_models/export_source.dart';
import 'package:ledger_tracer/presentation/shell/view_models/navigation_intent.dart';
import 'package:ledger_tracer/presentation/statistics/bloc/statistics_state.dart';
import 'package:ledger_tracer/presentation/statistics/view_models/cash_flow_view_model.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/filter_chip_view_model.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_context.dart';

/// Screen Map đặt ra một ràng buộc mà không tầng nào bên dưới giữ hộ được: **mọi
/// đường điều hướng phải mang theo đủ ngữ cảnh để tập dữ liệu ở đích trùng với
/// thứ người dùng vừa bấm vào**. Thiếu một mảnh thì không có gì đổ vỡ — chỉ là
/// hai màn hình hiện hai con số khác nhau cho cùng một thứ, và người dùng sẽ tin
/// một trong hai đang sai. Nhóm test này là chốt chặn duy nhất cho điều đó.
void main() {
  group('bề rộng của một cột biểu đồ', () {
    test('cột tháng mở ra trọn tháng, không phải ngày đầu tháng', () {
      final range = CashFlowDrillDown.rangeOf(
        DateTime.utc(2025, 3),
        CashFlowPeriod.month,
      );
      expect(range.from, DateTime.utc(2025, 3, 1));
      expect(range.to, DateTime.utc(2025, 3, 31));
      expect(range.lengthInDays, 31);
    });

    test('tháng ngắn và tháng nhuận đều đúng', () {
      expect(
        CashFlowDrillDown.rangeOf(
          DateTime.utc(2025, 2),
          CashFlowPeriod.month,
        ).to,
        DateTime.utc(2025, 2, 28),
      );
      expect(
        CashFlowDrillDown.rangeOf(
          DateTime.utc(2024, 2),
          CashFlowPeriod.month,
        ).to,
        DateTime.utc(2024, 2, 29),
      );
    });

    test('tháng 12 không tràn sang năm sau', () {
      final range = CashFlowDrillDown.rangeOf(
        DateTime.utc(2025, 12),
        CashFlowPeriod.month,
      );
      expect(range.to, DateTime.utc(2025, 12, 31));
    });

    test('cột ngày và cột năm', () {
      expect(
        CashFlowDrillDown.rangeOf(
          DateTime.utc(2025, 3, 17),
          CashFlowPeriod.day,
        ).lengthInDays,
        1,
      );
      final year = CashFlowDrillDown.rangeOf(
        DateTime.utc(2025),
        CashFlowPeriod.year,
      );
      expect(year.from, DateTime.utc(2025, 1, 1));
      expect(year.to, DateTime.utc(2025, 12, 31));
    });
  });

  group('khoan xuống từ Thống kê (UC-10 → UC-04)', () {
    const state = StatisticsState(
      status: LoadStatus.ready,
      currency: Currency.usd,
      period: CashFlowPeriod.month,
      excludeInternalTransfers: true,
    );

    const periodBar = CashFlowBarViewModel(
      label: '03/2025',
      inflowText: '+0',
      outflowText: '+0',
      netText: '+0',
      inflowMinorUnits: 0,
      outflowMinorUnits: 0,
      netMinorUnits: 0,
      periodStart: null,
    );

    test('mang đủ ba mảnh: khoảng ngày, loại tiền, công tắc loại trừ', () {
      final intent = state.drillDownForBar(
        CashFlowBarViewModel(
          label: periodBar.label,
          inflowText: periodBar.inflowText,
          outflowText: periodBar.outflowText,
          netText: periodBar.netText,
          inflowMinorUnits: 0,
          outflowMinorUnits: 0,
          netMinorUnits: 0,
          periodStart: DateTime.utc(2025, 3),
        ),
      );

      expect(intent, isNotNull);
      expect(intent!.destination, NavDestination.transactions);
      expect(intent.draft.dateFrom, DateTime.utc(2025, 3, 1));
      expect(intent.draft.dateTo, DateTime.utc(2025, 3, 31));
      expect(intent.draft.currency, Currency.usd);
      // Loại tiền ở đây là **tiêu chí** người dùng đã chọn qua tab, không phải
      // giá trị điền sẵn của ô loại tiền — thiếu cờ này thì danh sách ở đích gộp
      // cả loại tiền khác.
      expect(intent.draft.filterByCurrency, isTrue);
      expect(intent.context.excludeInternalTransfers, isTrue);
    });

    test('bản nháp mang đi dựng ra đúng bộ tiêu chí', () {
      final draft = state
          .drillDownForBar(
            CashFlowBarViewModel(
              label: '03/2025',
              inflowText: '+0',
              outflowText: '+0',
              netText: '+0',
              inflowMinorUnits: 0,
              outflowMinorUnits: 0,
              netMinorUnits: 0,
              periodStart: DateTime.utc(2025, 3),
            ),
          )!
          .draft;
      final filter = draft.validate().filter!;

      expect(filter.currency, Currency.usd);
      expect(filter.dateRange, DateRange(
        from: DateTime.utc(2025, 3, 1),
        to: DateTime.utc(2025, 3, 31),
      ));
    });

    test('cột theo tài khoản mang theo tài khoản, giữ khoảng ngày đang lọc', () {
      final range = DateRange(
        from: DateTime.utc(2025),
        to: DateTime.utc(2025, 6, 30),
      );
      final intent = state.copyWith(dateRange: range).drillDownForBar(
        const CashFlowBarViewModel(
          label: 'Ví thu hộ',
          inflowText: '+0',
          outflowText: '+0',
          netText: '+0',
          inflowMinorUnits: 0,
          outflowMinorUnits: 0,
          netMinorUnits: 0,
          accountId: 7,
        ),
      );

      expect(intent!.draft.accountId, 7);
      expect(intent.draft.dateFrom, range.from);
      expect(intent.draft.dateTo, range.to);
    });

    test('chưa có loại tiền nào thì không có gì để khoan xuống', () {
      expect(const StatisticsState().drillDownForBar(periodBar), isNull);
    });
  });

  group('ngữ cảnh thu hẹp danh sách', () {
    test('ngữ cảnh lượt nhập thu hẹp trước bằng tài khoản của file', () {
      const context = TransactionContext.fromImport(
        recordId: 4,
        fileName: 'thang-01.csv',
        accountId: 9,
      );
      expect(context.narrow(TransactionFilter.none).accountId, 9);
    });

    test('bộ lọc tài khoản do người dùng đặt được ưu tiên', () {
      // Chip tài khoản đang hiển thị là của người dùng; ghi đè nó bằng tài khoản
      // suy ra từ ngữ cảnh sẽ làm chip đó nói dối. Hai bên chỏi nhau thì kết quả
      // rỗng — và đó là câu trả lời đúng.
      const context = TransactionContext.fromImport(
        recordId: 4,
        fileName: 'thang-01.csv',
        accountId: 9,
      );
      final narrowed = context.narrow(TransactionFilter(accountId: 3));
      expect(narrowed.accountId, 3);
    });

    test('xoá từng chip ngữ cảnh một, không xoá lây', () {
      const both = TransactionContext(
        importFileRecordId: 4,
        importFileName: 'thang-01.csv',
        importAccountId: 9,
        excludeInternalTransfers: true,
      );
      expect(both.withoutImport().filtersByImport, isFalse);
      expect(both.withoutImport().excludeInternalTransfers, isTrue);
      expect(both.withoutInternalExclusion().filtersByImport, isTrue);
      expect(
        both.withoutInternalExclusion().excludeInternalTransfers,
        isFalse,
      );
    });
  });

  group('Export Dialog nói đúng thứ nó xuất được (UC-11)', () {
    test('chip ngữ cảnh được nêu là **không** đi vào file xuất', () {
      const context = TransactionContext(
        importFileRecordId: 4,
        importFileName: 'thang-01.csv',
        importAccountId: 9,
        excludeInternalTransfers: true,
      );
      final source = ExportTransactionsSource(
        filter: TransactionFilter.none,
        context: context,
        chips: FilterChips.of(
          filter: TransactionFilter.none,
          context: context,
          accountNames: const <int, String>{9: 'Ví thu hộ'},
        ),
      );

      // Hai tiêu chí chỉ lọc được trong bộ nhớ, nên file xuất sẽ rộng hơn thứ
      // đang hiển thị. Giấu đi thì người dùng nhận về một file rộng hơn mà không
      // có gì trong đó nói cho họ biết.
      expect(source.hasUnexportableContext, isTrue);
      expect(source.unexportableContextLines, hasLength(2));
      // Bộ lọc gửi xuống vẫn được thu hẹp bằng những gì tầng dưới hiểu được.
      final request = source.toRequest(ExportFormat.csv) as ExportTransactions;
      expect(request.filter.accountId, 9);
    });

    test('không có chip ngữ cảnh thì không có cảnh báo nào', () {
      const source = ExportTransactionsSource(
        filter: TransactionFilter.none,
        context: TransactionContext.none,
        chips: <FilterChipViewModel>[],
      );
      expect(source.hasUnexportableContext, isFalse);
      expect(source.criteriaLines, <String>['No filter applied.']);
    });
  });
}
