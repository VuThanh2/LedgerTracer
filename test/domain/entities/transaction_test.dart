import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/domain/entities/transaction.dart';
import 'package:ledger_tracer/domain/services/match_predicate.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/domain/value_objects/search_text.dart';

/// Hai cột dẫn xuất — searchText và fingerprint — được tính **một lần lúc nhập**
/// và phải được **tính lại khi sửa tay**. Quên tính lại thì bản đã sửa vừa tìm
/// không ra vừa bị coi là giao dịch mới ở lần nhập sau.
void main() {
  final importedAt = DateTime.utc(2025, 4, 1, 10, 30);

  Transaction imported({
    int accountId = 1,
    DateTime? bookingDate,
    Money amount = const Money(-250000, Currency.vnd),
    String? counterpartyName = 'Nguyễn Văn A',
    String description = 'CK tien hang',
    int? sourceLineNumber = 12,
  }) => Transaction.imported(
    accountId: accountId,
    bookingDate: bookingDate ?? DateTime.utc(2025, 3, 20, 14, 5),
    amount: amount,
    counterpartyName: counterpartyName,
    description: description,
    importFileRecordId: 99,
    sourceLineNumber: sourceLineNumber,
    importedAt: importedAt,
  );

  group('nhập từ file', () {
    test('cắt ngày ghi nhận về đúng ngày, bỏ phần giờ', () {
      expect(imported().bookingDate, DateTime.utc(2025, 3, 20));
    });

    test('tách bạch thời điểm nhập với ngày ghi nhận', () {
      // Sao kê được tải về và nhập vào hàng tuần sau khi giao dịch xảy ra.
      final tx = imported();
      expect(tx.importedAt, importedAt);
      expect(tx.bookingDate, isNot(tx.importedAt));
    });

    test('tính sẵn searchText từ tên đối tác và nội dung', () {
      expect(imported().searchText.value, 'nguyen van a ck tien hang');
    });

    test('tính sẵn fingerprint khớp với dữ liệu của chính nó', () {
      final tx = imported();
      final same = imported();
      expect(tx.fingerprint, same.fingerprint);
    });

    test('tên đối tác rỗng hoặc toàn khoảng trắng được lưu thành null', () {
      expect(imported(counterpartyName: '').counterpartyName, isNull);
      expect(imported(counterpartyName: '   ').counterpartyName, isNull);
      expect(imported(counterpartyName: null).counterpartyName, isNull);
    });

    test('tên đối tác được cắt khoảng trắng hai đầu', () {
      expect(imported(counterpartyName: '  Trần B  ').counterpartyName, 'Trần B');
    });

    test('giữ số thứ tự dòng gốc để đối chiếu lại với file', () {
      expect(imported().sourceLineNumber, 12);
      expect(imported(sourceLineNumber: null).sourceLineNumber, isNull);
    });

    test('luôn trỏ về đúng một bản ghi nhập — không có giao dịch mồ côi', () {
      expect(imported().importFileRecordId, 99);
    });

    test('chưa được lưu và chưa bị sửa tay', () {
      expect(imported().isPersisted, isFalse);
      expect(imported().isManuallyEdited, isFalse);
    });
  });

  group('chiều tiền', () {
    test('lấy trực tiếp từ dấu của số tiền', () {
      expect(imported(amount: const Money(100, Currency.vnd)).isIncoming, isTrue);
      expect(imported(amount: const Money(-100, Currency.vnd)).isOutgoing, isTrue);
    });
  });

  group('sửa tay', () {
    test('tính lại searchText theo nội dung mới', () {
      final edited = imported().editedWith(
        bookingDate: DateTime.utc(2025, 3, 20),
        amount: const Money(-250000, Currency.vnd),
        counterpartyName: 'Lê Thị C',
        description: 'Trả nợ',
      );
      expect(edited.searchText, SearchText.query('le thi c tra no'));
    });

    test('tính lại fingerprint khi số tiền đổi', () {
      final original = imported();
      final edited = original.editedWith(
        bookingDate: original.bookingDate,
        amount: const Money(-300000, Currency.vnd),
        counterpartyName: original.counterpartyName,
        description: original.description,
      );
      expect(edited.fingerprint, isNot(original.fingerprint));
    });

    test('tính lại fingerprint khi ngày đổi', () {
      final original = imported();
      final edited = original.editedWith(
        bookingDate: DateTime.utc(2025, 3, 25),
        amount: original.amount,
        counterpartyName: original.counterpartyName,
        description: original.description,
      );
      expect(edited.fingerprint, isNot(original.fingerprint));
    });

    test('sửa về đúng dữ liệu cũ cho lại đúng fingerprint cũ', () {
      // Nếu không, một lần sửa rồi hoàn nguyên sẽ biến dòng cũ thành dòng mới ở
      // lần nhập sau.
      final original = imported();
      final edited = original.editedWith(
        bookingDate: original.bookingDate,
        amount: original.amount,
        counterpartyName: original.counterpartyName,
        description: original.description,
      );
      expect(edited.fingerprint, original.fingerprint);
      expect(edited.searchText, original.searchText);
    });

    test('đánh dấu đã sửa tay để lịch sử cảnh báo trước khi hoàn tác', () {
      final edited = imported().editedWith(
        bookingDate: DateTime.utc(2025, 3, 20),
        amount: const Money(-1, Currency.vnd),
        counterpartyName: null,
        description: 'x',
      );
      expect(edited.isManuallyEdited, isTrue);
    });

    test('xoá trắng được tên đối tác', () {
      final edited = imported().editedWith(
        bookingDate: DateTime.utc(2025, 3, 20),
        amount: const Money(-250000, Currency.vnd),
        counterpartyName: null,
        description: 'CK tien hang',
      );
      expect(edited.counterpartyName, isNull);
      expect(edited.searchText, SearchText.query('ck tien hang'));
    });

    test('tên đối tác toàn khoảng trắng cũng thành null', () {
      final edited = imported().editedWith(
        bookingDate: DateTime.utc(2025, 3, 20),
        amount: const Money(-250000, Currency.vnd),
        counterpartyName: '   ',
        description: 'x',
      );
      expect(edited.counterpartyName, isNull);
    });

    test('cắt ngày mới về đúng ngày', () {
      final edited = imported().editedWith(
        bookingDate: DateTime.utc(2025, 3, 25, 23, 59),
        amount: const Money(-1, Currency.vnd),
        counterpartyName: null,
        description: 'x',
      );
      expect(edited.bookingDate, DateTime.utc(2025, 3, 25));
    });

    test('không đụng tới nguồn gốc, tài khoản và thời điểm nhập', () {
      // Tài khoản nằm trong fingerprint và trong chuỗi nguồn gốc nên không sửa
      // được; mất liên kết nguồn gốc là mất luôn khả năng hoàn tác.
      final original = imported().withIdentity(5);
      final edited = original.editedWith(
        bookingDate: DateTime.utc(2025, 3, 25),
        amount: const Money(-1, Currency.vnd),
        counterpartyName: null,
        description: 'x',
      );
      expect(edited.accountId, original.accountId);
      expect(edited.importFileRecordId, original.importFileRecordId);
      expect(edited.sourceLineNumber, original.sourceLineNumber);
      expect(edited.importedAt, original.importedAt);
      expect(edited.transactionId, 5);
    });
  });

  group('định danh', () {
    test('withIdentity giữ nguyên mọi cột dẫn xuất', () {
      final fresh = imported();
      final saved = fresh.withIdentity(11);
      expect(saved.transactionId, 11);
      expect(saved.isPersisted, isTrue);
      expect(saved.fingerprint, fresh.fingerprint);
      expect(saved.searchText, fresh.searchText);
    });

    test('bằng nhau theo định danh, không theo nội dung', () {
      expect(imported().withIdentity(1), imported(description: 'x').withIdentity(1));
      expect(imported().withIdentity(1), isNot(imported().withIdentity(2)));
    });

    test('hai giao dịch chưa lưu không bằng nhau dù nội dung giống hệt', () {
      // Hai dòng giống hệt nhau trong cùng một file là hai giao dịch thật khác
      // nhau và phải được nhập đủ.
      expect(imported(), isNot(imported()));
    });
  });

  test('là một MatchCandidate — cùng vị từ ghép cặp chạy trên nó', () {
    final MatchCandidate candidate = imported().withIdentity(4);
    expect(candidate.transactionId, 4);
    expect(candidate.accountId, 1);
    expect(candidate.bookingDate, DateTime.utc(2025, 3, 20));
    expect(candidate.amount, const Money(-250000, Currency.vnd));
  });
}
