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

  group('ImportFileRecord — cộng dồn theo lô', () {
    // Bộ đếm lớn lên cùng nhịp với các dòng được ghi ra, trong cùng một
    // transaction. Đây là thứ giữ cho lịch sử nói đúng sự thật khi tiến trình bị
    // kết liễu giữa chừng: bước chốt cuối lúc đó không chạy.

    test('cộng dồn qua nhiều lô thay vì ghi đè', () {
      final after = record()
          .accumulate(importedCount: 2, duplicateSkippedCount: 1)
          .accumulate(importedCount: 3, errorRowCount: 1);
      expect(after.importedCount, 5);
      expect(after.duplicateSkippedCount, 1);
      expect(after.errorRowCount, 1);
    });

    test('không đụng tới trạng thái — một lô không kết luận được cả file', () {
      // Bản ghi vẫn ở `cancelled` cho tới khi có người còn sống chốt lại, nên
      // chết giữa chừng để lại một file dở dang chứ không phải một file "xong".
      final after = record().accumulate(importedCount: 9);
      expect(after.status, ImportFileStatus.cancelled);
    });

    test('bản ghi đã có dòng thì hoàn tác được ngay, chưa cần chốt', () {
      // Chính chỗ này là bug cũ: bộ đếm chỉ được ghi ở bước chốt, nên một lượt
      // nhập bị kết liễu để lại `importedCount = 0` trong khi bảng Transaction
      // đã có dữ liệu — và `canRevert` khoá luôn, biến các dòng ấy thành mồ côi
      // không xoá được qua UC-03.
      expect(record().withIdentity(7).accumulate(importedCount: 1).canRevert,
          isTrue);
    });

    test('giữ nguyên nguồn gốc và thứ tự chọn file', () {
      final after = record(orderIndex: 2).accumulate(importedCount: 1);
      expect(after.orderIndex, 2);
      expect(after.sessionId, 1);
      expect(after.accountId, 2);
    });

    test('từ chối phần cộng thêm âm', () {
      expect(
        () => record().accumulate(importedCount: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ImportFileRecord — chốt kết quả', () {
    test('không dòng lỗi nào thì là hoàn tất', () {
      final done = record()
          .accumulate(importedCount: 120, duplicateSkippedCount: 5)
          .finished();
      expect(done.status, ImportFileStatus.completed);
      expect(done.importedCount, 120);
      expect(done.duplicateSkippedCount, 5);
    });

    test('có dòng lỗi thì là hỏng một phần, không phải hỏng cả file', () {
      // Một dòng hỏng không được làm dừng các dòng còn lại.
      final done = record()
          .accumulate(importedCount: 118, errorRowCount: 2)
          .finished();
      expect(done.status, ImportFileStatus.partiallyFailed);
    });

    test('bị huỷ thì là đã huỷ, kể cả khi có dòng lỗi', () {
      final done = record()
          .accumulate(importedCount: 40, errorRowCount: 3)
          .finished(wasCancelled: true);
      expect(done.status, ImportFileStatus.cancelled);
      // Phần đã xử lý xong trước thời điểm huỷ vẫn được giữ lại.
      expect(done.importedCount, 40);
    });

    test('file toàn dòng trùng vẫn là hoàn tất', () {
      final done = record()
          .accumulate(duplicateSkippedCount: 200)
          .finished();
      expect(done.status, ImportFileStatus.completed);
    });

    test('người dùng bỏ qua file là một trạng thái riêng, không phải lỗi đọc', () {
      expect(record().skipped().status, ImportFileStatus.skipped);
    });

    test('chốt kết quả không đụng tới thứ tự chọn và nguồn gốc', () {
      final done = record(orderIndex: 3)
          .accumulate(importedCount: 1)
          .finished();
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
        .accumulate(importedCount: imported)
        .finished();

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
      final finished = record(orderIndex: id - 1)
          .withIdentity(id)
          .accumulate(
            importedCount: imported,
            duplicateSkippedCount: duplicates,
            errorRowCount: errors,
          )
          .finished();
      return revertedAt == null ? finished : finished.revert(revertedAt);
    }

    test('mở ra ở trạng thái đang chạy và chưa kết thúc', () {
      final fresh = session();
      expect(fresh.status, ImportSessionStatus.inProgress);
      expect(fresh.isFinished, isFalse);
      expect(fresh.completedAt, isNull);
    });

    test('gián đoạn là trạng thái kết thúc, tách hẳn khỏi huỷ', () {
      // Huỷ là phán quyết của người dùng và họ biết mình dừng ở đâu; gián đoạn
      // thì họ không biết gì cả, nên giao diện phải nói hai điều khác nhau.
      final orphan = session().interrupt();
      expect(orphan.status, ImportSessionStatus.interrupted);
      expect(orphan.isFinished, isTrue);
    });

    test('gián đoạn không bịa ra mốc kết thúc', () {
      // Không ai biết lượt nhập chết lúc nào. `null` đọc được đúng nghĩa "không
      // có thời điểm kết thúc nào được ghi lại"; một mốc bịa ra thì không.
      expect(session().interrupt().completedAt, isNull);
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
