import '../entities/reconciliation_pair.dart';
import '../entities/rejected_match.dart';
import '../entities/transaction.dart';
import '../value_objects/match_window.dart';
import '../value_objects/pair_status.dart';

/// Cổng lưu trữ của aggregate ReconciliationPair và RejectedMatch (UC-08,
/// UC-09).
///
/// Nó cũng sở hữu **đường đọc giao dịch phục vụ đối soát** — dòng nào chưa được
/// ghép, dòng nào có thể ghép với một dòng cho trước — vì các truy vấn đó nói về
/// chính trạng thái ghép cặp.
abstract interface class ReconciliationRepository {
  /// Một trang các cặp, có thể thu hẹp theo trạng thái (UC-09).
  Future<List<ReconciliationPair>> findPairs({
    PairStatus? status,
    required int limit,
    required int offset,
  });

  Future<int> countPairs({PairStatus? status});

  Future<ReconciliationPair?> findPairById(int pairId);

  /// Cặp mà một giao dịch đang thuộc về, nếu có — mỗi giao dịch thuộc tối đa một
  /// cặp tại một thời điểm (UC-08).
  Future<ReconciliationPair?> findPairInvolving(int transactionId);

  /// Trong các giao dịch đưa vào, những giao dịch nào đã nằm trong một cặp —
  /// dùng để vẽ chỉ báo "đã đối soát" cho một trang danh sách (UC-04).
  Future<Set<int>> findPairedTransactionIds(
    Iterable<int> transactionIds, {
    PairStatus? status,
  });

  /// Lưu một lô gợi ý mà lần quét tìm được.
  Future<void> addPairs(List<ReconciliationPair> pairs);

  /// Lưu một lần xác nhận (UC-09 bước 3).
  ///
  /// Ném `PairNotFoundError` nếu bản ghi không còn tồn tại.
  Future<void> updatePair(ReconciliationPair pair);

  Future<void> deletePairById(int pairId);

  /// Xoá sạch các gợi ý trước một lần quét mới và trả về số cặp đã mất. Cặp đã
  /// xác nhận thì ở lại: chúng mang phán quyết của người dùng, gợi ý thì không
  /// (UC-08).
  Future<int> deleteSuggestedPairs();

  /// Huỷ mọi cặp có dính tới các giao dịch sắp bị xoá, bất kể trạng thái — một
  /// cặp chỉ tồn tại khi cả hai vế còn tồn tại (bất biến ở UC-09, được UC-01,
  /// UC-03, UC-05 tham chiếu).
  Future<int> deletePairsInvolving(Iterable<int> transactionIds);

  /// Một thao tác xoá sẽ huỷ bao nhiêu cặp, để hộp thoại xác nhận nói được con
  /// số đó (UC-01, UC-03).
  Future<int> countPairsInvolving(Iterable<int> transactionIds);

  /// Một trang các giao dịch chưa thuộc cặp nào — đầu vào mà lần quét duyệt theo
  /// lô (UC-08 bước 2).
  Future<List<Transaction>> findUnpairedTransactions({
    required int limit,
    required int offset,
  });

  Future<int> countUnpairedTransactions();

  /// Các dòng có thể ghép với [anchor] — chính là danh sách thay thế mà UC-09
  /// tính lại mỗi lần mở một cặp thay vì lưu sẵn.
  ///
  /// Ranh giới trách nhiệm ở đây quan trọng, vì chia sai sẽ hiện cho người dùng
  /// một ứng viên mà họ không chọn được:
  ///
  /// * **trạng thái** lọc tại đây, vì chỉ cơ sở dữ liệu biết — bỏ chính anchor,
  ///   bỏ các dòng đã thuộc cặp khác, và bỏ các dòng đã bị người dùng từ chối
  ///   với anchor này (`RejectedMatch`);
  /// * **khả năng ghép** do người gọi lọc qua `MatchPredicate`, thứ vẫn là định
  ///   nghĩa duy nhất của một cặp hợp lệ. Thu hẹp trước bằng các cột có chỉ mục
  ///   (số tiền đối nhau, cùng loại tiền, khác tài khoản, ngày trong [window])
  ///   là nên làm, nhưng đó chỉ là tối ưu: kết quả là một tập cha và vị từ mới
  ///   có tiếng nói cuối.
  Future<List<Transaction>> findMatchCandidates({
    required Transaction anchor,
    required MatchWindow window,
  });

  /// Ghi lại phán quyết "hai giao dịch này không phải một cặp" (UC-09 bước 3).
  Future<RejectedMatch> addRejection(RejectedMatch rejection);

  /// Gỡ một phán quyết bấm nhầm; cặp đó trở lại làm ứng viên ở lần quét kế tiếp
  /// (UC-09 bước 5).
  Future<void> deleteRejectionById(int rejectedMatchId);

  /// Phán quyết chỉ có nghĩa khi cả hai giao dịch còn tồn tại, nên xoá một giao
  /// dịch thì xoá luôn phán quyết dính tới nó (UC-09).
  Future<int> deleteRejectionsInvolving(Iterable<int> transactionIds);

  /// Một trang của danh sách "Đã từ chối" trên màn hình đối soát (UC-09).
  Future<List<RejectedMatch>> findRejections({
    required int limit,
    required int offset,
  });

  /// Các phán quyết dính tới bất kỳ giao dịch nào trong tập đưa vào, nạp theo
  /// từng lô quét để lần quét loại được cặp đã bị từ chối mà không phải hỏi cơ
  /// sở dữ liệu cho từng ứng viên (UC-08).
  Future<List<RejectedMatch>> findRejectionsInvolving(
    Iterable<int> transactionIds,
  );
}
