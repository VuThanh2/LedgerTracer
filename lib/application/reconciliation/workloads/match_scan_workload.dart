import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/progress_report.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/services/match_predicate.dart';
import '../../../domain/value_objects/match_window.dart';
import '../contracts/match_row.dart';
import '../contracts/pair_candidate.dart';

/// Đầu vào của lần quét đối soát. Đi qua ranh giới isolate nên mọi trường phải
/// sao chép được, và **không trường nào là Entity của Domain**.
///
/// Toàn bộ tập ứng viên được gửi vào một lần thay vì theo lô. Đó không phải sơ
/// suất mà là ràng buộc của chính thuật toán: bước đầu tiên là dựng chỉ mục
/// theo số tiền trên **toàn bộ** tập, và một chỉ mục dựng trên từng mảnh rời sẽ
/// bỏ sót đúng những cặp nằm vắt qua hai mảnh. Cái giá bộ nhớ được trả bằng
/// [MatchRow] — bản rút gọn chỉ giữ bốn thuộc tính mà phép ghép thật sự đọc.
///
/// Đây là workload thứ hai của báo cáo, khác bản chất với luồng nhập: một lần
/// duyệt **CPU thuần** trên toàn bảng thay vì I/O + phân tích nhiều file (UC-08).
final class MatchScanInput {
  const MatchScanInput({
    required this.rows,
    required this.window,
    required this.rejectedKeys,
    required this.batchSize,
  });

  final List<MatchRow> rows;

  final MatchWindow window;

  /// Khoá của các cặp đã bị từ chối, dựng bằng [RejectedMatch.keyOf] trên luồng
  /// chính — dữ kiện về quá khứ, không suy ra được từ dữ liệu hiện tại (UC-08).
  ///
  /// Đi qua ranh giới dưới dạng tập chuỗi chứ không phải tập Entity, nhưng quy
  /// tắc dựng khoá vẫn nằm nguyên trong Domain: phía isolate gọi lại **chính**
  /// [RejectedMatch.keyOf] — gọi một hàm tĩnh không đưa Entity nào qua ranh
  /// giới, nên không có bản sao thứ hai của quy tắc ấy để lệch.
  final Set<String> rejectedKeys;

  final int batchSize;
}

/// Quét toàn bộ giao dịch chưa ghép, tìm các cặp chuyển tiền nội bộ và giao
/// chúng theo lô (UC-08 bước 2–3).
///
/// **Bắt buộc là hàm top-level**: nó chạy trong isolate và không được đóng gói
/// bất kỳ trạng thái nào bên ngoài. Điều kiện ghép cặp không được viết lại ở đây
/// mà uỷ cho [MatchPredicate] — nơi duy nhất định nghĩa một cặp hợp lệ, dùng
/// chung với danh sách ứng viên tính lại lúc hiển thị, để hai chỗ không bao giờ
/// lệch nhau (Rule – Suggested Is Not Confirmed).
///
/// Băm theo tổ hợp (loại tiền • trị tuyệt đối số tiền) để thu hẹp ứng viên
/// nhanh; duyệt anchor theo thứ tự định danh và để [MatchPredicate] chọn ứng
/// viên lệch ngày nhỏ nhất — hai điều đó cùng làm cho hai lần chạy trên cùng dữ
/// liệu cho ra cùng kết quả. Mỗi giao dịch được ghép tối đa một cặp: hai vế bị
/// đánh dấu ngay khi ghép.
Future<void> matchScanWorkload(
  MatchScanInput input,
  WorkloadContext<List<PairCandidate>> context,
) async {
  final rows = <MatchRow>[...input.rows]
    ..sort((a, b) => a.transactionId.compareTo(b.transactionId));

  // Chỉ mục theo (loại tiền • trị tuyệt đối): hai vế đối nhau rơi vào cùng ô.
  final byAmount = <String, List<MatchRow>>{};
  for (final row in rows) {
    byAmount.putIfAbsent(_amountKey(row), () => <MatchRow>[]).add(row);
  }

  final matched = <int>{};
  final batch = <PairCandidate>[];
  var processed = 0;

  for (final anchor in rows) {
    processed++;
    final anchorId = anchor.transactionId;
    if (!matched.contains(anchorId)) {
      final candidates = <MatchRow>[
        for (final candidate in byAmount[_amountKey(anchor)] ?? const <MatchRow>[])
          if (candidate.transactionId != anchorId &&
              !matched.contains(candidate.transactionId) &&
              !input.rejectedKeys.contains(
                RejectedMatch.keyOf(anchorId, candidate.transactionId),
              ))
            candidate,
      ];
      final best = MatchPredicate.bestMatchFor(anchor, candidates, input.window);
      if (best != null) {
        matched
          ..add(anchorId)
          ..add(best.transactionId);
        final (outgoing, incoming) = MatchPredicate.orient(anchor, best);
        batch.add(
          PairCandidate(
            outgoingTransactionId: outgoing.transactionId,
            incomingTransactionId: incoming.transactionId,
          ),
        );
      }
    }

    final atBoundary = processed % input.batchSize == 0;
    if (atBoundary || processed == rows.length) {
      // Ranh giới lô là nơi **duy nhất** yêu cầu huỷ được kiểm: một isolate
      // không bị ngắt được từ bên ngoài giữa chừng một phép tính (UC-14).
      if (context.isCancelled) return;
      if (batch.isNotEmpty) {
        await context.emit(<PairCandidate>[...batch]);
        batch.clear();
      }
      context.reportProgress(
        ProgressReport(processed: processed, total: rows.length),
      );
    }
  }
}

String _amountKey(MatchRow row) =>
    '${row.amount.currency.code}|${row.amount.minorUnits.abs()}';
