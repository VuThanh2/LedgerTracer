import '../view_models/reconciliation_group.dart';

/// Những gì xảy ra trên màn hình đối soát nội bộ (UC-08, UC-09).
sealed class ReconciliationEvent {
  const ReconciliationEvent();
}

/// Mở màn hình: đọc ngưỡng lệch, đếm ba nhóm, và kiểm tiền điều kiện "có ít nhất
/// hai tài khoản có giao dịch" (UC-08).
final class ReconciliationStarted extends ReconciliationEvent {
  const ReconciliationStarted({this.focusPairId});

  /// Vào từ chỉ báo "đã đối soát" ở màn hình chi tiết giao dịch: mở thẳng tới
  /// đúng cặp đó (UC-04 → UC-09).
  final int? focusPairId;
}

/// Đổi nhóm trên Segmented Control.
final class ReconciliationGroupSelected extends ReconciliationEvent {
  const ReconciliationGroupSelected(this.group);

  final ReconciliationGroup group;
}

/// Bấm nút Chạy.
///
/// [acknowledgedClearingPending] là **xác nhận đã đọc cảnh báo**: chạy lại xoá
/// sạch mọi cặp chưa xác nhận, nên khi nhóm *Chờ quyết định* khác rỗng thì lần
/// bấm đầu chỉ dựng cảnh báo, và lần bấm thứ hai — với cờ này bật — mới thật sự
/// chạy (UC-08).
final class ReconciliationRunRequested extends ReconciliationEvent {
  const ReconciliationRunRequested({this.acknowledgedClearingPending = false});

  final bool acknowledgedClearingPending;
}

/// Đóng cảnh báo "chạy lại sẽ xoá gợi ý chưa xác nhận" mà không chạy.
final class ReconciliationRunDismissed extends ReconciliationEvent {
  const ReconciliationRunDismissed();
}

/// Bấm Huỷ trong lúc đang quét.
///
/// Tín hiệu chỉ được đọc **tại ranh giới giữa các lô**, nên nút phản hồi trong
/// vòng một lô chứ không tức thì — hành vi có chủ đích, và giao diện nói ra điều
/// đó thay vì giả vờ đã dừng (UC-14).
final class ReconciliationRunCancelled extends ReconciliationEvent {
  const ReconciliationRunCancelled();
}

/// Cuộn tới cuối danh sách của nhóm đang chọn.
final class ReconciliationNextPageRequested extends ReconciliationEvent {
  const ReconciliationNextPageRequested();
}

/// Mở chi tiết một cặp: nạp hai vế đầy đủ và các ứng viên thay thế (UC-09
/// bước 2).
final class ReconciliationPairOpened extends ReconciliationEvent {
  const ReconciliationPairOpened(this.pairId);

  /// `null` để đóng.
  final int? pairId;
}

/// Xác nhận một cặp (UC-09 bước 3).
final class ReconciliationPairConfirmed extends ReconciliationEvent {
  const ReconciliationPairConfirmed(this.pairId);

  final int pairId;
}

/// Từ chối một cặp — hành động duy nhất để loại một cặp, dùng chung cho cả cặp
/// gợi ý lẫn cặp đã xác nhận (UC-09).
final class ReconciliationPairRejected extends ReconciliationEvent {
  const ReconciliationPairRejected(this.pairId);

  final int pairId;
}

/// Bấm Hoàn tác trên snackbar vừa hiện sau một lần từ chối, hoặc gỡ một phán
/// quyết trong nhóm *Đã từ chối* (UC-09 bước 5).
final class ReconciliationRejectionUndone extends ReconciliationEvent {
  const ReconciliationRejectionUndone(this.rejectedMatchId);

  final int rejectedMatchId;
}

/// Đổi ngưỡng lệch thời gian, ngay trên màn hình này chứ không trong Thiết lập.
///
/// Chỉ ảnh hưởng **lần chạy sau** và không đụng tới cặp đã xác nhận: cửa sổ là
/// tham số dò tìm, cặp đã xác nhận là phán quyết của người dùng (UC-08).
final class ReconciliationMatchWindowChanged extends ReconciliationEvent {
  const ReconciliationMatchWindowChanged(this.days);

  final int days;
}
