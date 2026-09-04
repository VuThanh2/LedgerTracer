/// Workload đã chạy tới đâu, gửi từ nơi xử lý về giao diện.
///
/// Là trạng thái thực thi chứ không phải Domain: nó chỉ sống bằng vòng đời của
/// tác vụ và không bao giờ được lưu. Nó đi qua ranh giới isolate nên phải là dữ
/// liệu thuần, sao chép được.
///
/// Tiến trình chỉ được báo **tại ranh giới giữa các lô** — isolate không thể bị
/// ngắt giữa chừng một phép tính, nên một thanh tiến trình mịn hơn là thứ không
/// mua được bằng bất cứ giá nào (UC-02, UC-08, UC-14).
final class ProgressReport {
  const ProgressReport({required this.processed, this.total, this.workloadId})
    : assert(processed >= 0, 'processed rows cannot be negative');

  /// Chưa đo được gì — số dòng của một file chỉ biết sau khi đã đọc.
  const ProgressReport.starting({String? workloadId})
    : this(processed: 0, workloadId: workloadId);

  final int processed;

  /// Tổng ước lượng, nếu có. `null` nghĩa là không xác định và giao diện phải
  /// hiện vòng xoay thay vì thanh tiến trình.
  final int? total;

  /// Đây là workload nào trong số các workload đang chạy — ví dụ định danh bản
  /// ghi nhập của file đang xử lý. Để kiểu chuỗi để `core` không dính tới bất kỳ
  /// định danh nghiệp vụ nào.
  final String? workloadId;

  bool get isDeterminate => total != null && total! > 0;

  /// Mức hoàn thành trong khoảng 0..1, hoặc `null` khi chưa xác định được.
  double? get fraction {
    final expected = total;
    if (expected == null || expected <= 0) return null;
    final ratio = processed / expected;
    return ratio > 1 ? 1 : ratio;
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressReport &&
      other.processed == processed &&
      other.total == total &&
      other.workloadId == workloadId;

  @override
  int get hashCode => Object.hash(processed, total, workloadId);

  @override
  String toString() =>
      'ProgressReport($processed/${total ?? '?'}'
      '${workloadId == null ? '' : ', $workloadId'})';
}
