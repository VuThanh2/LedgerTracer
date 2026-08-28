import '../../../domain/entities/import_error_row.dart';
import '../../../domain/entities/import_file_record.dart';
import '../../../domain/entities/import_session.dart';
import '../../../domain/value_objects/import_file_status.dart';
import '../../../domain/value_objects/import_session_status.dart';
import '../../../domain/value_objects/statement_format.dart';
import '../../database/sql_codec.dart';

/// Đổi ba entity của aggregate ImportSession qua lại với các dòng tương ứng.
///
/// Bộ đếm của [ImportFileRecord] được ghi lại **nguyên vẹn** như entity đang
/// mang, không tính lại từ bảng giao dịch. `duplicateSkippedCount` là lý do bắt
/// buộc: dòng bị bỏ vì đã có không được ghi ở đâu cả nên không có gì để đếm lại,
/// và ba bộ đếm mà hai cái tính lại được còn một cái thì không sẽ là ba con số
/// lệch pha nhau (Rule – A Dead Process Leaves Honest Records).
abstract final class ImportRecordMapper {
  static Map<String, Object?> sessionToRow(ImportSession session) =>
      <String, Object?>{
        'started_at': SqlCodec.timestamp(session.startedAt),
        'completed_at': SqlCodec.nullableTimestamp(session.completedAt),
        'status': session.status.name,
      };

  /// Dựng lại một lượt nhập **không kèm** bản ghi con; việc gắn chúng vào là của
  /// repository, vốn là nơi duy nhất truy vấn được chúng.
  static ImportSession sessionFromRow(Map<String, Object?> row) => ImportSession(
    sessionId: row['session_id'] as int,
    startedAt: SqlCodec.parseTimestamp(row['started_at'] as int),
    completedAt: SqlCodec.parseNullableTimestamp(row['completed_at']),
    status: SqlCodec.parseEnum(ImportSessionStatus.values, row['status']),
  );

  static Map<String, Object?> fileRecordToRow(ImportFileRecord record) =>
      <String, Object?>{
        'session_id': record.sessionId,
        'account_id': record.accountId,
        'file_name': record.fileName,
        'detected_format': record.detectedFormat.name,
        'order_index': record.orderIndex,
        'status': record.status.name,
        'imported_count': record.importedCount,
        'duplicate_skipped_count': record.duplicateSkippedCount,
        'error_row_count': record.errorRowCount,
        'reverted_at': SqlCodec.nullableTimestamp(record.revertedAt),
      };

  static ImportFileRecord fileRecordFromRow(Map<String, Object?> row) =>
      ImportFileRecord(
        recordId: row['record_id'] as int,
        sessionId: row['session_id'] as int,
        accountId: row['account_id'] as int,
        fileName: row['file_name'] as String,
        detectedFormat: SqlCodec.parseEnum(
          StatementFormat.values,
          row['detected_format'],
        ),
        orderIndex: row['order_index'] as int,
        status: SqlCodec.parseEnum(ImportFileStatus.values, row['status']),
        importedCount: row['imported_count'] as int,
        duplicateSkippedCount: row['duplicate_skipped_count'] as int,
        errorRowCount: row['error_row_count'] as int,
        revertedAt: SqlCodec.parseNullableTimestamp(row['reverted_at']),
      );

  static Map<String, Object?> errorRowToRow(ImportErrorRow row) =>
      <String, Object?>{
        'record_id': row.recordId,
        'source_line_number': row.sourceLineNumber,
        // Trích đoạn đã được cắt đúng một lần lúc `ParseError` ra đời; cắt lại ở
        // đây sẽ ăn thêm một ký tự và sinh ra dấu lược đôi.
        'raw_excerpt': row.rawExcerpt,
        'reason': row.reason,
      };

  static ImportErrorRow errorRowFromRow(Map<String, Object?> row) =>
      ImportErrorRow(
        errorRowId: row['error_row_id'] as int,
        recordId: row['record_id'] as int,
        sourceLineNumber: row['source_line_number'] as int,
        rawExcerpt: row['raw_excerpt'] as String,
        reason: row['reason'] as String,
      );
}
