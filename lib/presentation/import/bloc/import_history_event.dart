/// Đơn vị bị hoàn tác: một file, hay cả một lượt (UC-03 bước 3).
enum RevertTarget { file, session }

/// Những gì xảy ra ở tab *Lịch sử* (UC-03).
sealed class ImportHistoryEvent {
  const ImportHistoryEvent();
}

/// Mở tab, hoặc đọc lại sau khi vừa nhập xong một lượt.
final class ImportHistoryStarted extends ImportHistoryEvent {
  const ImportHistoryStarted();
}

final class ImportHistoryNextPageRequested extends ImportHistoryEvent {
  const ImportHistoryNextPageRequested();
}

/// Mở/đóng một lượt để xem các bản ghi file con của nó.
final class ImportHistorySessionToggled extends ImportHistoryEvent {
  const ImportHistorySessionToggled(this.sessionId);

  final int sessionId;
}

/// Bấm hoàn tác: hỏi trước xem việc đó sẽ xoá bao nhiêu giao dịch và huỷ bao
/// nhiêu cặp đối soát, để hộp thoại xác nhận nói được con số cụ thể
/// (UC-03 bước 4).
final class ImportHistoryRevertRequested extends ImportHistoryEvent {
  const ImportHistoryRevertRequested({
    required this.target,
    required this.id,
  });

  final RevertTarget target;

  /// Định danh bản ghi file, hoặc định danh lượt, tuỳ [target].
  final int id;
}

/// Đóng hộp thoại xác nhận mà không hoàn tác.
final class ImportHistoryRevertDismissed extends ImportHistoryEvent {
  const ImportHistoryRevertDismissed();
}

/// Đồng ý hoàn tác trong hộp thoại xác nhận.
final class ImportHistoryRevertConfirmed extends ImportHistoryEvent {
  const ImportHistoryRevertConfirmed();
}
