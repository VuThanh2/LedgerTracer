/// Kết quả của lượt quét dọn khi ứng dụng khởi động (UC-02, UC-03).
///
/// Trả về con số chứ không phải `void`: giao diện cần biết có gì để nói với
/// người dùng hay không — một lượt nhập bị gián đoạn là thứ họ phải được báo,
/// vì lần trước ứng dụng biến mất mà không kịp nói gì.
final class ImportRecoveryReport {
  const ImportRecoveryReport({
    required this.interruptedSessionCount,
    required this.discardedEmptySessionCount,
  });

  static const ImportRecoveryReport none = ImportRecoveryReport(
    interruptedSessionCount: 0,
    discardedEmptySessionCount: 0,
  );

  /// Số lượt được chuyển từ `InProgress` sang `Interrupted`. Mỗi lượt như thế
  /// vẫn giữ nguyên các bản ghi file và các giao dịch đã ghi được.
  final int interruptedSessionCount;

  /// Số lượt bị xoá hẳn vì chưa kịp mở bản ghi file nào — chúng không mang thông
  /// tin gì cho người dùng, chỉ là rác của một tiến trình chết sớm.
  final int discardedEmptySessionCount;

  /// Có gì đáng báo cho người dùng không. Lượt rỗng bị xoá không tính: không có
  /// dữ liệu nào của họ dính tới nó.
  bool get hasInterruptedSessions => interruptedSessionCount > 0;
}
