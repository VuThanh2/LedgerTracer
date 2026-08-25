import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/errors/transaction_errors.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/amount_range.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/date_range.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';

/// Bộ lọc gom mọi tiêu chí vào một object để danh sách, phép đếm và file xuất
/// chạy **cùng một** điều kiện thay vì ba bản chép tay lệch nhau. `matches` là
/// bản đặc tả đọc được của điều kiện ấy.
void main() {
  Transaction tx({
    int id = 1,
    int accountId = 1,
    DateTime? bookingDate,
    int minorUnits = -500000,
    Currency currency = Currency.vnd,
    String? counterpartyName = 'Nguyễn Văn A',
    String description = 'CK tien hang',
  }) => Transaction.imported(
    accountId: accountId,
    bookingDate: bookingDate ?? DateTime.utc(2025, 6, 15),
    amount: Money(minorUnits, currency),
    counterpartyName: counterpartyName,
    description: description,
    importFileRecordId: 1,
    importedAt: DateTime.utc(2025, 7, 1),
  ).withIdentity(id);

  group('bộ lọc rỗng', () {
    test('nhận mọi giao dịch', () {
      expect(TransactionFilter.none.isEmpty, isTrue);
      expect(TransactionFilter.none.matches(tx()), isTrue);
    });

    test('từ khoá rỗng không được coi là một tiêu chí', () {
      // Ô tìm kiếm trống không được biến thành điều kiện lọc.
      final filter = TransactionFilter(keyword: SearchText.query('  '));
      expect(filter.keyword, isNull);
      expect(filter.isEmpty, isTrue);
    });
  });

  group('từng tiêu chí', () {
    test('lọc theo từ khoá, không phân biệt hoa/thường và dấu', () {
      final filter = TransactionFilter(keyword: SearchText.query('NGUYỄN'));
      expect(filter.matches(tx()), isTrue);
      expect(filter.matches(tx(counterpartyName: 'Trần B')), isFalse);
    });

    test('từ khoá cũng tìm trong nội dung chuyển khoản', () {
      final filter = TransactionFilter(keyword: SearchText.query('tien hang'));
      expect(filter.matches(tx()), isTrue);
    });

    test('lọc theo tài khoản', () {
      final filter = TransactionFilter(accountId: 2);
      expect(filter.matches(tx(accountId: 2)), isTrue);
      expect(filter.matches(tx(accountId: 3)), isFalse);
    });

    test('lọc theo khoảng ngày, bao gồm hai đầu mút', () {
      final filter = TransactionFilter(
        dateRange: DateRange(
          from: DateTime.utc(2025, 6, 1),
          to: DateTime.utc(2025, 6, 30),
        ),
      );
      expect(filter.matches(tx(bookingDate: DateTime.utc(2025, 6, 1))), isTrue);
      expect(filter.matches(tx(bookingDate: DateTime.utc(2025, 6, 30))), isTrue);
      expect(filter.matches(tx(bookingDate: DateTime.utc(2025, 5, 31))), isFalse);
      expect(filter.matches(tx(bookingDate: DateTime.utc(2025, 7, 1))), isFalse);
    });

    test('lọc theo khoảng số tiền, tính cả dấu', () {
      final filter = TransactionFilter(
        amountRange: AmountRange(
          min: const Money(-1000000, Currency.vnd),
          max: const Money(-100000, Currency.vnd),
        ),
      );
      expect(filter.matches(tx(minorUnits: -500000)), isTrue);
      expect(filter.matches(tx(minorUnits: 500000)), isFalse);
    });

    test('lọc theo loại tiền', () {
      final filter = TransactionFilter(currency: Currency.usd);
      expect(filter.matches(tx(currency: Currency.usd, minorUnits: -100)), isTrue);
      expect(filter.matches(tx(currency: Currency.vnd)), isFalse);
    });
  });

  group('kết hợp tiêu chí', () {
    final filter = TransactionFilter(
      keyword: SearchText.query('nguyen'),
      accountId: 1,
      dateRange: DateRange(
        from: DateTime.utc(2025, 6, 1),
        to: DateTime.utc(2025, 6, 30),
      ),
    );

    test('phải thoả mãn tất cả tiêu chí đang bật', () {
      expect(filter.matches(tx()), isTrue);
    });

    test('trượt một tiêu chí là trượt cả bộ lọc', () {
      expect(filter.matches(tx(accountId: 2)), isFalse);
      expect(filter.matches(tx(counterpartyName: 'Trần B')), isFalse);
      expect(filter.matches(tx(bookingDate: DateTime.utc(2025, 7, 5))), isFalse);
    });
  });

  group('ràng buộc loại tiền của bộ lọc số tiền', () {
    test('khoảng số tiền tự mang loại tiền của nó vào bộ lọc', () {
      // So sánh hai con số khác đơn vị là phép toán vô nghĩa, nên một bộ lọc số
      // tiền luôn kèm loại tiền.
      final filter = TransactionFilter(
        amountRange: AmountRange(
          min: const Money(0, Currency.usd),
          max: const Money(10000, Currency.usd),
        ),
      );
      expect(filter.currency, Currency.usd);
    });

    test('khoảng USD không vơ nhầm giao dịch VND cùng con số', () {
      final filter = TransactionFilter(
        amountRange: AmountRange(
          min: const Money(100000, Currency.usd),
          max: const Money(500000, Currency.usd),
        ),
      );
      expect(
        filter.matches(tx(minorUnits: 200000, currency: Currency.vnd)),
        isFalse,
      );
      expect(
        filter.matches(tx(minorUnits: 200000, currency: Currency.usd)),
        isTrue,
      );
    });

    test('loại tiền khai báo trùng với loại tiền của khoảng thì chấp nhận', () {
      final filter = TransactionFilter(
        amountRange: AmountRange(
          min: const Money(0, Currency.usd),
          max: const Money(1, Currency.usd),
        ),
        currency: Currency.usd,
      );
      expect(filter.currency, Currency.usd);
    });

    test('khai báo hai loại tiền mâu thuẫn nhau bị chặn ngay khi dựng', () {
      expect(
        () => TransactionFilter(
          amountRange: AmountRange(
            min: const Money(0, Currency.usd),
            max: const Money(1, Currency.usd),
          ),
          currency: Currency.vnd,
        ),
        throwsA(isA<CurrencyMismatchError>()),
      );
    });
  });

  group('CashFlowBucket', () {
    test('ròng là tổng của tiền vào và tiền ra đã mang dấu', () {
      final bucket = PeriodCashFlow(
        periodStart: DateTime.utc(2025, 6),
        inflow: const Money(1000000, Currency.vnd),
        outflow: const Money(-400000, Currency.vnd),
      );
      expect(bucket.net, const Money(600000, Currency.vnd));
    });

    test('kiểu tổng đóng nên mỗi cột chỉ mang đúng nhãn của nó', () {
      // Không còn trường nullable nào để phải `!` khi dựng bảng xuất.
      final CashFlowBucket byPeriod = PeriodCashFlow(
        periodStart: DateTime.utc(2025, 6),
        inflow: const Money(0, Currency.vnd),
        outflow: const Money(0, Currency.vnd),
      );
      const CashFlowBucket byAccount = AccountCashFlow(
        accountId: 3,
        inflow: Money(0, Currency.vnd),
        outflow: Money(0, Currency.vnd),
      );
      final labels = <CashFlowBucket>[byPeriod, byAccount]
          .map(
            (bucket) => switch (bucket) {
              PeriodCashFlow(:final periodStart) => periodStart.month.toString(),
              AccountCashFlow(:final accountId) => 'tk$accountId',
            },
          )
          .toList();
      expect(labels, <String>['6', 'tk3']);
    });
  });
}
