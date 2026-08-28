import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../database/sql_codec.dart';

/// Đổi hai entity của nghiệp vụ đối soát qua lại với dòng của chúng.
///
/// Cặp và phán quyết từ chối là **hai aggregate độc lập** chứ không phải hai
/// trạng thái của cùng một bảng: một giao dịch chỉ thuộc tối đa một cặp nhưng có
/// thể bị từ chối với nhiều đối tác khác nhau, và phán quyết sống lâu hơn cặp đã
/// sinh ra nó (Rule – Deletion Is Physical, Not a Tombstone).
abstract final class ReconciliationMapper {
  static Map<String, Object?> pairToRow(ReconciliationPair pair) =>
      <String, Object?>{
        'outgoing_transaction_id': pair.outgoingTransactionId,
        'incoming_transaction_id': pair.incomingTransactionId,
        'status': pair.status.name,
        'created_at': SqlCodec.timestamp(pair.createdAt),
        'confirmed_at': SqlCodec.nullableTimestamp(pair.confirmedAt),
      };

  static ReconciliationPair pairFromRow(Map<String, Object?> row) =>
      ReconciliationPair(
        pairId: row['pair_id'] as int,
        outgoingTransactionId: row['outgoing_transaction_id'] as int,
        incomingTransactionId: row['incoming_transaction_id'] as int,
        status: SqlCodec.parseEnum(PairStatus.values, row['status']),
        createdAt: SqlCodec.parseTimestamp(row['created_at'] as int),
        confirmedAt: SqlCodec.parseNullableTimestamp(row['confirmed_at']),
      );

  /// Hai định danh được ghi đúng như entity đang giữ, tức đã tăng dần — cùng thứ
  /// tự mà `RejectedMatch.between` áp đặt và ràng buộc `CHECK` của lược đồ canh
  /// giữ. Nhờ vậy hỏi "cặp này đã bị từ chối chưa" chỉ cần một lần tra thay vì
  /// hai (UC-09).
  static Map<String, Object?> rejectionToRow(RejectedMatch rejection) =>
      <String, Object?>{
        'transaction_a_id': rejection.transactionAId,
        'transaction_b_id': rejection.transactionBId,
        'rejected_at': SqlCodec.timestamp(rejection.rejectedAt),
      };

  static RejectedMatch rejectionFromRow(Map<String, Object?> row) =>
      RejectedMatch(
        rejectedMatchId: row['rejected_match_id'] as int,
        transactionAId: row['transaction_a_id'] as int,
        transactionBId: row['transaction_b_id'] as int,
        rejectedAt: SqlCodec.parseTimestamp(row['rejected_at'] as int),
      );
}
