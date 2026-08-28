import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/currency.dart';
import '../../../domain/value_objects/fingerprint.dart';
import '../../../domain/value_objects/money.dart';
import '../../../domain/value_objects/search_text.dart';
import '../../database/sql_codec.dart';

/// Đổi một [Transaction] qua lại với một dòng của bảng `ledger_transaction`.
///
/// `searchText` và `fingerprint` được đọc lại bằng hai hàm dựng `fromStored`,
/// **không** tính lại từ nội dung: chúng đã được dẫn xuất đúng một lần lúc nhập
/// và lưu thành cột có chỉ mục (Rule – Normalization Happens Once, at Import).
/// Tính lại ở đây sẽ vừa trả giá cho mỗi dòng đọc ra, vừa mở ra khả năng giá trị
/// trong bộ nhớ khác giá trị mà truy vấn vừa dùng để tìm ra chính dòng đó.
abstract final class TransactionMapper {
  /// Dòng sắp ghi. Cố ý **không** có `transaction_id`: định danh do cơ sở dữ
  /// liệu cấp, và gửi kèm một giá trị `null` chỉ khiến `INSERT` phải khai báo
  /// thêm một cột không mang thông tin gì.
  static Map<String, Object?> toRow(Transaction transaction) =>
      <String, Object?>{
        'account_id': transaction.accountId,
        'booking_date': SqlCodec.bookingDate(transaction.bookingDate),
        'amount_minor': transaction.amount.minorUnits,
        'currency': transaction.amount.currency.code,
        'counterparty_name': transaction.counterpartyName,
        'description': transaction.description,
        'search_text': transaction.searchText.value,
        'fingerprint': transaction.fingerprint.value,
        'import_file_record_id': transaction.importFileRecordId,
        'source_line_number': transaction.sourceLineNumber,
        'is_manually_edited': SqlCodec.boolean(transaction.isManuallyEdited),
        'imported_at': SqlCodec.timestamp(transaction.importedAt),
      };

  static Transaction fromRow(Map<String, Object?> row) => Transaction(
    transactionId: row['transaction_id'] as int,
    accountId: row['account_id'] as int,
    bookingDate: SqlCodec.parseBookingDate(row['booking_date'] as String),
    amount: Money(
      row['amount_minor'] as int,
      Currency.parse(row['currency'] as String),
    ),
    counterpartyName: row['counterparty_name'] as String?,
    description: row['description'] as String,
    searchText: SearchText.fromStored(row['search_text'] as String),
    fingerprint: Fingerprint.fromStored(row['fingerprint'] as String),
    importFileRecordId: row['import_file_record_id'] as int,
    sourceLineNumber: row['source_line_number'] as int?,
    isManuallyEdited: SqlCodec.parseBoolean(row['is_manually_edited']),
    importedAt: SqlCodec.parseTimestamp(row['imported_at'] as int),
  );
}
