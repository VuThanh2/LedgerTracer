import '../../../domain/value_objects/pair_status.dart';

/// Ba nhóm phán quyết của Segmented Control (UC-09).
///
/// Cả ba **luôn nhìn thấy kèm số đếm**, kể cả khi đếm bằng 0: nhóm biến mất khi
/// rỗng nghĩa là người dùng không biết mình đã từ chối bao nhiêu cặp, và cũng
/// không tìm được đường vào để gỡ một phán quyết bấm nhầm.
///
/// Chú ý [rejected] **không** phải một `PairStatus`. Từ chối là xoá cặp và ghi
/// một `RejectedMatch` riêng — một giao dịch chỉ thuộc tối đa một cặp nhưng có
/// thể bị từ chối với nhiều giao dịch khác nhau, nên phán quyết không thể là một
/// trạng thái của cặp. Ba nhóm trên màn hình vì thế đến từ **hai** đường đọc
/// khác nhau, và enum này là chỗ duy nhất biết điều đó.
enum ReconciliationGroup {
  /// Cặp máy đề xuất, chờ người dùng quyết.
  pending,

  /// Cặp đã xác nhận — nhóm duy nhất có hiệu lực nghiệp vụ.
  confirmed,

  /// Phán quyết từ chối đã ghi.
  rejected;

  /// Trạng thái cặp tương ứng, hoặc `null` với [rejected] vì nó không phải một
  /// trạng thái cặp.
  PairStatus? get pairStatus => switch (this) {
    ReconciliationGroup.pending => PairStatus.suggested,
    ReconciliationGroup.confirmed => PairStatus.confirmed,
    ReconciliationGroup.rejected => null,
  };

  String get label => switch (this) {
    ReconciliationGroup.pending => 'Chờ quyết định',
    ReconciliationGroup.confirmed => 'Đã xác nhận',
    ReconciliationGroup.rejected => 'Đã từ chối',
  };
}
