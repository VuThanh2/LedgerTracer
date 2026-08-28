import '../../domain/entities/import_error_row.dart';
import '../../domain/entities/import_file_record.dart';
import '../../domain/entities/import_session.dart';
import '../../domain/errors/import_errors.dart';
import '../../domain/repositories/import_repository.dart';
import '../../domain/value_objects/import_session_status.dart';
import '../database/app_database.dart';
import '../database/schema.dart';
import '../database/sql_query.dart';
import 'mappers/import_record_mapper.dart';

/// Hiện thực SQLite của [ImportRepository] (UC-02, UC-03).
///
/// Cổng này chỉ sở hữu phần **lịch sử** của một lượt nhập; việc xoá các giao dịch
/// mà nó đã ghi là của `TransactionRepository`.
final class SqliteImportRepository implements ImportRepository {
  const SqliteImportRepository(this._db);

  final AppDatabase _db;

  @override
  Future<ImportSession> addSession(ImportSession session) async {
    final id = await _db.executor.insert(
      LedgerSchema.importSession,
      ImportRecordMapper.sessionToRow(session),
    );
    return session.withIdentity(id);
  }

  @override
  Future<void> updateSession(ImportSession session) async {
    final changed = await _db.executor.update(
      LedgerSchema.importSession,
      ImportRecordMapper.sessionToRow(session),
      where: 'session_id = ?',
      whereArgs: <Object?>[session.sessionId],
    );
    if (changed == 0) throw ImportSessionNotFoundError(session.sessionId!);
  }

  @override
  Future<List<ImportSession>> findSessions({
    required int limit,
    required int offset,
  }) async {
    final rows = await _db.executor.query(
      LedgerSchema.importSession,
      orderBy: 'started_at DESC, session_id DESC',
      limit: limit,
      offset: offset,
    );
    return _hydrate(rows.map(ImportRecordMapper.sessionFromRow).toList());
  }

  @override
  Future<int> countSessions() =>
      _db.executor.countRows('SELECT COUNT(*) FROM ${LedgerSchema.importSession}');

  /// Không kèm bản ghi con: nơi gọi chỉ đổi trạng thái của chính lượt nhập.
  @override
  Future<List<ImportSession>> findUnfinishedSessions() async {
    final rows = await _db.executor.query(
      LedgerSchema.importSession,
      where: 'status = ?',
      whereArgs: <Object?>[ImportSessionStatus.inProgress.name],
      orderBy: 'session_id',
    );
    return rows.map(ImportRecordMapper.sessionFromRow).toList(growable: false);
  }

  @override
  Future<ImportSession?> findSessionById(int sessionId) async {
    final rows = await _db.executor.query(
      LedgerSchema.importSession,
      where: 'session_id = ?',
      whereArgs: <Object?>[sessionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final hydrated = await _hydrate(<ImportSession>[
      ImportRecordMapper.sessionFromRow(rows.first),
    ]);
    return hydrated.single;
  }

  /// Gắn bản ghi con vào các lượt nhập vừa đọc, bằng **một** truy vấn cho cả
  /// trang.
  ///
  /// Hợp đồng của interface bắt buộc trả kèm đầy đủ bản ghi con: hoàn tác cả một
  /// lượt được định nghĩa là lần lượt hoàn tác từng bản ghi con, nên một danh
  /// sách rỗng ở đây sẽ biến thao tác hoàn tác thành một lệnh không làm gì cả
  /// (UC-03).
  ///
  /// Hỏi một lần cho cả trang chứ không mỗi lượt một lần: N+1 truy vấn cho một
  /// màn hình cuộn là thứ chỉ thấy chậm khi người dùng đã nhập nhiều.
  ///
  /// Danh sách định danh vẫn được chia lô trước khi vào mệnh đề `IN`. Trên thực
  /// tế một trang lịch sử không bao giờ dài tới mức đó, nhưng kích thước trang
  /// là do nơi gọi quyết định — và một giả định về nơi gọi thì không có gì canh
  /// giữ, trong khi hậu quả của việc vượt trần tham số là một lỗi SQLite khó
  /// hiểu chứ không phải một thông báo rõ ràng.
  Future<List<ImportSession>> _hydrate(List<ImportSession> sessions) async {
    if (sessions.isEmpty) return sessions;

    final bySession = <int, List<ImportFileRecord>>{};
    final ids = sessions.map((session) => session.sessionId!);
    for (final chunk in SqlQuery.chunked(ids)) {
      final rows = await _db.executor.query(
        LedgerSchema.importFileRecord,
        where: 'session_id IN (${SqlQuery.placeholders(chunk.length)})',
        whereArgs: chunk,
        orderBy: 'session_id, order_index',
      );
      for (final row in rows) {
        final record = ImportRecordMapper.fileRecordFromRow(row);
        bySession
            .putIfAbsent(record.sessionId, () => <ImportFileRecord>[])
            .add(record);
      }
    }
    return <ImportSession>[
      for (final session in sessions)
        session.withFileRecords(
          bySession[session.sessionId] ?? const <ImportFileRecord>[],
        ),
    ];
  }

  @override
  Future<int> deleteEmptySessions() => _db.executor.rawDelete(
    'DELETE FROM ${LedgerSchema.importSession} WHERE session_id NOT IN '
    '(SELECT session_id FROM ${LedgerSchema.importFileRecord})',
  );

  @override
  Future<ImportFileRecord> addFileRecord(ImportFileRecord record) async {
    final id = await _db.executor.insert(
      LedgerSchema.importFileRecord,
      ImportRecordMapper.fileRecordToRow(record),
    );
    return record.withIdentity(id);
  }

  @override
  Future<void> updateFileRecord(ImportFileRecord record) async {
    final changed = await _db.executor.update(
      LedgerSchema.importFileRecord,
      ImportRecordMapper.fileRecordToRow(record),
      where: 'record_id = ?',
      whereArgs: <Object?>[record.recordId],
    );
    if (changed == 0) throw ImportFileRecordNotFoundError(record.recordId!);
  }

  @override
  Future<ImportFileRecord?> findFileRecordById(int recordId) async {
    final rows = await _db.executor.query(
      LedgerSchema.importFileRecord,
      where: 'record_id = ?',
      whereArgs: <Object?>[recordId],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : ImportRecordMapper.fileRecordFromRow(rows.first);
  }

  @override
  Future<List<ImportFileRecord>> findFileRecordsByAccountId(
    int accountId,
  ) async {
    final rows = await _db.executor.query(
      LedgerSchema.importFileRecord,
      where: 'account_id = ?',
      whereArgs: <Object?>[accountId],
      orderBy: 'session_id, order_index',
    );
    return rows
        .map(ImportRecordMapper.fileRecordFromRow)
        .toList(growable: false);
  }

  /// Xoá bản ghi cùng các dòng lỗi của nó.
  ///
  /// Dòng lỗi thuộc về aggregate ImportSession và không có nghĩa gì khi đứng
  /// một mình, nên chúng đi theo ở đây chứ không bắt nơi gọi phải nhớ — khác hẳn
  /// giao dịch, vốn là aggregate riêng và được tầng Application xoá tường minh.
  @override
  Future<void> deleteFileRecordById(int recordId) async {
    await _db.executor.delete(
      LedgerSchema.importErrorRow,
      where: 'record_id = ?',
      whereArgs: <Object?>[recordId],
    );
    await _db.executor.delete(
      LedgerSchema.importFileRecord,
      where: 'record_id = ?',
      whereArgs: <Object?>[recordId],
    );
  }

  /// Ghi các dòng lỗi của **một lô** trong đúng một lần đi xuống cơ sở dữ liệu.
  @override
  Future<void> addErrorRows(List<ImportErrorRow> rows) async {
    if (rows.isEmpty) return;
    final batch = _db.executor.batch();
    for (final row in rows) {
      batch.insert(
        LedgerSchema.importErrorRow,
        ImportRecordMapper.errorRowToRow(row),
      );
    }
    // `noResult` vì các định danh vừa cấp không ai dùng tới: dòng lỗi chỉ được
    // đọc lại theo bản ghi file lúc xuất file (UC-11).
    await batch.commit(noResult: true);
  }

  @override
  Future<List<ImportErrorRow>> findErrorRows(int recordId) async {
    final rows = await _db.executor.query(
      LedgerSchema.importErrorRow,
      where: 'record_id = ?',
      whereArgs: <Object?>[recordId],
      orderBy: 'source_line_number, error_row_id',
    );
    return rows.map(ImportRecordMapper.errorRowFromRow).toList(growable: false);
  }
}
