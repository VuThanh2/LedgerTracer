import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/settings/app_lock/app_lock_use_case.dart';
import 'package:ledger_tracer/application/settings/reset_app/reset_app_use_case.dart';
import 'package:ledger_tracer/presentation/settings/bloc/app_lock_bloc.dart';
import 'package:ledger_tracer/presentation/settings/bloc/app_lock_event.dart';
import 'package:ledger_tracer/presentation/settings/bloc/app_lock_state.dart';
import 'package:ledger_tracer/presentation/settings/bloc/settings_bloc.dart';
import 'package:ledger_tracer/presentation/settings/bloc/settings_event.dart';

import '_support/presentation_fixtures.dart';

void main() {
  late FakeDatabase db;
  late FakeAppDataStore store;
  late FakeBiometricAuthenticator biometric;
  late AppLockUseCase appLock;

  setUp(() {
    db = FakeDatabase();
    store = FakeAppDataStore();
    biometric = FakeBiometricAuthenticator();
    appLock = AppLockUseCase(
      settings: db.settings,
      hasher: const FakePinHasher(),
      biometric: biometric,
    );
  });

  AppLockBloc buildLock() => AppLockBloc(
    appLock: appLock,
    resetApp: ResetAppUseCase(store: store),
  );

  SettingsBloc buildSettings() => SettingsBloc(appLock: appLock);

  group('cổng khoá', () {
    test('khoá tắt thì vào thẳng', () async {
      final bloc = buildLock();
      bloc.add(const AppLockChecked());
      final state = await bloc.stream.firstWhere(
        (state) => state.gate != AppLockGate.unknown,
      );
      expect(state.gate, AppLockGate.unlocked);
      await bloc.close();
    });

    test('khoá bật thì chặn, và chỉ đúng PIN mới mở', () async {
      await appLock.enableLock('2468');

      final bloc = buildLock();
      bloc.add(const AppLockChecked());
      var state = await bloc.stream.firstWhere(
        (state) => state.gate != AppLockGate.unknown,
      );
      expect(state.gate, AppLockGate.locked);

      bloc.add(const AppLockPinSubmitted('1111'));
      state = await bloc.stream.firstWhere((state) => state.pinError != null);
      expect(state.gate, AppLockGate.locked);
      // Câu chữ không nói bí mật sai ở chỗ nào.
      expect(state.pinError, isNot(contains('2468')));

      bloc.add(const AppLockPinSubmitted('2468'));
      state = await bloc.stream.firstWhere(
        (state) => state.gate == AppLockGate.unlocked,
      );
      expect(state.pinError, isNull);
      await bloc.close();
    });

    test(
      'nút sinh trắc học chỉ hiện khi đã bật **và** thiết bị còn hỗ trợ',
      () async {
        await appLock.enableLock('2468');
        biometric.available = true;
        await appLock.setBiometric(true);

        var bloc = buildLock();
        bloc.add(const AppLockChecked());
        var state = await bloc.stream.firstWhere(
          (state) => state.gate != AppLockGate.unknown,
        );
        expect(state.canUseBiometric, isTrue);
        await bloc.close();

        // Người dùng tháo hết vân tay khỏi thiết bị: nút phải biến mất, không
        // phải hiện ra rồi báo lỗi sau khi bấm.
        biometric.available = false;
        bloc = buildLock();
        bloc.add(const AppLockChecked());
        state = await bloc.stream.firstWhere(
          (state) => state.gate != AppLockGate.unknown,
        );
        expect(state.biometricEnabled, isTrue);
        expect(state.canUseBiometric, isFalse);
        await bloc.close();
      },
    );

    test('cảm biến không nhận thì không phải lỗi — PIN vẫn ở đó', () async {
      await appLock.enableLock('2468');
      biometric
        ..available = true
        ..succeeds = false;
      await appLock.setBiometric(true);

      final bloc = buildLock();
      bloc.add(const AppLockChecked());
      await bloc.stream.firstWhere((state) => state.canUseBiometric);

      bloc.add(const AppLockBiometricRequested());
      final state = await bloc.stream.firstWhere(
        (state) => !state.isVerifying && state.error != null,
      );
      expect(state.gate, AppLockGate.locked);
      await bloc.close();
    });
  });

  group('quên PIN', () {
    test('phải gõ đúng chuỗi xác nhận mới xoá được', () async {
      await appLock.enableLock('2468');

      final bloc = buildLock();
      bloc.add(const AppLockChecked());
      await bloc.stream.firstWhere((state) => state.gate == AppLockGate.locked);

      bloc.add(const AppLockResetRequested());
      await bloc.stream.firstWhere((state) => state.isResetPending);

      // Gõ sai: nút không sáng, và lệnh xoá bị chặn ngay cả khi vẫn gửi tới.
      bloc.add(const AppLockResetConfirmationTyped('xoa'));
      var state = await bloc.stream.firstWhere(
        (state) => state.resetConfirmationText == 'xoa',
      );
      expect(state.canConfirmReset, isFalse);

      bloc.add(const AppLockResetConfirmed());
      await Future<void>.delayed(Duration.zero);
      expect(store.wiped, isFalse);

      bloc.add(
        const AppLockResetConfirmationTyped(
          AppLockState.resetConfirmationPhrase,
        ),
      );
      state = await bloc.stream.firstWhere((state) => state.canConfirmReset);

      bloc.add(const AppLockResetConfirmed());
      state = await bloc.stream.firstWhere(
        (state) => state.gate == AppLockGate.unlocked,
      );
      expect(store.wiped, isTrue);
      // Xoá xong thì vào được ngay: thiết lập — và mã PIN đã quên — đã biến mất
      // cùng dữ liệu. Chừa lại nó thì use case tự triệt tiêu.
      expect(state.error, isNotNull);
      await bloc.close();
    });
  });

  group('cấu hình khoá ở Thiết lập', () {
    test('hai ô mã PIN không khớp thì chặn ngay, không gọi xuống dưới', () async {
      final bloc = buildSettings();
      bloc.add(const SettingsStarted());
      await bloc.stream.firstWhere((state) => state.status.isReady);

      bloc.add(const SettingsLockEnabled(pin: '2468', confirmPin: '2469'));
      final state = await bloc.stream.firstWhere(
        (state) => state.pinError != null,
      );
      expect(state.appLockEnabled, isFalse);
      expect((await db.settings.load()).appLockEnabled, isFalse);
      await bloc.close();
    });

    test('đổi PIN đòi đúng PIN hiện tại', () async {
      await appLock.enableLock('2468');

      final bloc = buildSettings();
      bloc.add(const SettingsStarted());
      await bloc.stream.firstWhere((state) => state.status.isReady);

      bloc.add(
        const SettingsPinChanged(
          currentPin: '0000',
          newPin: '1357',
          confirmPin: '1357',
        ),
      );
      await bloc.stream.firstWhere((state) => state.pinError != null);
      expect((await appLock.unlockWithPin('2468')).valueOrNull, isTrue);

      bloc.add(
        const SettingsPinChanged(
          currentPin: '2468',
          newPin: '1357',
          confirmPin: '1357',
        ),
      );
      await bloc.stream.firstWhere(
        (state) => state.pinError == null && state.notice != null,
      );
      expect((await appLock.unlockWithPin('1357')).valueOrNull, isTrue);
      await bloc.close();
    });

    test(
      'lỗi không phải sai PIN thì xoá câu "sai mã PIN" của lần trước',
      () async {
        await appLock.enableLock('2468');

        final bloc = buildSettings();
        bloc.add(const SettingsStarted());
        await bloc.stream.firstWhere((state) => state.status.isReady);

        // Lần một: sai PIN hiện tại — câu lỗi treo dưới ô nhập.
        bloc.add(
          const SettingsPinChanged(
            currentPin: '0000',
            newPin: '1357',
            confirmPin: '1357',
          ),
        );
        await bloc.stream.firstWhere((state) => state.pinError != null);

        // Lần hai: bật khoá trong khi khoá **đang bật** — một vi phạm luật, không
        // phải sai PIN. Câu lỗi cũ mà còn treo thì nó đang nói về quá khứ.
        bloc.add(
          const SettingsLockEnabled(pin: '1357', confirmPin: '1357'),
        );
        final state = await bloc.stream.firstWhere(
          (state) => !state.isSubmitting && state.notice != null,
        );
        expect(state.pinError, isNull);
        await bloc.close();
      },
    );

    test('mục Chẩn đoán chỉ lộ ra sau đủ số lần chạm', () async {
      final bloc = buildSettings();
      bloc.add(const SettingsStarted());
      await bloc.stream.firstWhere((state) => state.status.isReady);

      for (var i = 0; i < bloc.hiddenTapsRequired - 1; i++) {
        bloc.add(const SettingsHiddenEntryTapped());
      }
      await bloc.stream.firstWhere(
        (state) => state.hiddenTapCount == bloc.hiddenTapsRequired - 1,
      );
      expect(bloc.state.diagnosticsUnlocked, isFalse);

      bloc.add(const SettingsHiddenEntryTapped());
      final state = await bloc.stream.firstWhere(
        (state) => state.diagnosticsUnlocked,
      );
      expect(state.notice, isNotNull);
      await bloc.close();
    });
  });
}
