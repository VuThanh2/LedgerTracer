import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_filter_draft.dart';

/// Filter Panel là chỗ duy nhất người dùng gõ tay ra một bộ tiêu chí, nên nó là
/// chỗ duy nhất dữ liệu sai có thể vào được — và phép kiểm ở đây phải nói được
/// **ô nào** sai, thứ mà một `ValidationFailure` đi lên từ tầng dưới không nói
/// được.
void main() {
  group('loại tiền', () {
    test(
      'ô loại tiền có giá trị sẵn **không** phải là một tiêu chí',
      () {
        // Loại tiền phổ biến nhất được điền sẵn ngay khi mở màn hình, vì nó là
        // tiền đề của bộ lọc số tiền. Coi nó là tiêu chí nghĩa là màn hình vừa
        // mở đã tự thu hẹp dữ liệu kèm một chip người dùng không hề bật.
        final result = const TransactionFilterDraft(
          currency: Currency.vnd,
        ).validate();

        expect(result.isValid, isTrue);
        expect(result.filter!.currency, isNull);
        expect(result.filter!.isEmpty, isTrue);
      },
    );

    test('bật tường minh thì loại tiền trở thành tiêu chí', () {
      final result = const TransactionFilterDraft(
        currency: Currency.usd,
        filterByCurrency: true,
      ).validate();

      expect(result.filter!.currency, Currency.usd);
    });

    test('bộ lọc số tiền tự kéo theo tiêu chí loại tiền', () {
      // UC-07: "bật bộ lọc số tiền thì tự động bật kèm tiêu chí loại tiền" —
      // `TransactionFilter` suy ra nó từ chính khoảng số tiền.
      final result = const TransactionFilterDraft(
        minAmountText: '1.000.000',
        currency: Currency.vnd,
      ).validate();

      expect(result.filter!.currency, Currency.vnd);
      expect(result.filter!.amountRange!.currency, Currency.vnd);
    });

    test('gõ số tiền mà chưa có loại tiền thì báo ở đúng ô loại tiền', () {
      final result = const TransactionFilterDraft(
        minAmountText: '1.000.000',
      ).validate();

      expect(result.isValid, isFalse);
      expect(result.currencyError, isNotNull);
      // Không báo trùng ở ô số tiền: nó không sai, nó chỉ chưa đọc được.
      expect(result.minAmountError, isNull);
    });
  });

  group('khoảng số tiền', () {
    test('một đầu để trống là khoảng mở đúng chiều', () {
      final atLeast = const TransactionFilterDraft(
        minAmountText: '1.000.000',
        currency: Currency.vnd,
      ).validate();
      expect(atLeast.filter!.amountRange!.min, Money(1000000, Currency.vnd));

      final atMost = const TransactionFilterDraft(
        maxAmountText: '5.000.000',
        currency: Currency.vnd,
      ).validate();
      expect(atMost.filter!.amountRange!.max, Money(5000000, Currency.vnd));
    });

    test('hai cận ngược thứ tự thì báo lỗi và không dựng bộ lọc', () {
      final result = const TransactionFilterDraft(
        minAmountText: '5.000.000',
        maxAmountText: '1.000.000',
        currency: Currency.vnd,
      ).validate();

      expect(result.isValid, isFalse);
      expect(result.amountRangeError, isNotNull);
    });

    test('cận âm là hợp lệ — dấu chính là chiều tiền', () {
      final result = const TransactionFilterDraft(
        minAmountText: '-5.000.000',
        maxAmountText: '-1.000.000',
        currency: Currency.vnd,
      ).validate();

      expect(result.isValid, isTrue);
      expect(result.filter!.amountRange!.min, Money(-5000000, Currency.vnd));
    });

    test('quá số chữ số thập phân của loại tiền thì báo ở đúng ô', () {
      final result = const TransactionFilterDraft(
        minAmountText: '1000,5',
        currency: Currency.vnd,
      ).validate();

      expect(result.isValid, isFalse);
      expect(result.minAmountError, contains('VND'));
    });

    test('chuỗi không phải số thì báo ở đúng ô', () {
      final result = const TransactionFilterDraft(
        maxAmountText: 'một triệu',
        currency: Currency.vnd,
      ).validate();

      expect(result.isValid, isFalse);
      expect(result.maxAmountError, isNotNull);
      expect(result.minAmountError, isNull);
    });
  });

  group('khoảng ngày', () {
    test('ngày bắt đầu sau ngày kết thúc thì báo lỗi', () {
      final result = TransactionFilterDraft(
        dateFrom: DateTime.utc(2025, 5, 10),
        dateTo: DateTime.utc(2025, 5, 1),
      ).validate();

      expect(result.isValid, isFalse);
      expect(result.dateRangeError, isNotNull);
    });

    test('chỉ một đầu thì thu về đúng một ngày', () {
      final result = TransactionFilterDraft(
        dateFrom: DateTime.utc(2025, 5, 10),
      ).validate();

      expect(result.filter!.dateRange!.lengthInDays, 1);
    });
  });

  group('từ khoá', () {
    test('từ khoá rỗng không phải một tiêu chí', () {
      final result = const TransactionFilterDraft().validate(
        keyword: SearchText.query('   '),
      );
      expect(result.filter!.keyword, isNull);
      expect(result.filter!.isEmpty, isTrue);
    });

    test('từ khoá đi cùng các tiêu chí khác', () {
      final result = const TransactionFilterDraft(accountId: 7).validate(
        keyword: SearchText.query('Nguyễn'),
      );
      expect(result.filter!.keyword, isNotNull);
      expect(result.filter!.accountId, 7);
    });
  });

  group('copyWith', () {
    test('xoá khoảng số tiền nhưng giữ loại tiền đang chọn', () {
      // Bỏ trống ô loại tiền sau khi xoá khoảng số tiền sẽ chặn ngay lần gõ số
      // tiền kế tiếp.
      const draft = TransactionFilterDraft(
        minAmountText: '1.000',
        currency: Currency.usd,
        filterByCurrency: true,
      );
      final cleared = draft.copyWith(clearAmount: true);

      expect(cleared.minAmountText, isEmpty);
      expect(cleared.currency, Currency.usd);
    });

    test('phân biệt "giữ nguyên" với "xoá"', () {
      const draft = TransactionFilterDraft(accountId: 3);
      expect(draft.copyWith().accountId, 3);
      expect(draft.copyWith(clearAccount: true).accountId, isNull);
    });
  });
}
