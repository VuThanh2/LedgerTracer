import '../services/match_predicate.dart';
import '../value_objects/date_range.dart';
import '../value_objects/fingerprint.dart';
import '../value_objects/money.dart';
import '../value_objects/search_text.dart';

/// Một dòng tiền vào hoặc ra của đúng một tài khoản, đến từ đúng một dòng trong
/// file sao kê.
///
/// Là aggregate root riêng (xem `bank_account.dart` để biết vì sao không lồng
/// vào tài khoản), và không bao giờ mồ côi: mỗi giao dịch luôn trỏ về bản ghi
/// nhập đã sinh ra nó — chính liên kết đó làm cho việc hoàn tác khả thi
/// (Rule – Provenance Is What Makes Undo Possible).
final class Transaction implements MatchCandidate {
  const Transaction({
    this.transactionId,
    required this.accountId,
    required this.bookingDate,
    required this.amount,
    this.counterpartyName,
    required this.description,
    required this.searchText,
    required this.fingerprint,
    required this.importFileRecordId,
    this.sourceLineNumber,
    this.isManuallyEdited = false,
    required this.importedAt,
  });

  /// Dựng giao dịch sắp được ghi ở giai đoạn ghi của một lượt nhập (UC-02).
  ///
  /// [searchText] và [fingerprint] được dẫn xuất tại đây, một lần, rồi lưu thành
  /// cột có chỉ mục (Rule – Normalization Happens Once, at Import).
  factory Transaction.imported({
    required int accountId,
    required DateTime bookingDate,
    required Money amount,
    String? counterpartyName,
    required String description,
    required int importFileRecordId,
    int? sourceLineNumber,
    required DateTime importedAt,
  }) {
    final bookingDay = DateRange.dateOnly(bookingDate);
    return Transaction(
      accountId: accountId,
      bookingDate: bookingDay,
      amount: amount,
      counterpartyName: _blankToNull(counterpartyName),
      description: description,
      searchText: SearchText.of(
        counterpartyName: counterpartyName,
        description: description,
      ),
      fingerprint: Fingerprint.of(
        accountId: accountId,
        bookingDate: bookingDay,
        amount: amount,
        description: description,
      ),
      importFileRecordId: importFileRecordId,
      sourceLineNumber: sourceLineNumber,
      importedAt: importedAt,
    );
  }

  /// `null` cho tới khi được ghi xuống; là số nguyên tự tăng cục bộ chứ không
  /// phải UUID — chỉ một thiết bị sinh id, mà khoá số nguyên rẻ hơn hẳn về chỉ
  /// mục ở quy mô hàng trăm nghìn dòng
  /// (Rule – Identity Is Local and Surrogate; Sameness Is Fingerprint).
  @override
  final int? transactionId;

  @override
  final int accountId;

  /// Ngày ngân hàng ghi nhận, đọc từ file — là **căn cứ duy nhất** để sắp xếp,
  /// lọc, gom nhóm và tính độ lệch ghép cặp
  /// (Rule – File Time and Device Time Are Different Things).
  @override
  final DateTime bookingDate;

  /// Số tiền có dấu kèm loại tiền; dương là tiền vào, âm là tiền ra.
  @override
  final Money amount;

  final String? counterpartyName;

  final String description;

  /// Dạng không dấu, có chỉ mục của tên đối tác và nội dung (UC-06).
  final SearchText searchText;

  /// Khoá chống trùng, có chỉ mục nhưng **không** ràng buộc duy nhất (UC-02).
  final Fingerprint fingerprint;

  /// Nguồn gốc của dòng này — liên kết làm cho hoàn tác chính xác được.
  final int importFileRecordId;

  /// Số thứ tự dòng trong file gốc, hiện ở màn hình chi tiết để người dùng đối
  /// chiếu trước khi sửa (UC-04, UC-05).
  final int? sourceLineNumber;

  /// Bật lên khi người dùng đã sửa tay; lịch sử nhập sẽ cảnh báo trước khi hoàn
  /// tác vì thao tác đó xoá luôn phần đã sửa (UC-03).
  final bool isManuallyEdited;

  /// Đồng hồ thiết bị lúc nhập, chỉ dùng cho lịch sử nhập.
  final DateTime importedAt;

  bool get isPersisted => transactionId != null;

  bool get isIncoming => amount.isIncoming;

  bool get isOutgoing => amount.isOutgoing;

  Transaction withIdentity(int id) => _copyWith(transactionId: id);

  /// Áp dụng một lần sửa tay (UC-05).
  ///
  /// Biểu mẫu sửa luôn gửi lên trọn bộ trường sửa được nên mọi tham số đều bắt
  /// buộc — truyền `null` cho [counterpartyName] là xoá trắng nó. `searchText`
  /// và `fingerprint` được tính lại: bản đã sửa mà giữ cột dẫn xuất cũ sẽ vừa
  /// tìm không ra vừa bị coi là giao dịch mới ở lần nhập sau.
  ///
  /// Tài khoản không sửa được: nó nằm trong fingerprint và trong chuỗi nguồn gốc.
  Transaction editedWith({
    required DateTime bookingDate,
    required Money amount,
    required String? counterpartyName,
    required String description,
  }) {
    final bookingDay = DateRange.dateOnly(bookingDate);
    final editedCounterparty = _blankToNull(counterpartyName);
    return _copyWith(
      bookingDate: bookingDay,
      amount: amount,
      counterpartyName: editedCounterparty,
      clearCounterpartyName: editedCounterparty == null,
      description: description,
      searchText: SearchText.of(
        counterpartyName: counterpartyName,
        description: description,
      ),
      fingerprint: Fingerprint.of(
        accountId: accountId,
        bookingDate: bookingDay,
        amount: amount,
        description: description,
      ),
      isManuallyEdited: true,
    );
  }

  Transaction _copyWith({
    int? transactionId,
    DateTime? bookingDate,
    Money? amount,
    String? counterpartyName,
    bool clearCounterpartyName = false,
    String? description,
    SearchText? searchText,
    Fingerprint? fingerprint,
    bool? isManuallyEdited,
  }) => Transaction(
    transactionId: transactionId ?? this.transactionId,
    accountId: accountId,
    bookingDate: bookingDate ?? this.bookingDate,
    amount: amount ?? this.amount,
    counterpartyName: clearCounterpartyName
        ? null
        : (counterpartyName ?? this.counterpartyName),
    description: description ?? this.description,
    searchText: searchText ?? this.searchText,
    fingerprint: fingerprint ?? this.fingerprint,
    importFileRecordId: importFileRecordId,
    sourceLineNumber: sourceLineNumber,
    isManuallyEdited: isManuallyEdited ?? this.isManuallyEdited,
    importedAt: importedAt,
  );

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// So sánh theo định danh; dòng chưa được ghi chỉ bằng chính nó.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.transactionId != null &&
          other.transactionId == transactionId);

  @override
  int get hashCode => transactionId?.hashCode ?? identityHashCode(this);

  @override
  String toString() =>
      'Transaction($transactionId, account $accountId, '
      '${bookingDate.toIso8601String()}, $amount)';
}
