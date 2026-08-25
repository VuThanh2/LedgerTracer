import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';

/// Chuẩn hoá xảy ra **một lần lúc nhập** và được lưu thành cột có chỉ mục. Vì
/// vậy thuật toán ở đây phải ổn định: đổi nó mà không tính lại toàn bộ dữ liệu
/// cũ nghĩa là những dòng đã nhập trước bỗng dưng tìm không ra.
void main() {
  group('normalize', () {
    test('hạ chữ thường', () {
      expect(SearchText.normalize('ABC Xyz'), 'abc xyz');
    });

    test('bỏ dấu tiếng Việt ở mọi nguyên âm', () {
      expect(
        SearchText.normalize('Nguyễn Văn Anh chuyển khoản'),
        'nguyen van anh chuyen khoan',
      );
      expect(SearchText.normalize('ưu đãi'), 'uu dai');
      expect(SearchText.normalize('Trường Đại học'), 'truong dai hoc');
    });

    test('đổi đ/Đ thành d', () {
      expect(SearchText.normalize('ĐỖ ĐÌNH'), 'do dinh');
    });

    test('xử lý được cả dạng Unicode tách rời, không chỉ dạng dựng sẵn', () {
      // 'ế' viết bằng 'e' + dấu mũ tổ hợp + dấu sắc tổ hợp.
      const decomposed = 'ế';
      expect(SearchText.normalize(decomposed), 'e');
    });

    test('gộp khoảng trắng liên tiếp và cắt hai đầu', () {
      expect(SearchText.normalize('  a   b \t c  '), 'a b c');
    });

    test('giữ nguyên chữ số và ký tự không dấu khác', () {
      expect(SearchText.normalize('CK 123-456 ATM'), 'ck 123-456 atm');
    });

    test('chuỗi rỗng vẫn chuẩn hoá được', () {
      expect(SearchText.normalize(''), '');
      expect(SearchText.normalize('   '), '');
    });
  });

  group('SearchText.of', () {
    test('ghép tên đối tác với nội dung chuyển khoản', () {
      final text = SearchText.of(
        counterpartyName: 'Trần Thị B',
        description: 'Thanh toán đơn hàng',
      );
      expect(text.value, 'tran thi b thanh toan don hang');
    });

    test('không để lại khoảng trắng thừa khi thiếu tên đối tác', () {
      final text = SearchText.of(description: 'Nội dung');
      expect(text.value, 'noi dung');
    });

    test('tên đối tác toàn khoảng trắng cho cùng kết quả với không có tên', () {
      expect(
        SearchText.of(counterpartyName: '   ', description: 'x').value,
        SearchText.of(description: 'x').value,
      );
    });

    test('cả hai đều rỗng thì kết quả rỗng', () {
      final text = SearchText.of(description: '');
      expect(text.isEmpty, isTrue);
      expect(text.isNotEmpty, isFalse);
    });
  });

  group('contains', () {
    final haystack = SearchText.of(
      counterpartyName: 'Nguyễn Văn A',
      description: 'CK tien hang thang 10',
    );

    test('tìm được khi từ khoá có dấu còn dữ liệu đã bỏ dấu', () {
      expect(haystack.contains(SearchText.query('nguyễn')), isTrue);
    });

    test('tìm được khi từ khoá viết hoa', () {
      expect(haystack.contains(SearchText.query('VAN A')), isTrue);
    });

    test('tìm được cụm nằm giữa chuỗi', () {
      expect(haystack.contains(SearchText.query('tien hang')), isTrue);
    });

    test('từ khoá rỗng khớp mọi thứ — không lọc gì cả', () {
      expect(haystack.contains(SearchText.query('')), isTrue);
      expect(haystack.contains(SearchText.query('   ')), isTrue);
    });

    test('không khớp thì trả false', () {
      expect(haystack.contains(SearchText.query('khong co')), isFalse);
    });
  });

  test('fromStored đi trọn vòng và giữ đẳng thức', () {
    final computed = SearchText.of(
      counterpartyName: 'Lê Đình C',
      description: 'abc',
    );
    expect(SearchText.fromStored(computed.value), computed);
    expect(SearchText.fromStored(computed.value).hashCode, computed.hashCode);
  });

  test('hai cách viết khác nhau của cùng nội dung cho cùng một khoá', () {
    expect(
      SearchText.of(description: 'THANH TOÁN'),
      SearchText.of(description: 'thanh toan'),
    );
  });
}
