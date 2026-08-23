import '../entities/reconciliation_pair.dart';
import '../entities/transaction.dart';
import '../value_objects/date_range.dart';
import '../value_objects/match_window.dart';

/// **Nơi duy nhất** định nghĩa "hai giao dịch này là hai vế của một lần chuyển
/// tiền nội bộ" (UC-08 bước 3).
///
/// Dùng chung cho lần quét theo lô **và** cho danh sách ứng viên được tính lại
/// khi người dùng mở một cặp (UC-09). Hai bản sao của cùng điều kiện chắc chắn
/// sẽ lệch nhau, và người dùng sẽ thấy một ứng viên hiện ở màn hình này mà không
/// hiện ở màn hình kia (Rule – Suggested Is Not Confirmed).
///
/// Thuần và không giữ trạng thái, vì lần quét chạy trong isolate — nơi không với
/// tới được bất cứ thứ gì trong DI container.
///
/// Phán quyết từ chối **không** được tra ở đây: đó là dữ kiện về quá khứ chứ
/// không phải thuộc tính của hai dòng dữ liệu, nên người gọi tự loại chúng bằng
/// tập đã nạp từ repository (UC-08).
abstract final class MatchPredicate {
  /// [a] và [b] có được phép ghép thành một cặp hay không:
  ///
  /// * khác tài khoản — một tài khoản không tự chuyển cho chính nó, và hai file
  ///   của hai tài khoản khác nhau không bao giờ là trùng lặp;
  /// * cùng loại tiền — chuyển tiền có đổi loại tiền nằm ngoài phạm vi, vì tỷ
  ///   giá và phí làm hai vế lệch cả giá trị
  ///   (Rule – Currency Belongs to the Transaction and Never Mixes);
  /// * số tiền đối nhau và khác 0 — dấu đã mang chiều tiền nên một phép kiểm này
  ///   thay cho việc rẽ nhánh theo từng định dạng nguồn
  ///   (Rule – The Sign Carries the Direction);
  /// * ngày ghi nhận nằm trong [window] — ngân hàng xử lý có độ trễ.
  static bool canPair(Transaction a, Transaction b, MatchWindow window) =>
      a.accountId != b.accountId &&
      a.amount.isOppositeOf(b.amount) &&
      window.covers(a.bookingDate, b.bookingDate);

  /// Số ngày nguyên giữa hai vế, hiển thị kèm mỗi cặp (UC-09 bước 1).
  static int driftInDays(Transaction a, Transaction b) =>
      DateRange.daysBetween(a.bookingDate, b.bookingDate).abs();

  /// Mọi ứng viên ghép được với [anchor], tốt nhất đứng trước.
  ///
  /// Thứ tự — lệch ngày nhỏ nhất, rồi tới định danh nhỏ nhất — chính là thứ làm
  /// cho hai lần chạy trên cùng dữ liệu cho ra cùng kết quả. Các ứng viên còn
  /// lại không bị loại âm thầm: chúng là danh sách thay thế mà UC-09 hiển thị,
  /// và được **tính lại lúc hiển thị** chứ không lưu sẵn.
  static List<Transaction> alternativesFor(
    Transaction anchor,
    Iterable<Transaction> candidates,
    MatchWindow window,
  ) {
    final matches = candidates
        .where((candidate) => canPair(anchor, candidate, window))
        .toList(growable: false);
    matches.sort((x, y) => _compareCandidates(anchor, x, y));
    return matches;
  }

  /// Ứng viên mà lần quét đề xuất cho [anchor], `null` nếu không có ai hợp lệ.
  static Transaction? bestMatchFor(
    Transaction anchor,
    Iterable<Transaction> candidates,
    MatchWindow window,
  ) {
    final matches = alternativesFor(anchor, candidates, window);
    return matches.isEmpty ? null : matches.first;
  }

  /// Dựng cặp gợi ý từ hai giao dịch đã thoả [canPair], đặt vế âm vào phía
  /// chuyển ra. Cả hai bắt buộc đã được lưu, vì cặp trỏ tới định danh.
  static ReconciliationPair pairOf(
    Transaction a,
    Transaction b, {
    required DateTime createdAt,
  }) {
    assert(
      a.isPersisted && b.isPersisted,
      'Only persisted transactions can be paired.',
    );
    final outgoing = a.isOutgoing ? a : b;
    final incoming = a.isOutgoing ? b : a;
    return ReconciliationPair.suggested(
      outgoingTransactionId: outgoing.transactionId!,
      incomingTransactionId: incoming.transactionId!,
      createdAt: createdAt,
    );
  }

  static int _compareCandidates(
    Transaction anchor,
    Transaction x,
    Transaction y,
  ) {
    final byDrift = driftInDays(anchor, x).compareTo(driftInDays(anchor, y));
    if (byDrift != 0) return byDrift;
    return (x.transactionId ?? 0).compareTo(y.transactionId ?? 0);
  }
}
