import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/entities/transaction.dart';

/// Một cặp ghép cùng hai giao dịch của nó và độ lệch thời gian, đúng những gì màn
/// hình đối soát hiển thị trên mỗi dòng (UC-09 bước 1).
final class PairView {
  const PairView({
    required this.pair,
    required this.outgoing,
    required this.incoming,
    required this.driftInDays,
    required this.outgoingAccountName,
    required this.incomingAccountName,
  });

  final ReconciliationPair pair;

  /// Vế có số tiền âm.
  final Transaction outgoing;

  /// Vế có số tiền dương.
  final Transaction incoming;

  /// Số ngày nguyên giữa hai vế.
  final int driftInDays;

  final String outgoingAccountName;
  final String incomingAccountName;
}

/// Một trang danh sách cặp, thu hẹp được theo trạng thái (UC-09).
final class PairsPage {
  const PairsPage({
    required this.items,
    required this.totalCount,
    required this.offset,
  });

  final List<PairView> items;
  final int totalCount;
  final int offset;
}

/// Các ứng viên ghép thay thế của một cặp, **tính lại lúc hiển thị** bằng chính
/// điều kiện ghép cặp chứ không lưu sẵn (UC-08, UC-09).
///
/// Hai danh sách vì mỗi vế có thể có ứng viên riêng: ứng viên nhận vào khác cho
/// vế chuyển ra, và ứng viên chuyển ra khác cho vế nhận vào. Cặp đang chọn đã bị
/// loại khỏi cả hai.
final class MatchAlternativesView {
  const MatchAlternativesView({
    required this.pair,
    required this.alternativesForOutgoing,
    required this.alternativesForIncoming,
  });

  final PairView pair;

  final List<Transaction> alternativesForOutgoing;
  final List<Transaction> alternativesForIncoming;

  bool get hasAlternatives =>
      alternativesForOutgoing.isNotEmpty || alternativesForIncoming.isNotEmpty;
}

/// Một phán quyết từ chối kèm hai giao dịch của nó, cho danh sách "Đã từ chối"
/// trên màn hình đối soát (UC-09 bước 5).
final class RejectedView {
  const RejectedView({
    required this.rejection,
    required this.transactionA,
    required this.transactionB,
  });

  final RejectedMatch rejection;

  /// Có thể `null` nếu giao dịch đã bị xoá ở đường khác — bản thân việc phán quyết
  /// còn treo mà giao dịch không còn là dữ liệu đã cũ, nhưng vẫn hiển thị được.
  final Transaction? transactionA;
  final Transaction? transactionB;
}

/// Một trang danh sách "Đã từ chối".
///
/// Phân trang bằng [hasMore] thay vì một tổng số: danh sách phán quyết từ chối
/// thường nhỏ và cổng lưu trữ không đếm riêng nó, nên "còn nữa hay không" là đủ
/// để cuộn tiếp mà không phải thêm một phép đếm toàn bảng.
final class RejectedPage {
  const RejectedPage({
    required this.items,
    required this.hasMore,
    required this.offset,
  });

  final List<RejectedView> items;
  final bool hasMore;
  final int offset;
}
