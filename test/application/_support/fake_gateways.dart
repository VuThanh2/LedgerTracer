import 'dart:convert';
import 'dart:typed_data';

import 'package:ledger_tracer/application/export/export_dataset/export_dataset_dto.dart';
import 'package:ledger_tracer/application/import/contracts/parse_error.dart';
import 'package:ledger_tracer/application/import/contracts/parsed_row.dart';
import 'package:ledger_tracer/application/import/contracts/statement_parser.dart';
import 'package:ledger_tracer/application/settings/app_lock/app_lock_use_case.dart';
import 'package:ledger_tracer/application/settings/backup_restore/backup_restore_dto.dart';
import 'package:ledger_tracer/application/settings/contracts/app_data_store.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

/// Một định dạng sao kê giả, đủ thật để test cả đường thành công lẫn đường lỗi.
///
/// Mỗi dòng là `ngày;số tiền;tên đối tác;nội dung`. Dòng bắt đầu bằng `!` là
/// dòng hỏng, dòng bắt đầu bằng `#25:` khai báo số tài khoản nhúng trong file —
/// đúng vai trò của tag `:25:` trong MT940.
final class FakeStatementParser implements StatementParser {
  const FakeStatementParser(this.format, {this.explodeOnParse = false});

  @override
  final StatementFormat format;

  /// File hỏng tới mức không tách được dòng nào.
  final bool explodeOnParse;

  static const String accountNumberPrefix = '#25:';

  static String line({
    required String date,
    required int amount,
    String counterparty = 'Doi tac',
    String description = 'Noi dung',
  }) => '$date;$amount;$counterparty;$description';

  static String brokenLine([String reason = 'khong doc duoc']) => '!$reason';

  static Uint8List file(List<String> lines) =>
      Uint8List.fromList(utf8.encode(lines.join('\n')));

  @override
  Iterable<ParseLineResult> parseLines(Uint8List bytes) sync* {
    if (explodeOnParse) throw const FormatException('file hỏng hoàn toàn');
    final lines = utf8.decode(bytes).split('\n');
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final lineNumber = i + 1;
      if (raw.isEmpty || raw.startsWith(accountNumberPrefix)) continue;
      if (raw.startsWith('!')) {
        yield ParseLineResult.failed(
          ParseError(
            sourceLineNumber: lineNumber,
            rawLine: raw,
            reason: raw.substring(1),
          ),
        );
        continue;
      }
      final parts = raw.split(';');
      yield ParseLineResult.parsed(
        ParsedRow(
          bookingDate: DateTime.parse(parts[0]),
          amount: Money(int.parse(parts[1]), Currency.vnd),
          counterpartyName: parts[2].isEmpty ? null : parts[2],
          description: parts[3],
          sourceLineNumber: lineNumber,
        ),
      );
    }
  }

  @override
  int? estimateRowCount(Uint8List bytes) {
    if (explodeOnParse) return null;
    return utf8
        .decode(bytes)
        .split('\n')
        .where(
          (line) => line.isNotEmpty && !line.startsWith(accountNumberPrefix),
        )
        .length;
  }

  @override
  String? peekAccountNumber(Uint8List head) {
    for (final line in utf8.decode(head, allowMalformed: true).split('\n')) {
      if (line.startsWith(accountNumberPrefix)) {
        return line.substring(accountNumberPrefix.length);
      }
    }
    return null;
  }
}

final class FakeParserFactory implements StatementParserFactory {
  FakeParserFactory({this.explodingFormats = const <StatementFormat>{}});

  final Set<StatementFormat> explodingFormats;

  @override
  StatementParser parserFor(StatementFormat format) => FakeStatementParser(
    format,
    explodeOnParse: explodingFormats.contains(format),
  );
}

/// Nhận diện định dạng theo phần mở rộng, và trả `null` cho thứ không nhận ra.
final class FakeFormatDetector implements StatementFormatDetector {
  const FakeFormatDetector();

  @override
  StatementFormat? detect({
    required String fileName,
    required Uint8List head,
  }) => switch (fileName.split('.').last.toLowerCase()) {
    'csv' => StatementFormat.csv,
    'xlsx' || 'xls' => StatementFormat.excel,
    'sta' || 'mt940' => StatementFormat.mt940,
    'json' => StatementFormat.json,
    _ => null,
  };
}

/// Mã hoá bảng thành một chuỗi đọc được, để test soi thẳng nội dung file xuất.
final class FakeTabularExporter implements TabularExporter {
  const FakeTabularExporter();

  static String decode(Uint8List bytes) => utf8.decode(bytes);

  @override
  Uint8List toBytes(ExportTable table, ExportFormat format) {
    final buffer = StringBuffer()
      ..writeln('format=${format.name}')
      ..writeAll(table.metadata.map((line) => '# $line\n'))
      ..writeln(table.headers.join(';'));
    for (final row in table.rows) {
      buffer.writeln(row.join(';'));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }
}

final class FakeFileSaver implements FileSaver {
  final List<String> savedNames = <String>[];
  final List<Uint8List> savedBytes = <Uint8List>[];

  @override
  Future<SavedFile> save({
    required Uint8List bytes,
    required String suggestedName,
    required ExportFormat format,
  }) async {
    savedNames.add(suggestedName);
    savedBytes.add(bytes);
    return SavedFile(path: '/tmp/$suggestedName', viaBrowserDownload: false);
  }
}

/// "Mã hoá" bằng cách đảo byte và gắn tiền tố mật khẩu — đủ để test phân biệt
/// được đúng/sai mật khẩu mà không kéo theo một thư viện mật mã thật.
final class FakeBackupCodec implements BackupCodec {
  const FakeBackupCodec();

  @override
  Future<Uint8List> encrypt(Uint8List plain, String password) async =>
      Uint8List.fromList(utf8.encode('$password|') + plain);

  @override
  Future<Uint8List> decrypt(Uint8List cipher, String password) async {
    final text = utf8.decode(cipher, allowMalformed: true);
    final separator = text.indexOf('|');
    if (separator < 0 || text.substring(0, separator) != password) {
      throw const BackupPasswordException();
    }
    return Uint8List.fromList(cipher.sublist(separator + 1));
  }
}

final class FakeBackupWriter implements BackupWriter {
  final List<String> writtenNames = <String>[];
  Uint8List? lastBytes;

  @override
  Future<BackupLocation> write(
    Uint8List bytes, {
    required String suggestedName,
  }) async {
    writtenNames.add(suggestedName);
    lastBytes = bytes;
    return BackupLocation(
      path: '/tmp/$suggestedName',
      viaBrowserDownload: false,
    );
  }
}

/// Kho dữ liệu giả cho sao lưu / khôi phục / reset.
///
/// Nội dung là một chuỗi JSON đơn giản; bất kỳ khối bytes nào không đọc được
/// thành đúng hình dạng đó đều bị coi là bản sao lưu hỏng.
final class FakeAppDataStore implements AppDataStore {
  FakeAppDataStore({
    this.accountCount = 2,
    this.transactionCount = 120,
    DateTime? createdAt,
  }) : _createdAt = createdAt ?? DateTime.utc(2025, 8, 1);

  int accountCount;
  int transactionCount;
  final DateTime _createdAt;

  bool wiped = false;
  Uint8List? restored;

  @override
  Future<Uint8List> snapshot() async => Uint8List.fromList(
    utf8.encode(
      '{"createdAt":"${_createdAt.toIso8601String()}",'
      '"accounts":$accountCount,"transactions":$transactionCount}',
    ),
  );

  @override
  Future<BackupManifest> inspect(Uint8List plain) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(plain, allowMalformed: true));
    } on FormatException catch (error) {
      throw CorruptBackupException(error.message);
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['createdAt'] is! String ||
        decoded['accounts'] is! int ||
        decoded['transactions'] is! int) {
      throw const CorruptBackupException();
    }
    return BackupManifest(
      createdAt: DateTime.parse(decoded['createdAt'] as String),
      accountCount: decoded['accounts'] as int,
      transactionCount: decoded['transactions'] as int,
    );
  }

  @override
  Future<void> replaceAll(Uint8List plain) async => restored = plain;

  @override
  Future<void> wipe() async => wiped = true;
}

/// Băm PIN bằng một phép biến đổi hiển nhiên; điều đáng test là **use case có
/// xác thực hay không**, chứ không phải chất lượng hàm băm.
final class FakePinHasher implements PinHasher {
  const FakePinHasher();

  @override
  String hash(String pin) => 'hashed:$pin';

  @override
  bool verify(String pin, String hash) => this.hash(pin) == hash;
}

final class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int authenticateCalls = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> authenticate() async {
    authenticateCalls++;
    return succeeds;
  }
}
