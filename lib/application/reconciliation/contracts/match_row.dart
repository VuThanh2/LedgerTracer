import '../../../domain/services/match_predicate.dart';
import '../../../domain/value_objects/money.dart';

/// Một giao dịch **rút gọn về đúng những gì phép ghép cặp cần đọc**, để đi qua
/// ranh giới isolate.
///
/// Entity của Domain không bao giờ đi qua ranh giới đó. Lý do không phải hình
/// thức: mọi thứ qua ranh giới đều bị **sao chép**, và một [Transaction] mang
/// theo `description`, `searchText`, `fingerprint` — ba chuỗi mà lần quét không
/// hề đụng tới nhưng lại chiếm gần hết dung lượng của bản ghi. Ở quy mô hàng
/// trăm nghìn dòng, gửi bản đầy đủ là trả giá bộ nhớ gấp nhiều lần cho dữ liệu
/// không ai dùng.
///
/// Nó vẫn là [MatchCandidate], nên vị từ ghép cặp chạy trên nó là **cùng một vị
/// từ** chạy trên [Transaction] ở màn hình ứng viên — không có bản sao thứ hai
/// của điều kiện ghép để hai bên lệch nhau (UC-08, UC-09).
final class MatchRow implements MatchCandidate {
  const MatchRow({
    required this.transactionId,
    required this.accountId,
    required this.bookingDate,
    required this.amount,
  });

  /// Không bao giờ `null`: chỉ giao dịch đã được lưu mới vào tới lần quét.
  @override
  final int transactionId;

  @override
  final int accountId;

  @override
  final DateTime bookingDate;

  @override
  final Money amount;

  @override
  String toString() =>
      'MatchRow($transactionId, account $accountId, '
      '${bookingDate.toIso8601String()}, $amount)';
}
