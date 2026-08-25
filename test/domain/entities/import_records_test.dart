import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/import_error_row.dart';
import 'package:ledger_tracer/domain/entities/import_file_record.dart';
import 'package:ledger_tracer/domain/entities/import_session.dart';
import 'package:ledger_tracer/domain/errors/import_errors.dart';
import 'package:ledger_tracer/domain/value_objects/import_file_status.dart';
import 'package:ledger_tracer/domain/value_objects/import_session_status.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

void main() {
  final startedAt = DateTime.utc(2025, 5, 1, 9);
  final finishedAt = DateTime.utc(2025, 5, 1, 9, 30);

  ImportFileRecord record({int orderIndex = 0, int sessionId = 1}) =>
      ImportFileRecord.started(
        sessionId: sessionId,
        accountId: 2,
        fileName: 'sao-ke-thang-3.csv',
        detectedFormat: StatementFormat.csv,
        orderIndex: orderIndex,
      );

  group('ImportFileRecord — trạng thái khi mở', () {
    test('mở ra ở trạng thái đã huỷ, không phải đã hoàn tất', () {
      // Nếu tiến trình chết giữa chừng, bản ghi còn lại nói đúng sự thật là
      // lượt nhập chưa hoàn tất, thay vì nói dối rằng nó đã xong.
      expect(record().status, ImportFileStatus.cancelled);
    });

    test('mọi bộ đếm bắt đầu từ 0 và chưa hoàn tác được', () {
      final fresh = record();
      expect(fresh.importedCount, 0);
      expect(fresh.duplicateSkippedCount, 0);
      expect(fresh.errorRowCount, 0);
      expect(fresh.isReverted, isFalse);
      expect(fresh.canRevert, isFalse);
    });

    test('từ chối thứ tự chọn file âm', () {
      expect(() => record(orderIndex: -1), throwsA(isA<AssertionError>()));
    });
  });

  group('ImportFileRecord — chốt kết quả', () {
    test('không dòng lỗi nào thì là hoàn tất', () {
      final done = record().finished(
        importedCount: 120,
        duplicateSkippedCount: 5,
        errorRowCount: 0,
      );
      expect(done.status, ImportFileStatus.completed);
      expect(done.importedCount, 120);
      expect(done.duplicateSkippedCount, 5);
    });

    test('có dòng lỗi thì là hỏng một phần, không phải hỏng cả file', () {
      // Một dòng hỏng không được làm dừng các dòng còn lại.
      final done = record().finished(
        importedCount: 118,
        duplicateSkippedCount: 0,
        errorRowCount: 2,
      );
      expect(done.status, ImportFileStatus.partiallyFailed);
    });

    test('bị huỷ thì là đã huỷ, kể cả khi có dòng lỗi', () {
      final done = record().finished(
        importedCount: 40,
        duplicateSkippedCount: 0,
        errorRowCount: 3,
        wasCancelled: true,
      );
      expect(done.status, ImportFileStatus.cancelled);
      // Phần đã xử lý xong trước thời điểm huỷ vẫn được giữ lại.
      expect(done.importedCount, 40);
    });

    test('file toàn dòng trùng vẫn là hoàn tất', () {
      final done = record().finished(
        importedCount: 0,
        duplicateSkippedCount: 200,
        errorRowCount: 0,
      );
      expect(done.status, ImportFileStatus.completed);
    });

    test('người dùng bỏ qua file là một trạng thái riêng, không phải lỗi đọc', () {
      expect(record().skipped().status, ImportFileStatus.skipped);
    });

    test('chốt kết quả không đụng tới thứ tự chọn và nguồn gốc', () {
      final done = record(orderIndex: 3).finished(
        importedCount: 1,
        duplicateSkippedCount: 0,
        errorRowCount: 0,
      );
      expect(done.orderIndex, 3);
      expect(done.sessionId, 1);
      expect(done.accountId, 2);
      expect(done.fileName, 'sao-ke-thang-3.csv');
      expect(done.detectedFormat, StatementFormat.csv);
    });
  });

  group('ImportFileRecord — hoàn tác', () {
    ImportFileRecord completed({int imported = 10}) => record()
        .withIdentity(4)
        .finished(
          importedCount: imported,
          duplicateSkippedCount: 0,
          errorRowCount: 0,
        );

    test('bản ghi có dòng đã ghi thì hoàn tác được', () {
      expect(completed().canRevert, isTrue);
    });

    test('đánh dấu đã hoàn tác mà không xoá bản ghi khỏi lịch sử', () {
      // revertedAt không phải tombstone: người dùng cần thấy "đã nhập rồi hoàn
      // tác", và dòng lỗi của nó vẫn phải xuất lại được.
      final reverted = completed().revert(finishedAt);
      expect(reverted.isReverted, isTrue);
      expect(reverted.revertedAt, finishedAt);
      expect(reverted.fileName, 'sao-ke-thang-3.csv');
      expect(reverted.importedCount, 10);
    });

    test('hoàn tác hai lần bị chặn', () {
      final reverted = completed().revert(finishedAt);
      expect(reverted.canRevert, isFalse);
      expect(
        () => reverted.revert(finishedAt),
        throwsA(isA<ImportAlreadyRevertedError>()),
      );
    });

    test('không có dòng nào đã ghi thì không có gì để hoàn tác', () {
      final empty = completed(imported: 0);
      expect(empty.canRevert, isFalse);
      expect(
        () => empty.revert(finishedAt),
        throwsA(isA<NothingToRevertError>()),
      );
    });
  });

  group('ImportSession', () {
    ImportSession session() =>
        ImportSession.started(startedAt).withIdentity(1);

    ImportFileRecord child({
      required int id,
      int imported = 0,
      int duplicates = 0,
      int errors = 0,
      DateTime? revertedAt,
    }) {
      final finished = record(orderIndex: id - 1).withIdentity(id).finished(
        importedCount: imported,
        duplicateSkippedCount: duplicates,
        errorRowCount: errors,
      );
      return revertedAt == null ? finished : finished.revert(revertedAt);
    }

    test('mở ra ở trạng thái đang chạy và chưa kết thúc', () {
      final fresh = session();
      expect(fresh.status, ImportSessionStatus.inProgress);
      expect(fresh.isFinished, isFalse);
      expect(fresh.completedAt, isNull);
    });

    test('hoàn tất và huỷ đều là trạng thái kết thúc, có mốc thời gian', () {
      expect(session().complete(finishedAt).status, ImportSessionStatus.completed);
      expect(session().complete(finishedAt).isFinished, isTrue);
      expect(session().cancel(finishedAt).status, ImportSessionStatus.cancelled);
      expect(session().cancel(finishedAt).completedAt, finishedAt);
    });

    test('cộng dồn ba bộ đếm từ các bản ghi con', () {
      final withFiles = session().withFileRecords(<ImportFileRecord>[
        child(id: 1, imported: 100, duplicates: 5, errors: 1),
        child(id: 2, imported: 50, duplicates: 0, errors: 2),
      ]);
      expect(withFiles.importedCount, 150);
      expect(withFiles.duplicateSkippedCount, 5);
      expect(withFiles.errorRowCount, 3);
    });

    test('lượt chưa có file nào thì mọi bộ đếm bằng 0', () {
      expect(session().importedCount, 0);
      expect(session().errorRowCount, 0);
    });

    test('chỉ coi là đã hoàn tác hết khi mọi bản ghi con đều đã hoàn tác', () {
      final partial = session().withFileRecords(<ImportFileRecord>[
        child(id: 1, imported: 10, revertedAt: finishedAt),
        child(id: 2, imported: 10),
      ]);
      expect(partial.isFullyReverted, isFalse);

      final all = session().withFileRecords(<ImportFileRecord>[
        child(id: 1, imported: 10, revertedAt: finishedAt),
        child(id: 2, imported: 10, revertedAt: finishedAt),
      ]);
      expect(all.isFullyReverted, isTrue);
    });

    test('lượt rỗng không phải là lượt đã hoàn tác hết', () {
      expect(session().isFullyReverted, isFalse);
    });

    test('danh sách bản ghi con không sửa được từ bên ngoài', () {
      final withFiles = session().withFileRecords(<ImportFileRecord>[
        child(id: 1, imported: 1),
      ]);
      expect(
        () => withFiles.fileRecords.add(child(id: 2)),
        throwsUnsupportedError,
      );
    });

    test('bằng nhau theo định danh lượt', () {
      expect(session(), ImportSession.started(finishedAt).withIdentity(1));
      expect(session(), isNot(ImportSession.started(startedAt).withIdentity(2)));
    });
  });

  group('ImportErrorRow', () {
    test('giữ nguyên dòng ngắn', () {
      final row = ImportErrorRow.from(
        recordId: 1,
        sourceLineNumber: 7,
        rawLine: 'a,b,c',
        reason: 'Thiếu cột số tiền',
      );
      expect(row.rawExcerpt, 'a,b,c');
      expect(row.sourceLineNumber, 7);
      expect(row.reason, 'Thiếu cột số tiền');
    });

    test('cắt dòng quá dài và đánh dấu bằng dấu lược', () {
      final long = 'x' * 500;
      final row = ImportErrorRow.from(
        recordId: 1,
        sourceLineNumber: 1,
        rawLine: long,
        reason: 'r',
      );
      expect(row.rawExcerpt.length, ImportErrorRow.maxExcerptLength + 1);
      expect(row.rawExcerpt.endsWith('…'), isTrue);
    });

    test('excerptOf là phép cắt luỹ đẳng — cắt lại không mất thêm ký tự', () {
      // ParseError cắt một lần ở phía isolate; nếu phía luồng chính cắt lại thì
      // trích đoạn sẽ bị ăn mất ký tự và sinh dấu lược đôi.
      final once = ImportErrorRow.excerptOf('y' * 500);
      expect(ImportErrorRow.excerptOf(once), once);
    });

    test('dòng đúng bằng ngưỡng thì không bị cắt', () {
      final exact = 'z' * ImportErrorRow.maxExcerptLength;
      expect(ImportErrorRow.excerptOf(exact), exact);
    });
  });
}
