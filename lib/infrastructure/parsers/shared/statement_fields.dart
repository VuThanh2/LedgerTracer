import '../../../domain/errors/domain_error.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/money.dart';
import '../../../domain/value_objects/search_text.dart';

/// Vai trò nghiệp vụ của một cột trong sao kê dạng bảng.
///
/// Sao kê không có lược đồ chuẩn: mỗi ngân hàng đặt tên cột một kiểu, và cùng
/// một thông tin có khi nằm ở một cột có dấu, có khi nằm ở hai cột ghi nợ / ghi
/// có. Enum này là cách nói "cột thứ 3 của file đóng vai trò gì" mà không để
/// tên cột cụ thể rò rỉ vào phần đọc dữ liệu.
enum StatementColumn {
  /// Ngày ghi nhận.
  date,

  /// Số tiền **có dấu**, khi nguồn dùng một cột duy nhất.
  amount,

  /// Tiền ra, khi nguồn tách hai cột.
  debit,

  /// Tiền vào, khi nguồn tách hai cột.
  credit,

  currency,
  counterparty,
  description,
}

/// Cột nào của file đóng vai trò nào.
///
/// Được suy ra từ dòng tiêu đề (hoặc từ khoá của một object JSON) đúng **một
/// lần cho cả file**, rồi dùng lại cho từng dòng: dò tên cột trên mỗi dòng là
/// trả cùng một chi phí hàng trăm nghìn lần cho một câu trả lời không đổi.
final class ColumnLayout {
  const ColumnLayout._(this._indexes);

  /// Dò vai trò của từng ô trong dòng tiêu đề.
  ///
  /// Tên cột được chuẩn hoá bằng **chính** `SearchText.normalize` — thuật toán
  /// chuẩn hoá duy nhất của hệ thống — nên `"Ngày GD"`, `"NGAY GD"` và
  /// `"ngay  gd"` là cùng một tên, và một bảng bí danh viết không dấu là đủ để
  /// nhận ra cả ba.
  factory ColumnLayout.fromHeader(List<String?> header) {
    final indexes = <StatementColumn, int>{};
    for (var index = 0; index < header.length; index++) {
      final name = SearchText.normalize(header[index] ?? '');
      if (name.isEmpty) continue;
      final column = _columnFor(name);
      // Cột đầu tiên mang một vai trò là cột giữ vai trò đó: sao kê hay có thêm
      // các cột phái sinh ("số dư sau giao dịch") mà tên gần giống, và lấy cột
      // sau sẽ âm thầm đọc nhầm cả file.
      if (column != null) indexes.putIfAbsent(column, () => index);
    }
    return ColumnLayout._(Map<StatementColumn, int>.unmodifiable(indexes));
  }

  final Map<StatementColumn, int> _indexes;

  bool has(StatementColumn column) => _indexes.containsKey(column);

  /// Giá trị của một cột trong [cells], hoặc `null` khi file không có cột đó
  /// hoặc ô trống.
  String? read(List<String?> cells, StatementColumn column) {
    final index = _indexes[column];
    if (index == null || index >= cells.length) return null;
    final value = cells[index]?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  /// Bố cục có đủ để đọc dữ liệu hay không: phải có ngày, và phải có ít nhất một
  /// đường để biết số tiền.
  ///
  /// Thiếu một trong hai thì đây không phải sao kê giao dịch, và cả **file**
  /// hỏng chứ không phải từng dòng hỏng — đó là ranh giới giữa `ParsingFailure`
  /// và dòng lỗi (UC-02).
  bool get isUsable =>
      has(StatementColumn.date) &&
      (has(StatementColumn.amount) ||
          has(StatementColumn.debit) ||
          has(StatementColumn.credit));

  /// Bí danh của từng vai trò, viết ở dạng đã chuẩn hoá (thường, không dấu).
  ///
  /// Bảng cố ý dài: người dùng chỉ chọn file mình đang có và không bao giờ phải
  /// khai báo cột nào là cột nào (UC-02 bước 2), nên mỗi tên gọi mà một ngân
  /// hàng thật sự dùng đều phải nằm ở đây.
  static const Map<StatementColumn, List<String>> _aliases =
      <StatementColumn, List<String>>{
        StatementColumn.date: <String>[
          'ngay',
          'ngay gd',
          'ngay giao dich',
          'ngay hach toan',
          'ngay ghi so',
          'ngay hieu luc',
          'date',
          'trans date',
          'transaction date',
          'booking date',
          'value date',
          'posting date',
        ],
        StatementColumn.amount: <String>[
          'so tien',
          'so tien gd',
          'gia tri',
          'gia tri gd',
          'amount',
          'transaction amount',
          'value',
        ],
        StatementColumn.debit: <String>[
          'ghi no',
          'no',
          'phat sinh no',
          'tien ra',
          'so tien ghi no',
          'rut ra',
          'debit',
          'debit amount',
          'withdrawal',
          'money out',
        ],
        StatementColumn.credit: <String>[
          'ghi co',
          'co',
          'phat sinh co',
          'tien vao',
          'so tien ghi co',
          'nop vao',
          'credit',
          'credit amount',
          'deposit',
          'money in',
        ],
        StatementColumn.currency: <String>[
          'loai tien',
          'don vi tien te',
          'tien te',
          'currency',
          'ccy',
          'cur',
        ],
        StatementColumn.counterparty: <String>[
          'doi tac',
          'ten doi tac',
          'nguoi chuyen',
          'nguoi gui',
          'nguoi nhan',
          'ten nguoi chuyen',
          'ten nguoi nhan',
          'tai khoan doi ung',
          'counterparty',
          'payee',
          'payer',
          'remitter',
          'beneficiary',
          'name',
        ],
        StatementColumn.description: <String>[
          'noi dung',
          'noi dung chuyen khoan',
          'noi dung giao dich',
          'dien giai',
          'mo ta',
          'ghi chu',
          'description',
          'details',
          'detail',
          'narrative',
          'remark',
          'remarks',
          'memo',
          'reference',
        ],
      };

  static final Map<String, StatementColumn> _byAlias = <String, StatementColumn>{
    for (final entry in _aliases.entries)
      for (final alias in entry.value) alias: entry.key,
  };

  static StatementColumn? _columnFor(String normalizedName) {
    final exact = _byAlias[normalizedName];
    if (exact != null) return exact;
    // Khớp gần đúng cho các biến thể có thêm chữ ("ngay giao dich (dd/mm/yyyy)",
    // "so tien (vnd)"). Chỉ chạy khi khớp đúng đã trượt, và duyệt theo thứ tự
    // khai báo để kết quả lặp lại được giữa các lần chạy.
    for (final entry in _aliases.entries) {
      for (final alias in entry.value) {
        // Bí danh quá ngắn không được khớp theo tiền tố. `co` và `no` là bí danh
        // thật của hai cột ghi có / ghi nợ, nhưng cho chúng khớp tiền tố thì một
        // cột tên `co quan` sẽ bị đọc thành cột tiền vào — và dòng tiền của cả
        // file đảo chiều mà không có lỗi nào báo.
        if (alias.length < _minPrefixAliasLength) continue;
        if (normalizedName.startsWith('$alias ')) return entry.key;
      }
    }
    return null;
  }

  static const int _minPrefixAliasLength = 4;
}

/// Một ô sao kê không đọc được thành giá trị của Domain.
///
/// Là exception nội bộ của tầng parser chứ không phải `DomainError`: nó sống
/// đúng một lời gọi, ngay lập tức được đổi thành `ParseError` — tức thành **dữ
/// liệu** — để một dòng hỏng không làm dừng các dòng còn lại (UC-02).
final class StatementFieldException implements Exception {
  const StatementFieldException(this.reason);

  final String reason;

  @override
  String toString() => 'StatementFieldException: $reason';
}

/// Đổi các ô văn bản thô của sao kê thành giá trị của Domain.
///
/// Mọi định dạng dùng chung phần này: bốn parser khác nhau nhưng "1.000.000",
/// "1,000,000" và "(1.000)" phải cho ra cùng một con số ở cả bốn, nếu không thì
/// chống trùng giữa hai file khác định dạng của cùng một tài khoản sẽ trượt.
abstract final class StatementFields {
  /// Đọc ngày ghi nhận từ ô văn bản.
  ///
  /// Nhận các dạng thường gặp trong sao kê ngân hàng Việt Nam và quốc tế. Khi
  /// chuỗi mơ hồ (`03/04/2025`) thì hiểu là **ngày trước, tháng sau** — quy ước
  /// của sao kê Việt Nam; chỉ khi cách đọc đó không hợp lệ (`13/04/2025` đọc
  /// theo kiểu Mỹ) mới thử cách còn lại. Đoán mò kiểu khác sẽ dịch chuyển giao
  /// dịch sang tháng khác và làm sai cả thống kê lẫn cửa sổ ghép cặp.
  ///
  /// Ném [StatementFieldException] khi không đọc được.
  static DateTime parseDate(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) {
      throw const StatementFieldException('The transaction date is missing.');
    }

    final match = _datePattern.firstMatch(value);
    if (match == null) {
      throw StatementFieldException('Could not read the date "$value".');
    }

    final first = int.parse(match.group(1)!);
    final second = int.parse(match.group(2)!);
    final third = int.parse(match.group(3)!);

    // Năm đứng đầu là dạng ISO, không có gì để đoán.
    if (match.group(1)!.length == 4) {
      return _buildDate(year: first, month: second, day: third, raw: value);
    }
    final year = _expandYear(third);
    // Ngày trước, tháng sau; đảo lại chỉ khi cách đọc đó bất khả thi.
    if (second > 12 && first <= 12) {
      return _buildDate(year: year, month: first, day: second, raw: value);
    }
    return _buildDate(year: year, month: second, day: first, raw: value);
  }

  /// Đọc mã loại tiền, hoặc trả về VND khi nguồn không nêu (UC-02).
  ///
  /// Chuỗi có ký tự lạ cũng về VND thay vì thành dòng lỗi: cột loại tiền trống
  /// là chuyện bình thường ở sao kê nội địa, và từ chối cả dòng vì nó là phản
  /// ứng nặng tay hơn hẳn mức vấn đề.
  static Currency parseCurrency(String? raw) =>
      Currency.tryParse(raw) ?? Currency.fallback;

  /// Đổi một ô số tiền thành [Money].
  ///
  /// Chuỗi được đưa về dạng chính tắc rồi mới giao cho
  /// `Money.fromDecimalString`, nơi giữ luật về độ chính xác: nhiều chữ số thập
  /// phân hơn mức loại tiền cho phép thì thành **dòng lỗi**, không bao giờ bị
  /// làm tròn âm thầm (Rule – Money Is a Signed Integer, Never a Floating-Point
  /// Number).
  ///
  /// [negative] là chiều mà **cấu trúc file** áp đặt — cột "ghi nợ" luôn là tiền
  /// ra dù ô của nó không mang dấu trừ.
  static Money parseAmount(
    String? raw,
    Currency currency, {
    bool negative = false,
  }) {
    final canonical = _canonicalDecimal(raw);
    try {
      final magnitude = Money.fromDecimalString(canonical, currency);
      return negative && !magnitude.isOutgoing ? -magnitude : magnitude;
    } on DomainError catch (error) {
      throw StatementFieldException(error.message);
    }
  }

  /// Đổi một số tiền **đã ở dạng chính tắc** (`[-]digits[.digits]`) thành
  /// [Money].
  ///
  /// Dành cho định dạng có ngữ pháp chặt chẽ như MT940, nơi dấu phẩy luôn là dấu
  /// thập phân và không bao giờ có dấu phân nhóm. Chạy phép đoán của
  /// [parseAmount] lên một chuỗi vốn đã không mơ hồ chỉ tạo ra một cách hiểu
  /// sai: `100,000` trong MT940 là một trăm phẩy không, còn phép đoán dành cho
  /// CSV sẽ đọc nó thành một trăm nghìn.
  static Money parseExactAmount(
    String decimal,
    Currency currency, {
    bool negative = false,
  }) {
    try {
      final magnitude = Money.fromDecimalString(decimal, currency);
      return negative && !magnitude.isOutgoing ? -magnitude : magnitude;
    } on DomainError catch (error) {
      throw StatementFieldException(error.message);
    }
  }

  /// Dò số tài khoản mà chính file khai báo ở phần đầu, hoặc `null`.
  ///
  /// Nhiều sao kê CSV/Excel đặt một khối thông tin trước bảng dữ liệu
  /// (`Số tài khoản: 0011 0004 1234`). Đọc được nó là điều kiện để cảnh báo gán
  /// nhầm tài khoản đích có ý nghĩa ở các định dạng ngoài MT940 (UC-02 bước 4).
  ///
  /// Cố ý bảo thủ — chỉ nhận khi có nhãn rõ ràng và một chuỗi đủ dài đứng ngay
  /// sau: một số nhận nhầm còn tệ hơn không nhận, vì nó biến mọi lần nhập sau đó
  /// thành một cảnh báo sai mà người dùng không có cách nào gỡ ngoài việc sửa
  /// tay ở UC-01.
  static String? findAccountNumber(String head) {
    for (final line in head.split('\n')) {
      final normalized = SearchText.normalize(line);
      for (final label in _accountNumberLabels) {
        final at = normalized.indexOf(label);
        if (at < 0) continue;
        final match = _accountNumberPattern.firstMatch(
          normalized.substring(at + label.length),
        );
        final candidate = match?.group(0)?.trim();
        // Đủ dài mới nhận. Một chuỗi hai ba ký tự sau nhãn thường là phần còn
        // lại của câu chữ, không phải số tài khoản.
        if (candidate != null &&
            candidate.replaceAll(_nonAlphanumeric, '').length >=
                _minAccountNumberLength) {
          return candidate;
        }
      }
    }
    return null;
  }

  static const List<String> _accountNumberLabels = <String>[
    'so tai khoan',
    'so tk',
    'account number',
    'account no',
    'so hieu tai khoan',
  ];

  static const int _minAccountNumberLength = 6;

  /// Các nhóm ký tự chữ/số, mỗi nhóm **phải chứa ít nhất một chữ số**, nối nhau
  /// bằng đúng một dấu cách, gạch nối hoặc dấu chấm.
  ///
  /// Điều kiện "mỗi nhóm phải có chữ số" là thứ chặn mẫu này lan sang phần văn
  /// xuôi đứng sau: với `so tai khoan: 001100041234 tai vietinbank`, một mẫu chỉ
  /// nhận "chữ, số và dấu cách" sẽ nuốt trọn cả `tai vietinbank`, và số tài
  /// khoản học được sẽ thành `001100041234TAIVIETINBANK` — sai vĩnh viễn, vì từ
  /// đó mọi lần nhập sau đều báo lệch số tài khoản (UC-02 bước 4).
  static final RegExp _accountNumberPattern = RegExp(
    r'[0-9a-z]*[0-9][0-9a-z]*(?:[ .\-][0-9a-z]*[0-9][0-9a-z]*)*',
  );

  static final RegExp _nonAlphanumeric = RegExp('[^0-9a-z]');

  /// Nội dung chuyển khoản; ô trống là chuỗi rỗng chứ không phải lỗi.
  ///
  /// Một giao dịch không có diễn giải vẫn là một giao dịch thật, và nội dung
  /// rỗng vẫn dựng được fingerprint — ngày, số tiền và tài khoản đã đủ để hai
  /// dòng khác nhau khác nhau.
  static String parseDescription(String? raw) => raw?.trim() ?? '';

  /// Đưa ô số tiền về dạng `[-]digits[.digits]` mà `Money` đọc được.
  ///
  /// Ba việc phải làm, và cả ba đều đến từ sao kê thật:
  ///
  /// 1. **Chiều tiền viết bằng ký hiệu**: `(1.000)`, `1.000-`, `1.000 DR` đều là
  ///    tiền ra. Chuẩn hoá về dấu trừ ngay tại đây là điều kiện để bốn parser đổ
  ///    chung vào một mô hình (Rule – The Sign Carries the Direction).
  /// 2. **Bỏ mọi thứ không phải chữ số**: mã tiền dính kèm, khoảng trắng hẹp,
  ///    dấu cộng.
  /// 3. **Phân biệt dấu phân nhóm với dấu thập phân**: `1.234,56` (kiểu Việt
  ///    Nam / châu Âu) và `1,234.56` (kiểu Anh Mỹ) viết ngược nhau. Khi có cả
  ///    hai ký tự thì ký tự **xuất hiện sau** là dấu thập phân; khi chỉ có một
  ///    thì nó là dấu thập phân chỉ khi phần đuôi không dài đúng 3 chữ số —
  ///    `1.000` là một nghìn, không phải một phẩy không.
  static String _canonicalDecimal(String? raw) {
    var value = raw?.trim() ?? '';
    if (value.isEmpty) {
      throw const StatementFieldException('The amount is missing.');
    }

    var negative = false;
    if (value.startsWith('(') && value.endsWith(')')) {
      negative = true;
      value = value.substring(1, value.length - 1);
    }
    final upper = value.toUpperCase();
    if (upper.endsWith('DR') || upper.endsWith('DB')) {
      negative = true;
      value = value.substring(0, value.length - 2);
    } else if (upper.endsWith('CR')) {
      value = value.substring(0, value.length - 2);
    }
    value = value.trim();
    if (value.endsWith('-')) {
      negative = true;
      value = value.substring(0, value.length - 1);
    }
    if (value.startsWith('-')) {
      negative = !negative;
      value = value.substring(1);
    } else if (value.startsWith('+')) {
      value = value.substring(1);
    }

    value = value.replaceAll(_nonNumericPattern, '');
    if (value.isEmpty) {
      throw StatementFieldException('Could not read the amount "$raw".');
    }

    final lastDot = value.lastIndexOf('.');
    final lastComma = value.lastIndexOf(',');
    final decimalAt = lastDot > lastComma ? lastDot : lastComma;
    final String digits;
    if (decimalAt < 0) {
      digits = value;
    } else {
      final fraction = value.substring(decimalAt + 1);
      final isGroupSeparator =
          fraction.length == 3 && lastDot != lastComma && (lastDot < 0 || lastComma < 0);
      digits = isGroupSeparator || fraction.isEmpty
          ? value.replaceAll(_separatorPattern, '')
          : '${value.substring(0, decimalAt).replaceAll(_separatorPattern, '')}'
                '.$fraction';
    }

    if (!_digitsPattern.hasMatch(digits)) {
      throw StatementFieldException('Could not read the amount "$raw".');
    }
    return negative ? '-$digits' : digits;
  }

  static DateTime _buildDate({
    required int year,
    required int month,
    required int day,
    required String raw,
  }) {
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      throw StatementFieldException('The date "$raw" is not valid.');
    }
    final date = DateTime.utc(year, month, day);
    // `DateTime.utc` tự trượt sang tháng sau với ngày 31 của tháng chỉ có 30
    // ngày. Trượt trong im lặng là đúng thứ không được phép ở đây: nó tạo ra một
    // giao dịch có thật ở sai ngày.
    if (date.year != year || date.month != month || date.day != day) {
      throw StatementFieldException('The date "$raw" does not exist.');
    }
    return date;
  }

  /// Năm hai chữ số của MT940 và vài sao kê cũ.
  ///
  /// Sao kê là dữ liệu quá khứ gần, không phải dữ liệu lịch sử, nên `25` là 2025
  /// chứ không phải 1925.
  static int _expandYear(int value) => value >= 100 ? value : 2000 + value;

  static final RegExp _datePattern = RegExp(
    r'^(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})',
  );
  static final RegExp _nonNumericPattern = RegExp(r'[^0-9.,]');
  static final RegExp _separatorPattern = RegExp(r'[.,]');
  static final RegExp _digitsPattern = RegExp(r'^\d+(?:\.\d+)?$');
}
