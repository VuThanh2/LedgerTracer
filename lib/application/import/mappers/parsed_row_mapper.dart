import '../../../domain/entities/import_error_row.dart';
import '../../../domain/entities/transaction.dart';
import '../contracts/parse_error.dart';
import '../contracts/parsed_row.dart';

/// Biến các *Transient Type* từ isolate thành Entity của Domain ở giai đoạn ghi
/// (UC-02).
///
/// Đây là nơi accountId, importFileRecordId và importedAt — ba thứ chỉ luồng
/// chính biết — được gắn vào. `searchText` và `fingerprint` được [Transaction.imported]
/// dẫn xuất đúng tại đây, một lần, qua đúng một thuật toán chuẩn hoá
/// (Rule – Normalization Happens Once, at Import). Gộp phép dẫn xuất về một chỗ
/// giữ cho hai giá trị có chỉ mục đó không bao giờ có bản sao thứ hai lệch nhau.
abstract final class ParsedRowMapper {
  /// Dựng giao dịch sắp ghi từ một dòng đã phân tích. Không tự sinh định danh —
  /// cơ sở dữ liệu cấp nó khi ghi.
  static Transaction toTransaction(
    ParsedRow row, {
    required int accountId,
    required int importFileRecordId,
    required DateTime importedAt,
  }) => Transaction.imported(
    accountId: accountId,
    bookingDate: row.bookingDate,
    amount: row.amount,
    counterpartyName: row.counterpartyName,
    description: row.description,
    importFileRecordId: importFileRecordId,
    sourceLineNumber: row.sourceLineNumber,
    importedAt: importedAt,
  );

  /// Biến một lỗi phân tích thành dòng lỗi trỏ về bản ghi file, để xuất lại được
  /// cả khi màn hình tổng kết đã đóng (UC-03, UC-11).
  /// Dựng thẳng [ImportErrorRow] chứ không qua `ImportErrorRow.from`: trích đoạn
  /// đã được cắt một lần lúc `ParseError` ra đời, cắt lại sẽ ăn mất thêm một ký
  /// tự và sinh ra dấu lược đôi.
  static ImportErrorRow toErrorRow(
    ParseError error, {
    required int importFileRecordId,
  }) => ImportErrorRow(
    recordId: importFileRecordId,
    sourceLineNumber: error.sourceLineNumber,
    rawExcerpt: error.rawExcerpt,
    reason: error.reason,
  );
}
