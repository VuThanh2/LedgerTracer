import '../entities/transaction.dart';
import '../errors/transaction_errors.dart';
import '../value_objects/amount_range.dart';
import '../value_objects/currency.dart';
import '../value_objects/date_range.dart';
import '../value_objects/fingerprint.dart';
import '../value_objects/money.dart';
import '../value_objects/search_text.dart';

/// Bộ tiêu chí thu hẹp các đường đọc giao dịch (UC-04, UC-06, UC-07). Tất cả kết
/// hợp với nhau theo logic VÀ.
///
/// Gom vào một object là thứ cho phép danh sách, phép đếm và file xuất chạy
/// **cùng một** điều kiện — ba bản chép tay của nó chắc chắn sẽ lệch và cho ra
/// ba tập kết quả khác nhau.
final class TransactionFilter {
  /// [currency] được suy ra từ [amountRange] nếu không truyền: một khoảng số
  /// tiền không có loại tiền là so sánh hai con số khác đơn vị, và sẽ loại nhầm
  /// giao dịch 1.000 USD khỏi khoảng "1 đến 5 triệu" (UC-07).
  ///
  /// Ném [CurrencyMismatchError] nếu truyền cả hai mà lại lệch nhau.
  factory TransactionFilter({
    SearchText? keyword,
    int? accountId,
    DateRange? dateRange,
    AmountRange? amountRange,
    Currency? currency,
  }) {
    if (amountRange != null &&
        currency != null &&
        amountRange.currency != currency) {
      throw CurrencyMismatchError(amountRange.currency.code, currency.code);
    }
    return TransactionFilter._(
      keyword: keyword != null && keyword.isNotEmpty ? keyword : null,
      accountId: accountId,
      dateRange: dateRange,
      amountRange: amountRange,
      currency: currency ?? amountRange?.currency,
    );
  }

  const TransactionFilter._({
    required this.keyword,
    required this.accountId,
    required this.dateRange,
    required this.amountRange,
    required this.currency,
  });

  /// Lấy tất cả, sắp theo ngày ghi nhận — danh sách mặc định của UC-04.
  static const TransactionFilter none = TransactionFilter._(
    keyword: null,
    accountId: null,
    dateRange: null,
    amountRange: null,
    currency: null,
  );

  final SearchText? keyword;
  final int? accountId;
  final DateRange? dateRange;
  final AmountRange? amountRange;
  final Currency? currency;

  bool get isEmpty =>
      keyword == null &&
      accountId == null &&
      dateRange == null &&
      amountRange == null &&
      currency == null;

  /// Bản trong bộ nhớ của chính điều kiện đó, để kiểm một giao dịch vừa ghi có
  /// khớp bộ lọc đang bật hay không mà không cần hỏi lại cơ sở dữ liệu.
  bool matches(Transaction transaction) {
    final activeKeyword = keyword;
    final activeRange = dateRange;
    final activeAmounts = amountRange;
    final activeCurrency = currency;
    return (activeKeyword == null ||
            transaction.searchText.contains(activeKeyword)) &&
        (accountId == null || transaction.accountId == accountId) &&
        (activeRange == null ||
            activeRange.contains(transaction.bookingDate)) &&
        (activeAmounts == null || activeAmounts.contains(transaction.amount)) &&
        (activeCurrency == null ||
            transaction.amount.currency == activeCurrency);
  }
}

/// Mỗi loại tiền có bao nhiêu giao dịch, nhiều nhất đứng trước — căn cứ để chọn
/// tab loại tiền mặc định (UC-10) và giá trị mặc định của bộ lọc số tiền
/// (UC-07).
final class CurrencyUsage {
  const CurrencyUsage({required this.currency, required this.transactionCount});

  final Currency currency;
  final int transactionCount;
}

/// Độ mịn thời gian của biểu đồ dòng tiền; mặc định theo tháng (UC-10 bước 2).
enum CashFlowPeriod { day, month, year }

/// Một cột của biểu đồ dòng tiền: hoặc một mốc thời gian, hoặc một tài khoản,
/// tuỳ phép tổng hợp nào sinh ra nó (UC-10).
///
/// Thống kê luôn được tính, không bao giờ lưu — một con số tổng đã lưu sẽ sai
/// ngay khi bất kỳ đường nào trong sáu đường thay đổi dữ liệu chạy qua
/// (Rule – Statistics Are Always Derived, Never Stored).
final class CashFlowBucket {
  const CashFlowBucket({
    this.periodStart,
    this.accountId,
    required this.inflow,
    required this.outflow,
  });

  /// Ngày đầu của mốc, khi gom nhóm theo thời gian.
  final DateTime? periodStart;

  /// Tài khoản, khi gom nhóm theo tài khoản.
  final int? accountId;

  /// Tổng các số tiền dương (tiền vào).
  final Money inflow;

  /// Tổng các số tiền âm (tiền ra), giữ nguyên dấu âm để [net] chỉ là một phép
  /// cộng.
  final Money outflow;

  Money get net => inflow + outflow;
}

/// Cổng lưu trữ của aggregate Transaction.
///
/// Các đường đọc truy vấn thẳng cơ sở dữ liệu chứ không nạp aggregate: đó là
/// điều kiện để một danh sách hàng trăm nghìn dòng cuộn được (UC-04). Vì vậy mọi
/// phép đọc đều theo trang.
abstract interface class TransactionRepository {
  /// Một trang của danh sách, ngày ghi nhận mới nhất trước (UC-04).
  Future<List<Transaction>> findPage({
    required TransactionFilter filter,
    required int limit,
    required int offset,
  });

  /// Số dòng khớp cùng [filter], dùng cho trạng thái trống và cho phần đầu file
  /// xuất (UC-11).
  Future<int> count(TransactionFilter filter);

  Future<Transaction?> findById(int transactionId);

  /// Nạp giao dịch theo một tập định danh — dùng để dựng hai vế của các cặp trên
  /// màn hình đối soát (UC-09).
  Future<List<Transaction>> findByIds(Iterable<int> transactionIds);

  /// Ghi một lô của giai đoạn ghi và trả về định danh vừa cấp, đúng thứ tự
  /// (UC-02).
  ///
  /// Trả định danh chứ không trả entity: một lượt nhập ghi hàng trăm nghìn dòng
  /// và giai đoạn ghi không dùng tới các object dựng lại.
  Future<List<int>> addAll(List<Transaction> transactions);

  /// Lưu một lần sửa tay, gồm cả searchText và fingerprint đã tính lại (UC-05).
  ///
  /// Ném `TransactionNotFoundError` nếu bản ghi không còn tồn tại.
  Future<void> update(Transaction transaction);

  Future<void> deleteById(int transactionId);

  /// Tài khoản này đang có bao nhiêu dòng ứng với mỗi fingerprint.
  ///
  /// Chống trùng so theo **số lượng**, không phải theo sự tồn tại: nhập lại cùng
  /// một file phải không thêm gì, trong khi hai dòng giống hệt nhau trong cùng
  /// một file là hai giao dịch thật và phải được ghi đủ (UC-02).
  Future<Map<Fingerprint, int>> countByFingerprint({
    required int accountId,
    required Iterable<Fingerprint> fingerprints,
  });

  /// Định danh các dòng mà một lượt nhập đã ghi — cần để huỷ cặp và xoá phán
  /// quyết từ chối liên quan trước khi xoá chúng (UC-03, UC-09).
  Future<List<int>> findIdsByImportFileRecordId(int recordId);

  Future<List<int>> findIdsByAccountId(int accountId);

  /// Xoá những gì một file đã ghi và trả về số dòng đã mất (UC-03). Xoá vật lý,
  /// không tombstone.
  Future<int> deleteByImportFileRecordId(int recordId);

  /// Xoá mọi giao dịch của một tài khoản, như một phần của việc xoá chính tài
  /// khoản đó (UC-01).
  Future<int> deleteByAccountId(int accountId);

  /// Lượt nhập này có bao nhiêu dòng đã bị sửa tay — lịch sử cảnh báo trước khi
  /// hoàn tác, vì hoàn tác xoá luôn phần đã sửa (UC-03).
  Future<int> countManuallyEditedByImportFileRecordId(int recordId);

  /// Các loại tiền đang có trong dữ liệu, nhiều giao dịch nhất trước (UC-07,
  /// UC-10).
  Future<List<CurrencyUsage>> currencyUsage();

  /// Dòng tiền gom theo thời gian, cho **một** loại tiền — số liệu của các loại
  /// tiền khác nhau không bao giờ cộng gộp và không quy đổi (UC-10).
  ///
  /// Khi [excludeInternalTransfers] bật (mặc định của màn hình), các dòng thuộc
  /// cặp **đã xác nhận** bị loại ra, để chuyển tiền nội bộ không bị tính thành
  /// dòng tiền với bên ngoài.
  Future<List<CashFlowBucket>> aggregateByPeriod({
    required Currency currency,
    required CashFlowPeriod period,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  });

  /// Cùng số liệu đó nhưng gom theo tài khoản (UC-10 bước 3).
  Future<List<CashFlowBucket>> aggregateByAccount({
    required Currency currency,
    DateRange? dateRange,
    bool excludeInternalTransfers = true,
  });
}
