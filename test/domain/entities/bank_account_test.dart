import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/domain/errors/account_errors.dart';

/// Số tài khoản **không phải trường người dùng tự khai**: hệ thống học nó từ file
/// sao kê đầu tiên có mang nó, rồi dùng làm mốc đối chiếu. Vì vậy phép so khớp
/// phải chịu được mọi cách trình bày mà các ngân hàng dùng cho cùng một số.
void main() {
  final createdAt = DateTime.utc(2025, 1, 1);

  BankAccount account({String name = 'Vietinbank vận hành'}) =>
      BankAccount.create(displayName: name, createdAt: createdAt);

  group('tạo tài khoản', () {
    test('cắt khoảng trắng thừa của tên hiển thị', () {
      expect(account(name: '  Quỹ lương  ').displayName, 'Quỹ lương');
    });

    test('từ chối tên rỗng hoặc toàn khoảng trắng', () {
      expect(
        () => account(name: ''),
        throwsA(isA<EmptyAccountNameError>()),
      );
      expect(
        () => account(name: '   '),
        throwsA(isA<EmptyAccountNameError>()),
      );
    });

    test('tài khoản mới chưa có số và chưa được lưu', () {
      final fresh = account();
      expect(fresh.hasAccountNumber, isFalse);
      expect(fresh.isPersisted, isFalse);
      expect(fresh.accountId, isNull);
    });

    test('tên không bắt buộc duy nhất — hai tài khoản trùng tên đều hợp lệ', () {
      expect(account(name: 'Quỹ').displayName, account(name: 'Quỹ').displayName);
    });
  });

  group('đổi tên', () {
    test('giữ nguyên định danh, số tài khoản và ngày tạo', () {
      final saved = account().withIdentity(7).withAccountNumber('12345678');
      final renamed = saved.renamedTo('Tên mới');
      expect(renamed.accountId, 7);
      expect(renamed.accountNumber, '12345678');
      expect(renamed.createdAt, createdAt);
      expect(renamed.displayName, 'Tên mới');
    });

    test('vẫn từ chối tên rỗng', () {
      expect(
        () => account().renamedTo('  '),
        throwsA(isA<EmptyAccountNameError>()),
      );
    });
  });

  group('số tài khoản', () {
    test('chuẩn hoá bằng cách bỏ mọi ký tự phân cách và viết hoa', () {
      expect(BankAccount.normalizeAccountNumber('1234-5678 90'), '1234567890');
      expect(BankAccount.normalizeAccountNumber('vn 12 ab'), 'VN12AB');
      expect(BankAccount.normalizeAccountNumber('  0011.2233  '), '00112233');
    });

    test('từ chối chuỗi không còn ký tự dùng được sau khi chuẩn hoá', () {
      for (final raw in <String>['', '   ', '---', '.  .']) {
        expect(
          () => BankAccount.normalizeAccountNumber(raw),
          throwsA(isA<InvalidAccountNumberError>()),
          reason: 'chuỗi "$raw" phải bị từ chối',
        );
      }
    });

    test('withAccountNumber lưu bản đã chuẩn hoá', () {
      expect(account().withAccountNumber('1234 5678').accountNumber, '12345678');
    });

    test('so khớp bỏ qua khác biệt về cách trình bày', () {
      final saved = account().withAccountNumber('1234-5678');
      expect(saved.matchesAccountNumber('1234 5678'), isTrue);
      expect(saved.matchesAccountNumber('12345678'), isTrue);
      expect(saved.matchesAccountNumber('1234.5678'), isTrue);
    });

    test('so khớp phân biệt hai số thật sự khác nhau', () {
      final saved = account().withAccountNumber('1234-5678');
      expect(saved.matchesAccountNumber('8765-4321'), isFalse);
      // Không cắt bớt: một số dài hơn không được coi là khớp.
      expect(saved.matchesAccountNumber('123456789'), isFalse);
    });

    test('chưa học số nào thì không khớp với bất cứ gì', () {
      // Cảnh báo lệch số chỉ có giá trị từ lần nhập thứ hai trở đi.
      expect(account().matchesAccountNumber('12345678'), isFalse);
    });

    test('so khớp với chuỗi rác trả false thay vì ném', () {
      final saved = account().withAccountNumber('12345678');
      expect(saved.matchesAccountNumber('---'), isFalse);
      expect(saved.matchesAccountNumber(''), isFalse);
    });

    test('xoá được số đã học khi lần nhập đầu gán nhầm file', () {
      final saved = account().withAccountNumber('12345678');
      final cleared = saved.withoutAccountNumber();
      expect(cleared.hasAccountNumber, isFalse);
      expect(cleared.accountNumber, isNull);
      expect(cleared.displayName, saved.displayName);
    });
  });

  group('định danh', () {
    test('withIdentity gắn định danh mà giữ nguyên phần còn lại', () {
      final saved = account().withIdentity(3);
      expect(saved.isPersisted, isTrue);
      expect(saved.accountId, 3);
      expect(saved.displayName, account().displayName);
    });

    test('hai bản ghi cùng định danh là một, dù nội dung đã đổi', () {
      final a = account().withIdentity(3);
      final b = account(name: 'Tên khác').withIdentity(3);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('hai tài khoản chưa lưu không bao giờ bằng nhau', () {
      // Chưa có định danh thì không có căn cứ nào nói chúng là một.
      expect(account(), isNot(account()));
    });

    test('một tài khoản luôn bằng chính nó, kể cả khi chưa lưu', () {
      final fresh = account();
      expect(fresh, fresh);
    });

    test('đã lưu và chưa lưu không bằng nhau, theo cả hai chiều', () {
      final saved = account().withIdentity(3);
      final fresh = account();
      expect(saved, isNot(fresh));
      expect(fresh, isNot(saved));
    });

    test('khác định danh là khác tài khoản', () {
      expect(account().withIdentity(1), isNot(account().withIdentity(2)));
    });
  });
}
