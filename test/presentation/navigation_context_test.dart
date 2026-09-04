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
    test('ngữ cảnh lượt nhập đi thẳng vào bộ tiêu chí gửi xuống', () {
      const context = TransactionContext.fromImport(
        recordId: 4,
        fileName: 'thang-01.csv',
      );
      expect(context.narrow(TransactionFilter.none).importFileRecordId, 4);
    });

    test('ngữ cảnh không ghi đè tiêu chí nào của người dùng', () {
      // Chip tài khoản đang hiển thị là của người dùng. Ngữ cảnh chỉ **thêm**
      // tiêu chí của nó, nên chip không bao giờ nói một đằng còn truy vấn chạy
      // một nẻo.
      const context = TransactionContext.fromImport(
        recordId: 4,
        fileName: 'thang-01.csv',
      );
      final narrowed = context.narrow(TransactionFilter(accountId: 3));
      expect(narrowed.accountId, 3);
      expect(narrowed.importFileRecordId, 4);
    });

    test('công tắc loại trừ của Thống kê đi xuống nguyên vẹn', () {
      const context = TransactionContext.fromStatistics(
        excludeInternalTransfers: true,
      );
      expect(
        context.narrow(TransactionFilter.none).excludeInternalTransfers,
        isTrue,
      );
    });

    test('xoá từng chip ngữ cảnh một, không xoá lây', () {
      const both = TransactionContext(
        importFileRecordId: 4,
        importFileName: 'thang-01.csv',
        excludeInternalTransfers: true,
      );
      expect(both.withoutImport().filtersByImport, isFalse);
      expect(both.withoutImport().excludeInternalTransfers, isTrue);
      expect(both.withoutInternalExclusion().filtersByImport, isTrue);
      expect(both.withoutInternalExclusion().excludeInternalTransfers, isFalse);
    });
  });

  group('Export Dialog xuất đúng thứ đang hiển thị (UC-11)', () {
    test('chip ngữ cảnh đi vào chính bộ tiêu chí của file xuất', () {
      const context = TransactionContext(
        importFileRecordId: 4,
        importFileName: 'thang-01.csv',
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

      // Đây là bất biến của UC-11: file xuất không được rộng hơn danh sách
      // người dùng vừa nhìn, và phần đầu file phải mô tả đúng tập bên dưới nó.
      final request = source.toRequest(ExportFormat.csv) as ExportTransactions;
      expect(request.filter.importFileRecordId, 4);
      expect(request.filter.excludeInternalTransfers, isTrue);
      expect(source.criteriaLines, hasLength(source.chips.length));
    });

    test('không có tiêu chí nào thì phần đầu file nói đúng như vậy', () {
      const source = ExportTransactionsSource(
        filter: TransactionFilter.none,
        context: TransactionContext.none,
        chips: <FilterChipViewModel>[],
      );
      expect(
        source.toRequest(ExportFormat.csv),
        isA<ExportTransactions>().having(
          (request) => request.filter.isEmpty,
          'filter.isEmpty',
          isTrue,
        ),
      );
      expect(source.criteriaLines, <String>['No filter applied.']);
    });
  });
}
