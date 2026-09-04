import '../value_objects/date_range.dart';
import '../value_objects/match_window.dart';
import '../value_objects/money.dart';

/// Bề mặt tối thiểu mà việc ghép cặp cần đọc được ở một giao dịch.
///
/// Tồn tại vì cùng một vị từ ghép cặp phải chạy ở **hai nơi có hình dạng dữ liệu
/// khác nhau**: lần quét theo lô chạy trong isolate (nơi Entity không được đi
/// qua — xem Ranh giới Isolate) và truy vấn ứng viên lúc hiển thị chạy trên
/// luồng chính với chính [Transaction]. Trừu tượng hoá bốn thuộc tính này là cách
/// giữ vị từ ở **đúng một chỗ** thay vì chép nó sang phía isolate rồi để hai bản
/// lệch nhau (Rule – Suggested Is Not Confirmed).
abstract interface class MatchCandidate {
  /// Định danh cục bộ; `null` khi bản ghi chưa được lưu.
  int? get transactionId;

  int get accountId;

  /// Ngày ghi nhận lấy từ file — không phải đồng hồ thiết bị
  /// (Rule – File Time and Device Time Are Different Things).
  DateTime get bookingDate;

  Money get amount;
}

/// Nơi **duy nhất** định nghĩa thế nào là một cặp chuyển tiền nội bộ hợp lệ
/// (UC-08 bước 3).
///
/// Điều kiện ghép nằm trọn ở đây, dùng chung cho lần quét theo lô lẫn danh sách
/// ứng viên được tính lại lúc hiển thị (UC-09). Hai bản sao của cùng một điều
/// kiện sẽ lệch nhau, và người dùng sẽ thấy một ứng viên xuất hiện ở màn hình này
/// mà không xuất hiện ở màn hình kia.
abstract final class MatchPredicate {
  /// Hai giao dịch khác tài khoản, **cùng loại tiền**, số tiền đối nhau, và lệch
  /// ngày nằm trong cửa sổ. Điều kiện cùng loại tiền do [Money.isOppositeOf] giữ:
  /// chuyển tiền nội bộ có đổi loại tiền nằm ngoài phạm vi đối soát (UC-08).
  static bool canPair(MatchCandidate a, MatchCandidate b, MatchWindow window) =>
      a.accountId != b.accountId &&
      a.amount.isOppositeOf(b.amount) &&
      window.covers(a.bookingDate, b.bookingDate);

  static int driftInDays(MatchCandidate a, MatchCandidate b) =>
      DateRange.daysBetween(a.bookingDate, b.bookingDate).abs();

  /// Mọi ứng viên hợp lệ của [anchor], lệch ngày nhỏ nhất trước; bằng nhau thì
  /// theo định danh tăng dần để hai lần chạy trên cùng dữ liệu cho ra cùng kết
  /// quả (UC-08).
  static List<T> alternativesFor<T extends MatchCandidate>(
    T anchor,
    Iterable<T> candidates,
    MatchWindow window,
  ) {
    final matches = candidates
        .where((candidate) => canPair(anchor, candidate, window))
        .toList(growable: false);
    matches.sort((x, y) => _compareCandidates(anchor, x, y));
    return matches;
  }

  /// Ứng viên được chọn làm gợi ý chính — phần tử đầu của [alternativesFor].
  static T? bestMatchFor<T extends MatchCandidate>(
    T anchor,
    Iterable<T> candidates,
    MatchWindow window,
  ) {
    final matches = alternativesFor(anchor, candidates, window);
    return matches.isEmpty ? null : matches.first;
  }

  /// Xác định vế nào là chuyển ra, vế nào là nhận vào — **chiều nằm ở dấu của số
  /// tiền**, không ở một cột loại giao dịch riêng (Rule – The Sign Carries the
  /// Direction). Chỉ gọi cho hai giao dịch đã qua [canPair].
  static (T outgoing, T incoming) orient<T extends MatchCandidate>(T a, T b) =>
      a.amount.isOutgoing ? (a, b) : (b, a);

  static int _compareCandidates<T extends MatchCandidate>(
    T anchor,
    T x,
    T y,
  ) {
    final byDrift = driftInDays(anchor, x).compareTo(driftInDays(anchor, y));
    if (byDrift != 0) return byDrift;
    return (x.transactionId ?? 0).compareTo(y.transactionId ?? 0);
  }
}
