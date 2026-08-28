import 'dart:convert';
import 'dart:typed_data';

import 'package:sqflite_common/sqlite_api.dart';

import '../../application/settings/contracts/app_data_store.dart';
import 'app_database.dart';
import 'schema.dart';

/// Một bản sao lưu đã giải mã và đã qua kiểm tra.
///
/// Giữ cả phần mô tả lẫn dữ liệu để một khối chỉ phải giải mã JSON đúng một lần
/// cho cả hai bước của UC-13 (kiểm tra, rồi ghi đè).
final class _BackupDocument {
  const _BackupDocument({required this.manifest, required this.tables});

  final BackupManifest manifest;
  final Map<String, Object?> tables;
}

/// Hiện thực [AppDataStore]: toàn bộ dữ liệu cục bộ nhìn như một khối duy nhất
/// (UC-12, UC-13).
///
/// Khối đó là một tài liệu JSON gồm nguyên văn các dòng của từng bảng. Chọn JSON
/// chứ không phải copy thẳng file cơ sở dữ liệu là vì ba lý do:
///
/// * file `.db` trên Web không phải một file — nó nằm trong kho lưu trữ của
///   trình duyệt, nên "copy file" không có nghĩa gì ở đó;
/// * bản sao lưu phải đọc lại được bởi một phiên bản ứng dụng có lược đồ mới hơn,
///   và một tài liệu có tên cột chịu được việc thêm cột, còn một file nhị phân
///   thì không;
/// * bản sao lưu cần **kiểm tra được** trước khi ghi đè (UC-13 bước 3), mà kiểm
///   một tài liệu thì rẻ hơn hẳn mở thử một cơ sở dữ liệu thứ hai.
///
/// Giới hạn phải nói thẳng: cả bản sao lưu nằm trong bộ nhớ một lúc. Điều đó là
/// **bắt buộc** chứ không phải cẩu thả — AES-GCM mã hoá và xác thực trọn một
/// khối, nên dù đọc dữ liệu theo luồng thì khối bytes cuối cùng vẫn phải hiện
/// diện đầy đủ để có một thẻ xác thực duy nhất cho cả file. Phần đọc từ cơ sở dữ
/// liệu vẫn đi **theo trang** để ít nhất không giữ hai bản sao cùng lúc.
final class SqliteAppDataStore implements AppDataStore {
  const SqliteAppDataStore({required this._db, required this._now});

  /// Nhãn nhận dạng nội dung, tách biệt với nhãn nhị phân của file đã mã hoá:
  /// một khối giải mã thành công nhưng không phải bản sao lưu vẫn phải bị từ
  /// chối.
  static const String _format = 'ledger_tracer.backup';
  static const int _version = 1;

  /// Số dòng đọc lên mỗi lần khi chụp dữ liệu.
  static const int _pageSize = 2000;

  final AppDatabase _db;
  final DateTime Function() _now;

  @override
  Future<Uint8List> snapshot() async {
    final counts = <String, int>{
      for (final table in LedgerSchema.tablesInBackupOrder)
        table: await _countOf(table),
    };

    final buffer = StringBuffer()
      ..write('{"format":${jsonEncode(_format)}')
      ..write(',"version":$_version')
      ..write(',"schemaVersion":${LedgerSchema.version}')
      ..write(',"createdAt":${jsonEncode(_now().toUtc().toIso8601String())}')
      ..write(',"counts":${jsonEncode(counts)}')
      ..write(',"tables":{');

    for (var index = 0; index < LedgerSchema.tablesInBackupOrder.length; index++) {
      final table = LedgerSchema.tablesInBackupOrder[index];
      if (index > 0) buffer.write(',');
      buffer
        ..write(jsonEncode(table))
        ..write(':[');
      await _writeRows(buffer, table);
      buffer.write(']');
    }

    buffer.write('}}');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  @override
  Future<BackupManifest> inspect(Uint8List plain) async =>
      _validate(plain).manifest;

  /// Kiểm một khối đã giải mã và trả về **cả** phần mô tả lẫn các bảng đã đọc.
  ///
  /// Tách ra để việc khôi phục không phải giải mã JSON hai lần. Với một bản sao
  /// lưu vài trăm nghìn giao dịch, lần giải mã thứ hai không chỉ tốn thời gian —
  /// nó dựng thêm một cây object đầy đủ nữa ngay cạnh cây thứ nhất, trên đúng
  /// đường đi vốn đã phải giữ cả bản sao lưu trong bộ nhớ.
  _BackupDocument _validate(Uint8List plain) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain, allowMalformed: true));
    } on FormatException catch (error) {
      throw CorruptBackupException(
        'Nội dung bản sao lưu không đọc được: ${error.message}',
      );
    }

    if (decoded is! Map<String, Object?> || decoded['format'] != _format) {
      throw const CorruptBackupException();
    }
    final version = decoded['version'];
    if (version is! int || version > _version) {
      throw const CorruptBackupException(
        'Bản sao lưu được tạo bởi một phiên bản ứng dụng mới hơn.',
      );
    }
    final createdAt = DateTime.tryParse(
      decoded['createdAt'] is String ? decoded['createdAt']! as String : '',
    );
    final tables = decoded['tables'];
    final counts = decoded['counts'];
    if (createdAt == null ||
        tables is! Map<String, Object?> ||
        counts is! Map<String, Object?>) {
      throw const CorruptBackupException();
    }
    // Thiếu một bảng là bản sao lưu dở dang; ghi đè bằng nó sẽ để lại một cơ sở
    // dữ liệu mất một phần dữ liệu mà không có gì báo (UC-13).
    for (final table in LedgerSchema.tablesInBackupOrder) {
      if (tables[table] is! List<Object?>) throw const CorruptBackupException();
    }

    return _BackupDocument(
      manifest: BackupManifest(
        createdAt: createdAt,
        accountCount: _countIn(counts, LedgerSchema.bankAccount),
        transactionCount: _countIn(counts, LedgerSchema.transaction),
      ),
      tables: tables,
    );
  }

  /// Ghi đè **toàn bộ** dữ liệu nghiệp vụ bằng khối này (UC-13 bước 4).
  ///
  /// Chỉ hỗ trợ ghi đè, không hợp nhất: cả ba tình huống khôi phục thực tế (cài
  /// lại ứng dụng, mất thiết bị, reset do quên PIN) đều diễn ra trên một ứng dụng
  /// trống, nơi ghi đè và hợp nhất cho cùng kết quả.
  ///
  /// Toàn bộ nằm trong **một** transaction: một lần khôi phục hỏng giữa chừng sẽ
  /// để lại thứ tệ hơn cả dữ liệu cũ lẫn dữ liệu mới — một cơ sở dữ liệu có tài
  /// khoản nhưng không có giao dịch của chúng.
  @override
  Future<void> replaceAll(Uint8List plain) async {
    // Kiểm lại trước khi đụng tới dữ liệu hiện có. Use case đã kiểm ở bước
    // chuẩn bị, nhưng đây là nơi cuối cùng còn có thể từ chối mà không mất gì.
    final tables = _validate(plain).tables;

    await _db.transaction(() async {
      // Xoá từ con lên cha, ghi lại từ cha xuống con: khoá ngoại đang bật, và
      // thứ tự sai sẽ bị chính cơ sở dữ liệu chặn — điều đó là mong muốn.
      for (final table in LedgerSchema.tablesInBackupOrder.reversed) {
        await _db.executor.delete(table);
      }
      for (final table in LedgerSchema.tablesInBackupOrder) {
        final rows = tables[table]! as List<Object?>;
        if (rows.isEmpty) continue;
        final batch = _db.executor.batch();
        for (final row in rows) {
          // Ghi lại nguyên vẹn cả khoá chính: liên kết giữa các bảng là các định
          // danh này, nên để cơ sở dữ liệu cấp định danh mới sẽ cắt đứt mọi quan
          // hệ mà bản sao lưu đang mang.
          batch.insert(table, Map<String, Object?>.from(row! as Map));
        }
        await batch.commit(noResult: true);
      }
    });
  }

  /// Xoá sạch dữ liệu cục bộ, **bao gồm cả thiết lập và mã PIN** (UC-12).
  ///
  /// Phần "bao gồm cả mã PIN" là toàn bộ lý do phương thức này tồn tại: reset là
  /// lối thoát duy nhất khi người dùng quên PIN. Chừa thiết lập lại thì ứng dụng
  /// sau khi reset vẫn khoá bằng đúng mã PIN đã quên.
  @override
  Future<void> wipe() async {
    await _db.transaction(() async {
      for (final table in LedgerSchema.tablesInDeletionOrder) {
        await _db.executor.delete(table);
      }
      // Đưa bộ đếm khoá tự tăng về 0 để ứng dụng sau khi reset thật sự giống một
      // bản vừa cài, thay vì tiếp tục đánh số từ chỗ dữ liệu cũ dừng lại.
      //
      // Bọc lại vì đây là bảng nội bộ của SQLite: nó chỉ tồn tại khi đã có bảng
      // AUTOINCREMENT, và bản dựng SQLite trên từng nền tảng không hứa hẹn gì về
      // nó. Đánh số lại là thứ "có thì tốt"; còn reset là **lối thoát duy nhất**
      // khi người dùng quên PIN, nên để nó đổ vỡ cả transaction vì một chi tiết
      // trang trí là đánh đổi sai hoàn toàn — người dùng sẽ mất luôn đường vào.
      try {
        await _db.executor.execute(
          'DELETE FROM sqlite_sequence WHERE name IN ('
          '${LedgerSchema.tablesInDeletionOrder.map((_) => '?').join(', ')})',
          LedgerSchema.tablesInDeletionOrder,
        );
      } on DatabaseException {
        // Không có bảng đếm nào để dọn; dữ liệu đã sạch, và đó mới là điều quan
        // trọng.
      }
    });
  }

  Future<void> _writeRows(StringBuffer buffer, String table) async {
    var offset = 0;
    var isFirst = true;
    while (true) {
      final rows = await _db.executor.query(
        table,
        // Bắt buộc phải có thứ tự: `LIMIT`/`OFFSET` không có `ORDER BY` thì
        // SQLite không hứa hẹn gì về thứ tự dòng giữa hai trang, và một bản sao
        // lưu bị lặp dòng này rồi mất dòng kia là loại hỏng chỉ lộ ra lúc khôi
        // phục — tức lúc dữ liệu gốc đã không còn. `rowid` dùng được cho mọi
        // bảng ở đây vì bảng nào cũng có khoá chính kiểu INTEGER.
        orderBy: 'rowid',
        limit: _pageSize,
        offset: offset,
      );
      if (rows.isEmpty) return;
      for (final row in rows) {
        if (!isFirst) buffer.write(',');
        buffer.write(jsonEncode(row));
        isFirst = false;
      }
      if (rows.length < _pageSize) return;
      offset += rows.length;
    }
  }

  Future<int> _countOf(String table) async {
    final rows = await _db.executor.rawQuery('SELECT COUNT(*) FROM $table');
    return (rows.first.values.first as int?) ?? 0;
  }

  static int _countIn(Map<String, Object?> counts, String table) {
    final value = counts[table];
    return value is int ? value : 0;
  }
}
