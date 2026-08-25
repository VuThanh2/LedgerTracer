import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/settings/app_lock/app_lock_use_case.dart';
import 'package:ledger_tracer/application/settings/backup_restore/backup_restore_dto.dart';
import 'package:ledger_tracer/application/settings/backup_restore/backup_restore_use_case.dart';
import 'package:ledger_tracer/application/settings/reset_app/reset_app_use_case.dart';
import 'package:ledger_tracer/core/result/failure.dart';

import '_support/fake_gateways.dart';
import '_support/fake_repositories.dart';

void main() {
  final now = DateTime.utc(2025, 10, 5, 14, 30, 15);

  group('khoá ứng dụng (UC-12)', () {
    late FakeDatabase db;
    late FakeBiometricAuthenticator biometric;
    late AppLockUseCase appLock;

    setUp(() {
      db = FakeDatabase();
      biometric = FakeBiometricAuthenticator();
      appLock = AppLockUseCase(
        settings: db.settings,
        hasher: const FakePinHasher(),
        biometric: biometric,
      );
    });

    test('mặc định tắt', () async {
      final status = await appLock.status();
      expect(status.valueOrNull!.appLockEnabled, isFalse);
      expect(status.valueOrNull!.biometricEnabled, isFalse);
    });

    test('bật khoá lưu hash chứ không lưu PIN dạng thuần', () async {
      expect((await appLock.enableLock('1234')).isOk, isTrue);
      expect(db.settings.current.appLockEnabled, isTrue);
      expect(db.settings.current.pinHash, isNot('1234'));
      expect(db.settings.current.pinHash, contains('hashed:'));
    });

    test('bật khoá khi đang bật bị chặn — đó là đổi PIN trá hình', () async {
      // Không chặn thì người cầm thiết bị đang mở đặt lại được PIN mà không cần
      // biết PIN hiện tại.
      await appLock.enableLock('1234');
      final result = await appLock.enableLock('0000');

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(db.settings.current.pinHash, 'hashed:1234');
    });

    test('đổi PIN bắt buộc nhập đúng PIN hiện tại', () async {
      await appLock.enableLock('1234');

      final wrong = await appLock.changePin(currentPin: '9999', newPin: '5678');
      expect(wrong.failureOrNull, isA<SecurityFailure>());
      expect(db.settings.current.pinHash, 'hashed:1234');

      final right = await appLock.changePin(currentPin: '1234', newPin: '5678');
      expect(right.isOk, isTrue);
      expect(db.settings.current.pinHash, 'hashed:5678');
    });

    test('tắt khoá bắt buộc nhập đúng PIN hiện tại', () async {
      await appLock.enableLock('1234');

      final wrong = await appLock.disableLock('0000');
      expect(wrong.failureOrNull, isA<SecurityFailure>());
      expect(db.settings.current.appLockEnabled, isTrue);

      final right = await appLock.disableLock('1234');
      expect(right.isOk, isTrue);
      expect(db.settings.current.appLockEnabled, isFalse);
      expect(db.settings.current.pinHash, isNull);
    });

    test('tắt khoá khi khoá vốn đã tắt bị chặn', () async {
      expect(
        (await appLock.disableLock('1234')).failureOrNull,
        isA<ValidationFailure>(),
      );
    });

    test('mở khoá bằng PIN đúng và từ chối PIN sai', () async {
      await appLock.enableLock('1234');
      expect((await appLock.unlockWithPin('1234')).valueOrNull, isTrue);
      expect((await appLock.unlockWithPin('0000')).valueOrNull, isFalse);
    });

    test('khoá đang tắt thì luôn vào được', () async {
      expect((await appLock.unlockWithPin('')).valueOrNull, isTrue);
    });

    group('sinh trắc học', () {
      test('là lớp đặt lên trên PIN, không thay thế PIN', () async {
        await appLock.enableLock('1234');
        expect((await appLock.setBiometric(true)).isOk, isTrue);
        expect(db.settings.current.biometricEnabled, isTrue);
        // PIN vẫn còn: cảm biến hỏng thì vẫn còn đường vào.
        expect(db.settings.current.pinHash, 'hashed:1234');
      });

      test('không bật được khi chưa có khoá', () async {
        expect(
          (await appLock.setBiometric(true)).failureOrNull,
          isA<ValidationFailure>(),
        );
      });

      test('không bật được khi thiết bị không hỗ trợ', () async {
        await appLock.enableLock('1234');
        biometric.available = false;
        final result = await appLock.setBiometric(true);
        expect(result.failureOrNull, isA<UnsupportedOnPlatformFailure>());
        expect(db.settings.current.biometricEnabled, isFalse);
      });

      test('mở khoá bằng sinh trắc học khi đã bật', () async {
        await appLock.enableLock('1234');
        await appLock.setBiometric(true);
        expect((await appLock.unlockWithBiometric()).valueOrNull, isTrue);
        expect(biometric.authenticateCalls, 1);
      });

      test('cảm biến từ chối thì không mở khoá', () async {
        await appLock.enableLock('1234');
        await appLock.setBiometric(true);
        biometric.succeeds = false;
        expect((await appLock.unlockWithBiometric()).valueOrNull, isFalse);
      });

      test('chưa bật thì không dùng được để mở khoá', () async {
        await appLock.enableLock('1234');
        final result = await appLock.unlockWithBiometric();
        expect(result.failureOrNull, isA<UnsupportedOnPlatformFailure>());
        expect(biometric.authenticateCalls, 0);
      });

      test('thiết bị mất hỗ trợ sau khi đã bật thì báo đúng lý do', () async {
        // Trên Web không có sinh trắc học; giao diện phải nói rõ chứ không im.
        await appLock.enableLock('1234');
        await appLock.setBiometric(true);
        biometric.available = false;
        expect(
          (await appLock.unlockWithBiometric()).failureOrNull,
          isA<UnsupportedOnPlatformFailure>(),
        );
      });

      test('trạng thái báo cả việc thiết bị có hỗ trợ hay không', () async {
        biometric.available = false;
        expect(
          (await appLock.status()).valueOrNull!.biometricAvailable,
          isFalse,
        );
      });
    });
  });

  group('sao lưu và khôi phục (UC-13)', () {
    late FakeAppDataStore store;
    late FakeBackupWriter writer;
    late BackupRestoreUseCase backupRestore;

    setUp(() {
      store = FakeAppDataStore(accountCount: 3, transactionCount: 1200);
      writer = FakeBackupWriter();
      backupRestore = BackupRestoreUseCase(
        store: store,
        codec: const FakeBackupCodec(),
        writer: writer,
        now: () => now,
      );
    });

    test('sao lưu mã hoá toàn bộ dữ liệu bằng mật khẩu người dùng đặt', () async {
      final result = await backupRestore.backup(
        const BackupRequest(password: 'mat-khau'),
      );

      expect(result.isOk, isTrue);
      expect(writer.lastBytes, isNotNull);
      // Không có gì đọc được nếu không biết mật khẩu.
      expect(
        () => const FakeBackupCodec().decrypt(writer.lastBytes!, 'sai'),
        throwsA(isA<BackupPasswordException>()),
      );
    });

    test('tên file sao lưu kèm mốc thời gian nên không ghi đè bản trước', () async {
      await backupRestore.backup(const BackupRequest(password: 'p'));
      expect(writer.writtenNames.single, contains('2025-10-05'));
      expect(writer.writtenNames.single, endsWith('.ltb'));
      // Không có dấu hai chấm — nhiều hệ tệp không nhận.
      expect(writer.writtenNames.single.contains(':'), isFalse);
    });

    test('kiểm tra trước khi ghi đè: sai mật khẩu không đụng dữ liệu hiện có', () async {
      await backupRestore.backup(const BackupRequest(password: 'dung'));
      final file = writer.lastBytes!;

      final result = await backupRestore.prepareRestore(
        RestoreRequest(bytes: file, password: 'sai'),
      );

      expect(result.failureOrNull, isA<SecurityFailure>());
      expect(store.restored, isNull);
    });

    test('file hỏng bị phân biệt với sai mật khẩu', () async {
      // Sai mật khẩu thì gõ lại; file hỏng thì phải tìm bản sao lưu khác.
      final rubbish = await const FakeBackupCodec().encrypt(
        Uint8List.fromList(<int>[1, 2, 3]),
        'p',
      );
      final result = await backupRestore.prepareRestore(
        RestoreRequest(bytes: rubbish, password: 'p'),
      );

      expect(result.failureOrNull, isA<ValidationFailure>());
      expect(store.restored, isNull);
    });

    test('kiểm xong trả về mô tả bản sao lưu cho hộp thoại cảnh báo', () async {
      await backupRestore.backup(const BackupRequest(password: 'p'));
      final plan = await backupRestore.prepareRestore(
        RestoreRequest(bytes: writer.lastBytes!, password: 'p'),
      );

      expect(plan.isOk, isTrue);
      expect(plan.valueOrNull!.manifest.accountCount, 3);
      expect(plan.valueOrNull!.manifest.transactionCount, 1200);
      // Vẫn chưa ghi gì: người dùng còn phải xác nhận.
      expect(store.restored, isNull);
    });

    test('chỉ ghi đè sau khi người dùng xác nhận kế hoạch đã kiểm', () async {
      await backupRestore.backup(const BackupRequest(password: 'p'));
      final plan = await backupRestore.prepareRestore(
        RestoreRequest(bytes: writer.lastBytes!, password: 'p'),
      );

      final result = await backupRestore.commitRestore(plan.valueOrNull!);

      expect(result.isOk, isTrue);
      expect(store.restored, isNotNull);
    });

    test('đi trọn vòng: sao lưu rồi khôi phục cho lại đúng dữ liệu', () async {
      final original = await store.snapshot();
      await backupRestore.backup(const BackupRequest(password: 'p'));
      final plan = await backupRestore.prepareRestore(
        RestoreRequest(bytes: writer.lastBytes!, password: 'p'),
      );
      await backupRestore.commitRestore(plan.valueOrNull!);
      expect(store.restored, original);
    });

    test('mật khẩu sao lưu độc lập hoàn toàn với mã PIN khoá ứng dụng', () async {
      // Nếu sao lưu mã hoá bằng chính PIN đã quên thì UC-12 và UC-13 triệt tiêu
      // nhau: quên PIN là mất trắng cả dữ liệu lẫn bản sao lưu.
      final db = FakeDatabase();
      final appLock = AppLockUseCase(
        settings: db.settings,
        hasher: const FakePinHasher(),
        biometric: FakeBiometricAuthenticator(),
      );
      await appLock.enableLock('1234');
      await backupRestore.backup(const BackupRequest(password: 'mat-khau-khac'));

      final withPin = await backupRestore.prepareRestore(
        RestoreRequest(bytes: writer.lastBytes!, password: '1234'),
      );
      expect(withPin.isErr, isTrue);

      final withPassword = await backupRestore.prepareRestore(
        RestoreRequest(bytes: writer.lastBytes!, password: 'mat-khau-khac'),
      );
      expect(withPassword.isOk, isTrue);
    });
  });

  group('reset ứng dụng (UC-12)', () {
    test('xoá sạch dữ liệu cục bộ — lối thoát duy nhất khi quên PIN', () async {
      final store = FakeAppDataStore();
      final resetApp = ResetAppUseCase(store: store);

      final result = await resetApp.execute();

      expect(result.isOk, isTrue);
      expect(store.wiped, isTrue);
    });
  });
}
