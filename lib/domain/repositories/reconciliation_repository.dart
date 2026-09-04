import '../entities/reconciliation_pair.dart';
import '../entities/rejected_match.dart';
import '../entities/transaction.dart';
import '../value_objects/match_window.dart';
import '../value_objects/pair_status.dart';

/// Cổng lưu trữ của hai aggregate độc lập nhưng luôn đi cùng nhau ở tầng trên:
/// ReconciliationPair (cặp đang tồn tại) và RejectedMatch (phán quyết về quá
/// khứ).
///
/// **Quy ước về đối số:** phương thức nhận một định danh đơn hoặc một khoá phạm
/// vi (`accountId`, `importFileRecordId`) là phương thức dùng được ở mọi quy mô —
/// nó dịch thành một câu lệnh có điều kiện lồng. Phương thức nhận `Iterable<int>`
/// chỉ dùng cho **một trang** dữ liệu, vì danh sách đi thẳng vào mệnh đề `IN`
/// của SQLite vốn có trần số tham số. Ranh giới này có chủ đích: một tài khoản
/// hay một lượt nhập có thể mang hàng trăm nghìn giao dịch, và nạp từng ấy định
/// danh lên luồng chính chỉ để xoá là việc vừa chậm vừa sẽ vỡ.
abstract interface class ReconciliationRepository {
  /// Một trang cặp, mới nhất trước (UC-09 bước 1). [status] `null` là lấy cả
  /// gợi ý lẫn đã xác nhận.
  Future<List<ReconciliationPair>> findPairs({
    PairStatus? status,
    required int limit,
    required int offset,
  });

  Future<int> countPairs({PairStatus? status});

  Future<ReconciliationPair?> findPairById(int pairId);

  /// Cặp mà một giao dịch đang thuộc về, nếu có — một giao dịch chỉ được ghép
  /// vào tối đa một cặp tại một thời điểm (UC-08).
  Future<ReconciliationPair?> findPairInvolving(int transactionId);

  /// Trong một trang giao dịch, những dòng nào đang thuộc một cặp — dùng cho chỉ
  /// báo "đã đối soát" (UC-04) với `status: PairStatus.confirmed`.
  ///
  /// [transactionIds] là **một trang**; xem quy ước về đối số ở đầu lớp.
  Future<Set<int>> findPairedTransactionIds(
    Iterable<int> transactionIds, {
    PairStatus? status,
  });

  Future<void> addPairs(List<ReconciliationPair> pairs);

  Future<void> updatePair(ReconciliationPair pair);

  Future<void> deletePairById(int pairId);

  /// Xoá mọi cặp **chưa xác nhận** và trả về số cặp đã xoá — bước đầu của một
  /// lần chạy lại đối soát; cặp đã xác nhận mang phán quyết của người dùng nên
  /// được giữ nguyên (UC-08).
  Future<int> deleteSuggestedPairs();

  /// Huỷ cặp mà một giao dịch đang thuộc về, trả về số cặp đã huỷ. Nền của bất
  /// biến "một cặp chỉ tồn tại khi cả hai vế còn tồn tại" ở đường xoá/sửa lẻ
  /// (UC-05, UC-09).
  Future<int> deletePairsInvolvingTransaction(int transactionId);

  /// Số cặp sẽ bị huỷ nếu xoá cả một tài khoản — con số cho hộp thoại xác nhận
  /// (UC-01).
  Future<int> countPairsByAccountId(int accountId);

  /// Huỷ mọi cặp có ít nhất một vế thuộc tài khoản này (UC-01).
  Future<int> deletePairsByAccountId(int accountId);

  /// Số cặp sẽ bị huỷ nếu hoàn tác một bản ghi nhập (UC-03 bước 4).
  Future<int> countPairsByImportFileRecordId(int recordId);

  /// Huỷ mọi cặp có ít nhất một vế đến từ bản ghi nhập này (UC-03).
  Future<int> deletePairsByImportFileRecordId(int recordId);

  /// Tập ứng viên của một lần quét: các giao dịch **chưa thuộc cặp nào**, theo
  /// trang (UC-08 bước 2).
  Future<List<Transaction>> findUnpairedTransactions({
    required int limit,
    required int offset,
  });

  Future<int> countUnpairedTransactions();

  /// Ứng viên ghép **thô** của một giao dịch, để danh sách ứng viên được tính
  /// lại lúc hiển thị thay vì lưu sẵn (UC-08, UC-09).
  ///
  /// Trả về các giao dịch **chưa thuộc cặp nào**, khác tài khoản với [anchor],
  /// cùng loại tiền, số tiền đối nhau, và ngày ghi nhận nằm trong [window].
  /// Việc loại các cặp **đã bị từ chối** không thuộc về đây mà thuộc về tầng
  /// Application — nơi phán quyết được đọc ra và dùng chung cho cả lần quét lẫn
  /// màn hình.
  Future<List<Transaction>> findMatchCandidates({
    required Transaction anchor,
    required MatchWindow window,
  });

  Future<RejectedMatch> addRejection(RejectedMatch rejection);

  /// Gỡ một phán quyết từ chối (UC-09 bước 5). Trả về `false` khi không có bản
  /// ghi nào bị xoá, để tầng trên phân biệt được "đã gỡ" với "id không còn".
  Future<bool> deleteRejectionById(int rejectedMatchId);

  /// Xoá mọi phán quyết dính tới một giao dịch sắp bị xoá — phán quyết chỉ có
  /// nghĩa khi cả hai vế còn tồn tại (UC-09).
  Future<int> deleteRejectionsInvolvingTransaction(int transactionId);

  Future<int> deleteRejectionsByAccountId(int accountId);

  Future<int> deleteRejectionsByImportFileRecordId(int recordId);

  /// Một trang danh sách "Đã từ chối" (UC-09 bước 5), mới nhất trước.
  Future<List<RejectedMatch>> findRejections({
    required int limit,
    required int offset,
  });

  /// Mọi phán quyết dính tới **một** giao dịch — để danh sách ứng viên lúc hiển
  /// thị loại đúng những cặp người dùng đã từ chối (UC-09).
  Future<List<RejectedMatch>> findRejectionsForTransaction(int transactionId);
}
