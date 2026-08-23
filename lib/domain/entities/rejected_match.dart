import '../errors/reconciliation_errors.dart';
import 'reconciliation_pair.dart';

/// Phán quyết của người dùng rằng hai giao dịch **không** phải hai vế của cùng
/// một lần chuyển tiền (UC-09).
///
/// Là aggregate riêng, không phải một trạng thái của [ReconciliationPair]: một
/// giao dịch có thể bị từ chối với nhiều đối tác khác nhau, trong khi nó chỉ
/// thuộc tối đa một cặp. Nó cũng không phải tombstone — cặp bị xoá thật, thứ
/// sống sót là **phán quyết**, và phán quyết sống lâu hơn cặp đã sinh ra nó
/// (Rule – Deletion Is Physical, Not a Tombstone).
///
/// Không có nó thì mỗi lần chạy lại đối soát sẽ đề xuất lại đúng cặp người dùng
/// vừa từ chối (UC-08).
final class RejectedMatch {
  const RejectedMatch({
    this.rejectedMatchId,
    required this.transactionAId,
    required this.transactionBId,
    required this.rejectedAt,
  });

  /// Phán quyết không có thứ tự, nên hai định danh luôn được lưu tăng dần: một
  /// lần tra là đủ để biết cặp ứng viên đã bị từ chối hay chưa.
  ///
  /// Ném [SelfPairError] nếu hai định danh là cùng một giao dịch.
  factory RejectedMatch.between({
    required int transactionAId,
    required int transactionBId,
    required DateTime rejectedAt,
  }) {
    if (transactionAId == transactionBId) throw SelfPairError(transactionAId);
    return RejectedMatch(
      transactionAId: transactionAId < transactionBId
          ? transactionAId
          : transactionBId,
      transactionBId: transactionAId < transactionBId
          ? transactionBId
          : transactionAId,
      rejectedAt: rejectedAt,
    );
  }

  /// Ghi lại phán quyết đứng sau việc từ chối [pair] (UC-09 bước 3).
  factory RejectedMatch.forPair(ReconciliationPair pair, DateTime rejectedAt) =>
      RejectedMatch.between(
        transactionAId: pair.outgoingTransactionId,
        transactionBId: pair.incomingTransactionId,
        rejectedAt: rejectedAt,
      );

  final int? rejectedMatchId;

  /// Định danh nhỏ hơn trong cặp bị từ chối.
  final int transactionAId;

  /// Định danh lớn hơn trong cặp bị từ chối.
  final int transactionBId;

  final DateTime rejectedAt;

  bool get isPersisted => rejectedMatchId != null;

  bool involves(int transactionId) =>
      transactionId == transactionAId || transactionId == transactionBId;

  /// So khớp với một cặp ứng viên, không phụ thuộc thứ tự.
  bool refuses(int firstTransactionId, int secondTransactionId) =>
      involves(firstTransactionId) &&
      involves(secondTransactionId) &&
      firstTransactionId != secondTransactionId;

  RejectedMatch withIdentity(int id) => RejectedMatch(
    rejectedMatchId: id,
    transactionAId: transactionAId,
    transactionBId: transactionBId,
    rejectedAt: rejectedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RejectedMatch &&
          other.rejectedMatchId != null &&
          other.rejectedMatchId == rejectedMatchId);

  @override
  int get hashCode => rejectedMatchId?.hashCode ?? identityHashCode(this);

  @override
  String toString() =>
      'RejectedMatch($rejectedMatchId, $transactionAId ✕ $transactionBId)';
}
