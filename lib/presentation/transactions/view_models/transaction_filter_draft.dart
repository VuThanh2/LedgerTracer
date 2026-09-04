import '../../../domain/errors/transaction_errors.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/amount_range.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/date_range.dart';
import '../../../domain/value_objects/money.dart';
import '../../../domain/value_objects/search_text.dart';
import '../../shared/formatting/number_formatter.dart';

/// Nội dung Filter Panel **đang được sửa**, trước khi nó trở thành một
/// `TransactionFilter` (UC-07).
///
/// Tồn tại vì hai hình dạng khác nhau của cùng một khái niệm. `TransactionFilter`
/// là bộ tiêu chí **đã hợp lệ**: hai cận số tiền là `Money`, khoảng ngày đã đúng
/// thứ tự, loại tiền đã thống nhất — nó từ chối được dựng từ dữ liệu sai, và đó
/// chính là giá trị của nó. Còn một biểu mẫu đang gõ dở thì *bản chất* là chưa
/// hợp lệ: ô "từ" có chữ mà ô "đến" chưa, số tiền mới gõ được một dấu trừ. Nhét
/// trạng thái ấy vào `TransactionFilter` nghĩa là hoặc nới lỏng bất biến của nó,
/// hoặc bắt giao diện bọc mọi phím gõ trong `try`.
///
/// Vì vậy hai cận số tiền ở đây là **chuỗi**, đúng thứ người dùng gõ, và
/// [validate] là ranh giới duy nhất giữa hai thế giới.
final class TransactionFilterDraft {
  const TransactionFilterDraft({
    this.accountId,
    this.dateFrom,
    this.dateTo,
    this.minAmountText = '',
    this.maxAmountText = '',
    this.currency,
    this.filterByCurrency = false,
  });

  static const TransactionFilterDraft empty = TransactionFilterDraft();

  final int? accountId;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  /// Cận dưới **đúng như người dùng gõ**, kể cả khi chưa đọc được thành số.
  final String minAmountText;

  final String maxAmountText;

  /// Loại tiền đang chọn trong ô loại tiền.
  ///
  /// **Có giá trị không có nghĩa là đang lọc theo loại tiền.** Ô này được điền
  /// sẵn loại tiền phổ biến nhất ngay khi mở màn hình, vì nó là *tiền đề* của bộ
  /// lọc số tiền — một khoảng số tiền không có loại tiền là so sánh hai con số
  /// khác đơn vị, và sẽ âm thầm loại mất giao dịch 1.000 USD khỏi khoảng "1 đến
  /// 5 triệu" (UC-07). Coi giá trị điền sẵn ấy là một tiêu chí nghĩa là màn hình
  /// vừa mở ra đã tự thu hẹp dữ liệu, kèm một chip mà người dùng không hề bật.
  ///
  /// Tiêu chí thật sự do [filterByCurrency] quyết định.
  final Currency? currency;

  /// Người dùng đã bật lọc theo loại tiền như một tiêu chí độc lập.
  ///
  /// Bộ lọc số tiền tự kéo theo tiêu chí loại tiền mà không cần cờ này, vì
  /// `TransactionFilter` suy ra loại tiền từ chính khoảng số tiền — đó là chỗ
  /// UC-07 nói "bật bộ lọc số tiền thì tự động bật kèm tiêu chí loại tiền".
  final bool filterByCurrency;

  bool get hasAmountCriteria =>
      minAmountText.trim().isNotEmpty || maxAmountText.trim().isNotEmpty;

  bool get isEmpty =>
      accountId == null &&
      dateFrom == null &&
      dateTo == null &&
      !hasAmountCriteria &&
      !filterByCurrency;

  /// `null` cho một trường nghĩa là "giữ nguyên"; để xoá một tiêu chí thì dùng
  /// các cờ `clear*`. Không có cách nào khác phân biệt "không đụng tới" với "đặt
  /// về rỗng" khi mọi trường đều nullable.
  TransactionFilterDraft copyWith({
    int? accountId,
    bool clearAccount = false,
    DateTime? dateFrom,
    DateTime? dateTo,
    bool clearDateRange = false,
    String? minAmountText,
    String? maxAmountText,
    Currency? currency,
    bool? filterByCurrency,
    bool clearAmount = false,
  }) => TransactionFilterDraft(
    accountId: clearAccount ? null : (accountId ?? this.accountId),
    dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
    dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
    minAmountText: clearAmount ? '' : (minAmountText ?? this.minAmountText),
    maxAmountText: clearAmount ? '' : (maxAmountText ?? this.maxAmountText),
    // Xoá khoảng số tiền **không** xoá loại tiền đang chọn: nó là giá trị của ô
    // loại tiền, và bỏ trống ô đó sẽ chặn lần gõ số tiền kế tiếp.
    currency: currency ?? this.currency,
    filterByCurrency: filterByCurrency ?? this.filterByCurrency,
  );

  /// Đổi bản nháp thành bộ tiêu chí, hoặc nói rõ ô nào sai.
  ///
  /// Lỗi được gắn với **từng ô** chứ không gộp thành một câu: `ValidationFailure`
  /// đi lên từ tầng dưới chỉ nói "dữ liệu không hợp lệ", còn người đang gõ cần
  /// biết ô nào. Đó là lý do phép kiểm nằm ở đây thay vì để `TransactionFilter`
  /// ném rồi bắt lại.
  TransactionFilterValidation validate({SearchText? keyword}) {
    String? dateError;
    DateRange? dateRange;
    final from = dateFrom;
    final to = dateTo;
    if (from != null && to != null) {
      if (DateRange.dateOnly(from).isAfter(DateRange.dateOnly(to))) {
        dateError = 'Ngày bắt đầu phải trước hoặc bằng ngày kết thúc.';
      } else {
        dateRange = DateRange(from: from, to: to);
      }
    } else if (from != null) {
      // Một đầu để trống nghĩa là "đúng ngày này": khoảng luôn có hai đầu, và
      // một khoảng mở tới vô hạn là thứ `DateRange` cố ý không có.
      dateRange = DateRange.singleDay(from);
    } else if (to != null) {
      dateRange = DateRange.singleDay(to);
    }

    String? currencyError;
    if ((hasAmountCriteria || filterByCurrency) && currency == null) {
      currencyError = 'Chọn loại tiền.';
    }

    final min = _parseAmount(minAmountText);
    final max = _parseAmount(maxAmountText);

    AmountRange? amountRange;
    String? rangeError;
    if (currencyError == null &&
        hasAmountCriteria &&
        min.error == null &&
        max.error == null) {
      amountRange = _buildRange(min.value, max.value);
      if (amountRange == null) {
        rangeError =
            'Số tiền nhỏ nhất phải nhỏ hơn hoặc bằng số tiền lớn nhất.';
      }
    }

    final hasError =
        dateError != null ||
        currencyError != null ||
        rangeError != null ||
        min.error != null ||
        max.error != null;

    return TransactionFilterValidation(
      filter: hasError
          ? null
          : TransactionFilter(
              keyword: keyword,
              accountId: accountId,
              dateRange: dateRange,
              amountRange: amountRange,
              // Loại tiền là tiêu chí riêng chỉ khi người dùng bật nó — xem
              // riêng các giao dịch USD là một nhu cầu độc lập. Có khoảng số
              // tiền rồi thì `TransactionFilter` tự suy ra, truyền thêm chỉ là
              // một cơ hội để hai bên lệch nhau.
              currency: amountRange == null && filterByCurrency
                  ? currency
                  : null,
            ),
      minAmountError: min.error,
      maxAmountError: max.error,
      amountRangeError: rangeError,
      currencyError: currencyError,
      dateRangeError: dateError,
    );
  }

  AmountRange? _buildRange(Money? min, Money? max) {
    try {
      if (min != null && max != null) return AmountRange(min: min, max: max);
      if (min != null) return AmountRange.atLeast(min);
      if (max != null) return AmountRange.atMost(max);
      return null;
    } on InvalidAmountRangeError {
      return null;
    }
  }

  _ParsedAmount _parseAmount(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const _ParsedAmount(null, null);
    final selected = currency;
    // Không có loại tiền thì không đọc được số tiền; lỗi đã báo ở ô loại tiền,
    // báo thêm ở đây chỉ là tiếng ồn.
    if (selected == null) return const _ParsedAmount(null, null);

    final decimal = NumberFormatter.toDecimalInput(trimmed);
    if (decimal == null) return const _ParsedAmount(null, 'Không phải một số.');
    try {
      return _ParsedAmount(Money.fromDecimalString(decimal, selected), null);
    } on AmountPrecisionError {
      return _ParsedAmount(
        null,
        '${selected.code} không có tới từng ấy chữ số thập phân.',
      );
    } on MalformedAmountError {
      return const _ParsedAmount(null, 'Không phải một số.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilterDraft &&
      other.accountId == accountId &&
      other.dateFrom == dateFrom &&
      other.dateTo == dateTo &&
      other.minAmountText == minAmountText &&
      other.maxAmountText == maxAmountText &&
      other.currency == currency &&
      other.filterByCurrency == filterByCurrency;

  @override
  int get hashCode => Object.hash(
    accountId,
    dateFrom,
    dateTo,
    minAmountText,
    maxAmountText,
    currency,
    filterByCurrency,
  );
}

/// Kết quả kiểm một bản nháp: hoặc bộ tiêu chí, hoặc lỗi của từng ô.
final class TransactionFilterValidation {
  const TransactionFilterValidation({
    required this.filter,
    this.minAmountError,
    this.maxAmountError,
    this.amountRangeError,
    this.currencyError,
    this.dateRangeError,
  });

  /// `null` khi còn ô sai.
  final TransactionFilter? filter;

  final String? minAmountError;
  final String? maxAmountError;
  final String? amountRangeError;
  final String? currencyError;
  final String? dateRangeError;

  bool get isValid => filter != null;
}

final class _ParsedAmount {
  const _ParsedAmount(this.value, this.error);

  final Money? value;
  final String? error;
}
