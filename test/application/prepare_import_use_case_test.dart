import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_dto.dart';
import 'package:ledger_tracer/application/import/prepare_import/prepare_import_use_case.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/domain/value_objects/statement_format.dart';

import '_support/fake_gateways.dart';
import '_support/fake_repositories.dart';
import '_support/seed.dart';

/// UC-02 bước 2–4: người dùng chỉ chọn file mình đang có; việc biết đó là định
/// dạng gì, và file này có đúng của tài khoản đích không, là việc của ứng dụng.
/// **Người dùng không phải gõ số tài khoản ở bất kỳ đâu.**
void main() {
  late FakeDatabase db;
  late Seed seed;
  late PrepareImportUseCase prepareImport;
  late int accountA;

  setUp(() async {
    db = FakeDatabase();
    seed = Seed(db);
    prepareImport = PrepareImportUseCase(
      accounts: db.accounts,
      detector: const FakeFormatDetector(),
      parserFactory: FakeParserFactory(),
    );
    accountA = await seed.account('Vietinbank vận hành');
  });

  PickedFile pick(String name, {String? accountNumber, int rows = 1}) =>
      PickedFile(
        fileName: name,
        bytes: FakeStatementParser.file(<String>[
          if (accountNumber != null)
            '${FakeStatementParser.accountNumberPrefix}$accountNumber',
          for (var i = 0; i < rows; i++)
            FakeStatementParser.line(date: '2025-03-1$i', amount: -1000),
        ]),
      );

  Future<List<InspectedFile>> inspect(List<PickedFile> files) async {
    final result = await prepareImport.inspect(files);
    expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
    return result.valueOrNull!;
  }

  group('nhận diện định dạng (bước 2)', () {
    test('nhận ra cả bốn định dạng được hỗ trợ', () async {
      final files = await inspect(<PickedFile>[
        pick('sao-ke.csv'),
        pick('sao-ke.xlsx'),
        pick('sao-ke.sta'),
        pick('sao-ke.json'),
      ]);
      expect(
        files.map((f) => (f as RecognizedFile).format).toList(),
        <StatementFormat>[
          StatementFormat.csv,
          StatementFormat.excel,
          StatementFormat.mt940,
          StatementFormat.json,
        ],
      );
    });

    test('file không nhận ra được về như dữ liệu, không làm hỏng cả lượt', () async {
      // Một file lạ trong nhóm người dùng chọn không được kéo theo những file
      // còn lại.
      final files = await inspect(<PickedFile>[
        pick('sao-ke.pdf'),
        pick('sao-ke.csv'),
      ]);

      expect(files[0], isA<UnrecognizedFile>());
      expect((files[0] as UnrecognizedFile).reason, contains('sao-ke.pdf'));
      expect(files[1], isA<RecognizedFile>());
    });

    test('giữ nguyên tên file và bytes để chuyển thẳng sang bước nhập', () async {
      final picked = pick('sao-ke.csv', rows: 3);
      final files = await inspect(<PickedFile>[picked]);
      final recognized = files.single as RecognizedFile;
      expect(recognized.fileName, 'sao-ke.csv');
      expect(recognized.bytes, picked.bytes);
    });

    test('danh sách rỗng cho kết quả rỗng', () async {
      expect(await inspect(<PickedFile>[]), isEmpty);
    });
  });

  group('đọc số tài khoản nhúng trong file (bước 4)', () {
    test('đọc được khi định dạng có mang, và chuẩn hoá luôn', () async {
      final files = await inspect(<PickedFile>[
        pick('sao-ke.sta', accountNumber: '1234-5678 90'),
      ]);
      final recognized = files.single as RecognizedFile;
      expect(recognized.carriesAccountNumber, isTrue);
      expect(recognized.embeddedAccountNumber, '1234567890');
    });

    test('định dạng không mang số thì không có gì để đối chiếu', () async {
      final files = await inspect(<PickedFile>[pick('sao-ke.csv')]);
      expect((files.single as RecognizedFile).carriesAccountNumber, isFalse);
    });

    test('số tài khoản rác được coi như file không mang số', () async {
      final files = await inspect(<PickedFile>[
        pick('sao-ke.sta', accountNumber: '---'),
      ]);
      expect((files.single as RecognizedFile).embeddedAccountNumber, isNull);
    });

    test('chỉ đọc phần đầu file, không đọc hết', () async {
      // Cảnh báo phải hiện ra **trước khi** xử lý nền bắt đầu, nên bước này
      // không được trả giá bằng một lượt đọc toàn bộ file.
      final padding = List<String>.generate(
        5000,
        (i) => FakeStatementParser.line(date: '2025-03-01', amount: -i),
      );
      final buried = PickedFile(
        fileName: 'lon.sta',
        bytes: FakeStatementParser.file(<String>[
          ...padding,
          '${FakeStatementParser.accountNumberPrefix}999',
        ]),
      );
      expect(buried.bytes.length, greaterThan(PrepareImportUseCase.headByteCount));

      final files = await inspect(<PickedFile>[buried]);
      expect((files.single as RecognizedFile).embeddedAccountNumber, isNull);
    });
  });

  group('đối chiếu với tài khoản đích', () {
    Future<AccountAssignmentCheck> check(
      String? accountNumber, {
      int? accountId,
    }) async {
      final files = await inspect(<PickedFile>[
        pick('sao-ke.sta', accountNumber: accountNumber),
      ]);
      final result = await prepareImport.checkAssignment(
        file: files.single as RecognizedFile,
        accountId: accountId ?? accountA,
      );
      expect(result.isOk, isTrue, reason: '${result.failureOrNull}');
      return result.valueOrNull!;
    }

    test('file không mang số thì không có phán quyết nào cần người dùng', () async {
      final verdict = await check(null);
      expect(verdict.verdict, AccountNumberVerdict.fileCarriesNoNumber);
      expect(verdict.needsUserDecision, isFalse);
    });

    test('tài khoản chưa có số thì hệ thống sẽ tự ghi nhận', () async {
      final verdict = await check('1234567890');
      expect(verdict.verdict, AccountNumberVerdict.willLearn);
      expect(verdict.embeddedAccountNumber, '1234567890');
      expect(verdict.needsUserDecision, isFalse);
    });

    test('số khớp thì đi tiếp không hỏi gì', () async {
      await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '1234567890',
      );
      final verdict = await check('1234-5678-90');
      expect(verdict.verdict, AccountNumberVerdict.matches);
      expect(verdict.needsUserDecision, isFalse);
    });

    test('số lệch thì cảnh báo và để người dùng quyết định', () async {
      // Không chặn cứng: ngân hàng có thể cấp lại số, hoặc lần nhập đầu đã học
      // sai.
      await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '1234567890',
      );
      final verdict = await check('9999999999');

      expect(verdict.verdict, AccountNumberVerdict.mismatch);
      expect(verdict.needsUserDecision, isTrue);
      expect(verdict.recordedAccountNumber, '1234567890');
      expect(verdict.embeddedAccountNumber, '9999999999');
    });

    test('đối chiếu là thao tác chỉ đọc, không ghi gì', () async {
      await check('1234567890');
      expect(db.accountRows[accountA]!.hasAccountNumber, isFalse);
    });

    test('tài khoản không tồn tại báo không tìm thấy', () async {
      final files = await inspect(<PickedFile>[
        pick('sao-ke.sta', accountNumber: '123'),
      ]);
      final result = await prepareImport.checkAssignment(
        file: files.single as RecognizedFile,
        accountId: 999999,
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  group('ghi nhận số tài khoản học được', () {
    test('lưu bản đã chuẩn hoá', () async {
      final result = await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '1234-5678 90',
      );
      expect(result.isOk, isTrue);
      expect(db.accountRows[accountA]!.accountNumber, '1234567890');
    });

    test('không ghi đè số đã có — chọn "vẫn nhập" không đổi mốc đối chiếu', () async {
      // Muốn đổi mốc thì người dùng phải sửa tường minh ở màn hình quản lý tài
      // khoản, chứ không phải bằng một tác dụng phụ của việc nhập file.
      await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '1111111111',
      );
      final result = await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '2222222222',
      );

      expect(result.isOk, isTrue);
      expect(db.accountRows[accountA]!.accountNumber, '1111111111');
    });

    test('số không dùng được bị từ chối', () async {
      final result = await prepareImport.learnAccountNumber(
        accountId: accountA,
        accountNumber: '---',
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('tài khoản không tồn tại báo không tìm thấy', () async {
      final result = await prepareImport.learnAccountNumber(
        accountId: 999999,
        accountNumber: '123',
      );
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });

  test('luồng đầy đủ: soi → gán → học → lần sau khớp', () async {
    final files = await inspect(<PickedFile>[
      pick('lan-dau.sta', accountNumber: '1234567890'),
    ]);
    final first = files.single as RecognizedFile;

    final firstCheck = await prepareImport.checkAssignment(
      file: first,
      accountId: accountA,
    );
    expect(firstCheck.valueOrNull!.verdict, AccountNumberVerdict.willLearn);

    await prepareImport.learnAccountNumber(
      accountId: accountA,
      accountNumber: first.embeddedAccountNumber!,
    );

    final later = await inspect(<PickedFile>[
      pick('lan-sau.sta', accountNumber: '1234567890'),
    ]);
    final secondCheck = await prepareImport.checkAssignment(
      file: later.single as RecognizedFile,
      accountId: accountA,
    );
    expect(secondCheck.valueOrNull!.verdict, AccountNumberVerdict.matches);
  });

  test('phần đầu file được cắt đúng khi file ngắn hơn ngưỡng', () async {
    // Cắt sai ở đây sẽ ném chỉ số vượt biên với mọi file nhỏ.
    final tiny = PickedFile(
      fileName: 'nho.sta',
      bytes: Uint8List.fromList(<int>[35, 50, 53, 58, 55]),
    );
    final files = await inspect(<PickedFile>[tiny]);
    expect((files.single as RecognizedFile).embeddedAccountNumber, '7');
  });
}
