/// Một cặp mà lần quét tìm ra, trên đường từ isolate về luồng chính.
///
/// Chưa phải `ReconciliationPair`: nó chưa có định danh, chưa có thời điểm tạo
/// đã chốt, và chưa được ghi. Chỉ mang hai định danh đã **được định chiều** —
/// vế nào chuyển ra, vế nào nhận vào — vì việc xác định chiều thuộc về vị từ
/// ghép cặp, không phải về tầng ghi.
final class PairCandidate {
  const PairCandidate({
    required this.outgoingTransactionId,
    required this.incomingTransactionId,
  });

  final int outgoingTransactionId;

  final int incomingTransactionId;

  @override
  String toString() =>
      'PairCandidate($outgoingTransactionId → $incomingTransactionId)';
}
