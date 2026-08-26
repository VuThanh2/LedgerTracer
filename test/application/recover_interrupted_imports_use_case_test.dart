import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/import/recover_interrupted_imports/recover_interrupted_imports_use_case.dart';
import 'package:ledger_tracer/domain/entities/import_file_record.dart';
import 'package:ledger_tracer/domain/entities/import_session.dart';
import 'package:ledger_tracer/domain/value_objects/import_session_status.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

import '_support/fake_repositories.dart';
import '_support/seed.dart';

/// Huỷ chủ động ở UC-02 có mã lệnh chạy tại thời điểm dừng nên tự ghi được trạng
/// thái cuối. Gián đoạn bị động thì không: tiến trình bị hệ điều hành kết liễu,
/// hoặc tab trình duyệt bị đóng, và không có callback nào đáng tin để bám vào.
/// Chỗ duy nhất còn lại để nhận ra chuyện đó là lần khởi động kế tiếp — và suy
/// luận ấy đúng tuyệt đối chứ không phải phỏng đoán, vì chỉ có một tiến trình và
/// nó vừa mới sinh ra.
void main() {
  late FakeDatabase db;
  late Seed seed;
  late RecoverInterruptedImportsUseCase useCase;

  final now = DateTime.utc(2025, 9, 1, 12);

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    useCase = RecoverInterruptedImportsUseCase(
      imports: db.imports,
      unitOfWork: db.unitOfWork,
    );
  });

  /// Dựng lại đúng những gì một tiến trình bị kết liễu để lại: lượt nhập còn
  /// `InProgress`, bản ghi file vẫn ở trạng thái mở, và các dòng đã commit thì
  /// vẫn nằm trong bảng.
  Future<({int sessionId, int recordId})> killedMidImport({
    required int accountId,
    int writtenRows = 3,
  }) async {
    final session = await db.imports.addSession(ImportSession.started(now));
    var record = await db.imports.addFileRecord(
      ImportFileRecord.started(
        sessionId: session.sessionId!,
        accountId: accountId,
        fileName: 'sao-ke.csv',
        detectedFormat: StatementFormat.csv,
        orderIndex: 0,
      ),
    );
    for (var i = 0; i < writtenRows; i++) {
      await seed.transaction(
        accountId: accountId,
        recordId: record.recordId!,
        amount: -100000 - i,
        bookingDate: now.add(Duration(days: i)),
      );
    }
    record = record.accumulate(importedCount: writtenRows);
    await db.imports.updateFileRecord(record);
    return (sessionId: session.sessionId!, recordId: record.recordId!);
  }

  test('lượt còn InProgress lúc khởi động là mồ côi, được chốt là Interrupted',
      () async {
    final accountId = await seed.account('A');
    final killed = await killedMidImport(accountId: accountId);

    final result = await useCase.execute();

    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    expect(result.valueOrNull!.interruptedSessionCount, 1);
    expect(
      db.sessionRows[killed.sessionId]!.status,
      ImportSessionStatus.interrupted,
    );
  });

  test('không đụng tới dữ liệu đã ghi được', () async {
    // Gián đoạn không phải rollback: phần đã commit ở lại, đúng như khi huỷ.
    final accountId = await seed.account('A');
    final killed = await killedMidImport(accountId: accountId);

    await useCase.execute();

    expect(db.transactionRows.length, 3);
    expect(db.fileRecordRows[killed.recordId]!.importedCount, 3);
  });

  test('phần đã ghi của lượt bị gián đoạn vẫn hoàn tác được', () async {
    // Đây là điều kiện làm cho lượt quét dọn có ích thay vì chỉ đổi một nhãn:
    // nếu bộ đếm về 0 thì `canRevert` khoá lại và các dòng ấy thành mồ côi
    // không xoá được qua UC-03.
    final accountId = await seed.account('A');
    final killed = await killedMidImport(accountId: accountId);

    await useCase.execute();

    expect(db.fileRecordRows[killed.recordId]!.canRevert, isTrue);
  });

  test('lượt chết trước khi kịp mở bản ghi file nào bị xoá hẳn', () async {
    // "Một lượt nhập bị gián đoạn, đã ghi được 0 giao dịch" là tiếng ồn, không
    // phải thông tin: không có dữ liệu nào của người dùng dính tới nó.
    await db.imports.addSession(ImportSession.started(now));

    final result = await useCase.execute();

    expect(result.valueOrNull!.discardedEmptySessionCount, 1);
    expect(result.valueOrNull!.interruptedSessionCount, 0);
    expect(result.valueOrNull!.hasInterruptedSessions, isFalse);
    expect(db.sessionRows, isEmpty);
  });

  test('không đụng tới lượt đã hoàn tất hay đã bị huỷ', () async {
    final accountId = await seed.account('A');
    final recordId = await seed.fileRecord(accountId: accountId);
    final sessionId = db.fileRecordRows[recordId]!.sessionId;
    await db.imports.updateSession(db.sessionRows[sessionId]!.cancel(now));

    final result = await useCase.execute();

    expect(result.valueOrNull!.interruptedSessionCount, 0);
    expect(
      db.sessionRows[sessionId]!.status,
      ImportSessionStatus.cancelled,
    );
    expect(db.sessionRows[sessionId]!.completedAt, now);
  });

  test('chạy lại lần nữa không đổi gì thêm', () async {
    // Quét dọn chạy mỗi lần khởi động, nên nó phải luỹ đẳng.
    final accountId = await seed.account('A');
    await killedMidImport(accountId: accountId);

    await useCase.execute();
    final second = await useCase.execute();

    expect(second.valueOrNull!.interruptedSessionCount, 0);
    expect(second.valueOrNull!.discardedEmptySessionCount, 0);
  });

  test('không có gì để dọn thì báo không có gì', () async {
    final result = await useCase.execute();
    expect(result.valueOrNull!.interruptedSessionCount, 0);
    expect(result.valueOrNull!.discardedEmptySessionCount, 0);
  });
}
