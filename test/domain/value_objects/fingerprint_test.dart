import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/fingerprint.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';

/// Fingerprint trả lời "giao dịch này đã từng được nhập chưa". Nó là **căn cứ
/// duy nhất** của chống trùng, nên hai thứ phải đúng tuyệt đối: cùng dữ liệu
/// luôn cho cùng dấu vân tay, và mỗi thành phần trong tổ hợp đều thật sự làm
/// thay đổi kết quả.
void main() {
  final bookingDate = DateTime.utc(2025, 3, 14);
  const amount = Money(-1500000, Currency.vnd);
  const description = 'CK tien hang';

  Fingerprint sample({
    int accountId = 1,
    DateTime? date,
    Money value = amount,
    String text = description,
  }) => Fingerprint.of(
    accountId: accountId,
    bookingDate: date ?? bookingDate,
    amount: value,
    description: text,
  );

  group('tính ổn định', () {
    test('cùng đầu vào luôn cho cùng dấu vân tay', () {
      expect(sample(), sample());
      expect(sample().hashCode, sample().hashCode);
    });

    test('giá trị là chuỗi hex 16 ký tự', () {
      expect(sample().value, matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('fromStored đi trọn vòng', () {
      final computed = sample();
      expect(Fingerprint.fromStored(computed.value), computed);
    });
  });

  group('mỗi thành phần của tổ hợp đều có tác dụng', () {
    test('đổi tài khoản là đổi dấu vân tay', () {
      // Hai file gán cho hai tài khoản khác nhau không bao giờ được coi là
      // trùng nhau — đó là hai vế của một giao dịch nội bộ.
      expect(sample(accountId: 2), isNot(sample(accountId: 1)));
    });

    test('đổi ngày là đổi dấu vân tay', () {
      expect(sample(date: DateTime.utc(2025, 3, 15)), isNot(sample()));
    });

    test('đổi số tiền là đổi dấu vân tay', () {
      expect(sample(value: const Money(-1500001, Currency.vnd)), isNot(sample()));
    });

    test('đổi chiều tiền là đổi dấu vân tay', () {
      expect(sample(value: const Money(1500000, Currency.vnd)), isNot(sample()));
    });

    test('cùng con số nhưng khác loại tiền là hai giao dịch khác nhau', () {
      expect(sample(value: const Money(-1500000, Currency.usd)), isNot(sample()));
    });

    test('đổi nội dung là đổi dấu vân tay', () {
      expect(sample(text: 'CK tien hang thang 4'), isNot(sample()));
    });
  });

  group('chuẩn hoá nội dung trước khi băm', () {
    test('nội dung khác hoa/thường và dấu vẫn là cùng một giao dịch', () {
      // Ngân hàng xuất lại cùng một sao kê với cách viết khác không được biến
      // dòng cũ thành dòng mới.
      expect(sample(text: 'CK TIEN HANG'), sample(text: 'ck tien hang'));
      expect(sample(text: 'Chuyển khoản'), sample(text: 'CHUYEN KHOAN'));
    });

    test('khoảng trắng thừa không tạo ra giao dịch mới', () {
      expect(sample(text: '  CK   tien  hang '), sample());
    });
  });

  group('phần thời gian', () {
    test('chỉ ngày được tính, giờ phút bị bỏ qua', () {
      expect(
        sample(date: DateTime.utc(2025, 3, 14, 23, 59, 59)),
        sample(date: DateTime.utc(2025, 3, 14)),
      );
    });

    test('ngày một chữ số được đệm 0 nên không nhập nhằng', () {
      // Không đệm thì 2025-1-11 và 2025-11-1 có thể cho cùng chuỗi chính tắc.
      expect(
        sample(date: DateTime.utc(2025, 1, 11)),
        isNot(sample(date: DateTime.utc(2025, 11, 1))),
      );
    });
  });

  test('các tổ hợp trường khác nhau không đụng độ trong một mẫu vừa phải', () {
    // Không phải bằng chứng về chất lượng hàm băm, chỉ là chốt chặn phát hiện
    // sớm nếu ai đó thay hàm băm bằng thứ đụng độ ngay ở quy mô nhỏ.
    final seen = <String>{};
    for (var account = 1; account <= 5; account++) {
      for (var day = 1; day <= 28; day++) {
        for (var cents = 0; cents < 20; cents++) {
          seen.add(
            Fingerprint.of(
              accountId: account,
              bookingDate: DateTime.utc(2025, 1, day),
              amount: Money(cents * 1000, Currency.vnd),
              description: 'row $cents',
            ).value,
          );
        }
      }
    }
    expect(seen.length, 5 * 28 * 20);
  });
}
