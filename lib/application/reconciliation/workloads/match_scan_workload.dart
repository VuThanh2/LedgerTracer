import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/progress_report.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/services/match_predicate.dart';
import '../../../domain/value_objects/match_window.dart';

/// Đầu vào của lần quét đối soát. Đi qua ranh giới isolate nên mọi trường phải
/// sao chép được.
///
/// Toàn bộ giao dịch chưa ghép được nạp trên luồng chính (isolate không chạm tới
/// cơ sở dữ liệu) rồi gửi vào một lần. Đây là workload thứ hai của báo cáo, khác
/// bản chất với luồng nhập: một lần duyệt **CPU thuần** trên toàn bảng thay vì
/// I/O + phân tích nhiều file (UC-08).
final class MatchScanInput {
  const MatchScanInput({
    required this.transactions,
    required this.window,
    required this.rejections,
    required this.createdAt,
    required this.batchSize,
  });

  final List<Transaction> transactions;

  final MatchWindow window;

  /// Các phán quyết "không phải một cặp" để loại khỏi tập ứng viên — dữ kiện về
  /// quá khứ, không suy ra được từ dữ liệu hiện tại (UC-08).
  final List<RejectedMatch> rejections;

  /// Một mốc thời gian duy nhất cho mọi cặp của lần chạy này.
  final DateTime createdAt;

  final int batchSize;
}

/// Quét toàn bộ giao dịch chưa ghép, tìm các cặp chuyển tiền nội bộ và giao chúng
/// theo lô (UC-08 bước 2–3).
///
/// **Bắt buộc là hàm top-level**: nó chạy trong isolate. Điều kiện ghép cặp không
/// được viết lại ở đây mà uỷ cho [MatchPredicate] — **nơi duy nhất** định nghĩa
/// một cặp hợp lệ, dùng chung với danh sách ứng viên tính lại lúc hiển thị, để
/// hai chỗ không bao giờ lệch nhau (Rule – Suggested Is Not Confirmed).
///
/// Băm theo tổ hợp (loại tiền • trị tuyệt đối số tiền) để thu hẹp ứng viên nhanh;
/// duyệt anchor theo thứ tự định danh và để [MatchPredicate] chọn ứng viên lệch
/// ngày nhỏ nhất — hai điều đó cùng làm cho hai lần chạy trên cùng dữ liệu cho ra
/// cùng kết quả (Rule – Write Order Is Deterministic). Mỗi giao dịch được ghép
/// tối đa một cặp: hai vế bị đánh dấu ngay khi ghép.
Future<void> matchScanWorkload(
  MatchScanInput input,
  WorkloadContext<List<ReconciliationPair>> context,
) async {
  final transactions = <Transaction>[...input.transactions]
    ..sort((a, b) => (a.transactionId ?? 0).compareTo(b.transactionId ?? 0));

  final rejectedKeys = <String>{
    for (final rejection in input.rejections)
      _pairKey(rejection.transactionAId, rejection.transactionBId),
  };

  // Chỉ mục theo (loại tiền • trị tuyệt đối): hai vế đối nhau rơi vào cùng ô.
  final byAmount = <String, List<Transaction>>{};
  for (final transaction in transactions) {
    byAmount
        .putIfAbsent(_amountKey(transaction), () => <Transaction>[])
        .add(transaction);
  }

  final matched = <int>{};
  final batch = <ReconciliationPair>[];
  var processed = 0;

  for (final anchor in transactions) {
    processed++;
    final anchorId = anchor.transactionId;
    if (anchorId != null && !matched.contains(anchorId)) {
      final candidates = <Transaction>[
        for (final candidate in byAmount[_amountKey(anchor)] ?? const [])
          if (candidate.transactionId != null &&
              candidate.transactionId != anchorId &&
              !matched.contains(candidate.transactionId) &&
              !rejectedKeys.contains(_pairKey(anchorId, candidate.transactionId!)))
            candidate,
      ];
      final best = MatchPredicate.bestMatchFor(anchor, candidates, input.window);
      if (best != null) {
        matched.add(anchorId);
        matched.add(best.transactionId!);
        batch.add(
          MatchPredicate.pairOf(anchor, best, createdAt: input.createdAt),
        );
      }
    }

    final atBoundary = processed % input.batchSize == 0;
    if (atBoundary || processed == transactions.length) {
      if (context.isCancelled) return;
      if (batch.isNotEmpty) {
        await context.emit(<ReconciliationPair>[...batch]);
        batch.clear();
      }
      context.reportProgress(
        ProgressReport(processed: processed, total: transactions.length),
      );
    }
  }
}

String _amountKey(Transaction transaction) =>
    '${transaction.amount.currency.code}|${transaction.amount.minorUnits.abs()}';

/// Khoá không phụ thuộc thứ tự của một cặp định danh giao dịch.
String _pairKey(int a, int b) => a < b ? '$a:$b' : '$b:$a';
