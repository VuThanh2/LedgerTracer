import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/app_settings.dart';
import 'package:ledger_tracer/domain/errors/settings_errors.dart';
import 'package:ledger_tracer/domain/value_objects/match_window.dart';

/// PIN là bắt buộc khi bật khoá; sinh trắc học là lớp mở khoá nhanh **đặt lên
/// trên** nó, không phải lựa chọn thay thế. Không có PIN thì cảm biến hỏng là
/// mất đường vào, và cùng dữ liệu đó trên Web không có gì mở được.
void main() {
  group('trạng thái ban đầu', () {
    test('khoá mặc định tắt và không giữ mã PIN nào', () {
      expect(AppSettings.initial.appLockEnabled, isFalse);
      expect(AppSettings.initial.pinHash, isNull);
      expect(AppSettings.initial.biometricEnabled, isFalse);
    });

    test('ngưỡng lệch thời gian mặc định là ±3 ngày', () {
      expect(AppSettings.initial.matchWindow, MatchWindow.standard);
    });
  });

  group('bất biến giữa khoá và PIN', () {
    test('không thể bật khoá mà không có PIN', () {
      expect(
        () => AppSettings(appLockEnabled: true),
        throwsA(isA<PinRequiredError>()),
      );
    });

    test('khoá tắt thì mã PIN truyền vào bị bỏ, không lưu lại', () {
      // Giữ lại hash của một lớp bảo vệ đang tắt là giữ một thứ không ai kiểm.
      final settings = AppSettings(appLockEnabled: false, pinHash: 'hash');
      expect(settings.pinHash, isNull);
    });

    test('khoá tắt thì sinh trắc học cũng tắt theo', () {
      final settings = AppSettings(
        appLockEnabled: false,
        biometricEnabled: true,
      );
      expect(settings.biometricEnabled, isFalse);
    });
  });

  group('bật và tắt khoá', () {
    test('bật khoá lưu hash và giữ nguyên ngưỡng đối soát', () {
      final locked = AppSettings.initial
          .withMatchWindow(MatchWindow(5))
          .enableLock(pinHash: 'hash-1');
      expect(locked.appLockEnabled, isTrue);
      expect(locked.pinHash, 'hash-1');
      expect(locked.matchWindow, MatchWindow(5));
    });

    test('tắt khoá xoá sạch cả PIN lẫn sinh trắc học', () {
      final unlocked = AppSettings.initial
          .enableLock(pinHash: 'hash-1')
          .withBiometric(true)
          .disableLock();
      expect(unlocked.appLockEnabled, isFalse);
      expect(unlocked.pinHash, isNull);
      expect(unlocked.biometricEnabled, isFalse);
    });

    test('tắt khoá không đụng tới ngưỡng đối soát', () {
      // Ngưỡng đối soát không liên quan gì tới bảo mật; mất nó khi tắt khoá là
      // một tác dụng phụ không ai mong đợi.
      final unlocked = AppSettings.initial
          .withMatchWindow(MatchWindow(7))
          .enableLock(pinHash: 'h')
          .disableLock();
      expect(unlocked.matchWindow, MatchWindow(7));
    });
  });

  group('đổi PIN', () {
    test('thay hash mới và giữ nguyên tuỳ chọn sinh trắc học', () {
      final changed = AppSettings.initial
          .enableLock(pinHash: 'old')
          .withBiometric(true)
          .changePin('new');
      expect(changed.pinHash, 'new');
      expect(changed.appLockEnabled, isTrue);
      expect(changed.biometricEnabled, isTrue);
    });

    test('không đổi được PIN khi khoá đang tắt', () {
      expect(
        () => AppSettings.initial.changePin('new'),
        throwsA(isA<AppLockDisabledError>()),
      );
    });
  });

  group('sinh trắc học', () {
    test('bật được khi khoá đang bật', () {
      final settings = AppSettings.initial
          .enableLock(pinHash: 'h')
          .withBiometric(true);
      expect(settings.biometricEnabled, isTrue);
      // PIN vẫn còn nguyên: sinh trắc học đặt lên trên PIN chứ không thay nó.
      expect(settings.pinHash, 'h');
    });

    test('không bật được khi chưa có khoá', () {
      expect(
        () => AppSettings.initial.withBiometric(true),
        throwsA(isA<AppLockDisabledError>()),
      );
    });

    test('tắt sinh trắc học khi khoá đang tắt là lệnh không làm gì', () {
      expect(AppSettings.initial.withBiometric(false).biometricEnabled, isFalse);
    });
  });

  group('ngưỡng đối soát', () {
    test('đổi được mà không đụng tới phần khoá', () {
      final settings = AppSettings.initial
          .enableLock(pinHash: 'h')
          .withMatchWindow(MatchWindow(10));
      expect(settings.matchWindow, MatchWindow(10));
      expect(settings.appLockEnabled, isTrue);
      expect(settings.pinHash, 'h');
    });
  });

  test('đẳng thức theo toàn bộ giá trị — đây là bản ghi đơn nhất', () {
    expect(
      AppSettings.initial.enableLock(pinHash: 'h'),
      AppSettings.initial.enableLock(pinHash: 'h'),
    );
    expect(
      AppSettings.initial.enableLock(pinHash: 'h').hashCode,
      AppSettings.initial.enableLock(pinHash: 'h').hashCode,
    );
    expect(
      AppSettings.initial.enableLock(pinHash: 'h'),
      isNot(AppSettings.initial.enableLock(pinHash: 'other')),
    );
  });

  test('toString không bao giờ để lộ hash của mã PIN', () {
    final text = AppSettings.initial.enableLock(pinHash: 'secret-hash').toString();
    expect(text.contains('secret-hash'), isFalse);
  });
}
