import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/transaction.dart';
import '../contracts/match_row.dart';
import '../contracts/pair_candidate.dart';

/// Hai phép đổi hình ở hai đầu ranh giới isolate của lần quét đối soát.
abstract final class MatchRowMapper {
  /// Entity đã lưu → dòng rút gọn gửi vào isolate.
  static MatchRow toRow(Transaction transaction) => MatchRow(
    transactionId: transaction.transactionId!,
    accountId: transaction.accountId,
    bookingDate: transaction.bookingDate,
    amount: transaction.amount,
  );

  /// Cặp isolate tìm ra → Entity ở trạng thái **gợi ý**.
  ///
  /// Trạng thái là gợi ý chứ không phải đã xác nhận: thuật toán ghép theo số
  /// tiền và cửa sổ thời gian chắc chắn sẽ trùng khớp ngẫu nhiên với những giao
  /// dịch không liên quan, nên để nó tự có hiệu lực nghiệp vụ là để máy quyết
  /// một việc nó không đủ căn cứ (Rule – Suggested Is Not Confirmed).
  static ReconciliationPair toPair(
    PairCandidate candidate, {
    required DateTime createdAt,
  }) => ReconciliationPair.suggested(
    outgoingTransactionId: candidate.outgoingTransactionId,
    incomingTransactionId: candidate.incomingTransactionId,
    createdAt: createdAt,
  );
}
