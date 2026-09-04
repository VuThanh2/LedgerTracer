import '../view_models/import_file_entry.dart';

/// Những gì xảy ra ở tab *Nhập mới* — stepper bốn bước của UC-02.
sealed class ImportEvent {
  const ImportEvent();
}

/// Mở tab: nạp danh sách tài khoản để bước 2 có gì mà gán.
final class ImportStarted extends ImportEvent {
  const ImportStarted();
}

/// Bước 1 — bấm chọn file. Mở hộp thoại của nền tảng rồi nhận diện định dạng
/// từng file (UC-02 bước 1, 2).
final class ImportFilesPickRequested extends ImportEvent {
  const ImportFilesPickRequested();
}

/// Bỏ một file khỏi lượt trước khi nhập.
final class ImportFileRemoved extends ImportEvent {
  const ImportFileRemoved(this.fileName);

  final String fileName;
}

/// Bước 2 — gán tài khoản đích cho một file, rồi đối chiếu số tài khoản
/// (UC-02 bước 3, 4).
final class ImportFileAccountAssigned extends ImportEvent {
  const ImportFileAccountAssigned({
    required this.fileName,
    required this.accountId,
  });

  final String fileName;
  final int accountId;
}

/// Tạo tài khoản mới ngay tại bước 2 rồi gán luôn cho file đang xét (UC-01,
/// UC-02 bước 3).
final class ImportAccountCreated extends ImportEvent {
  const ImportAccountCreated({
    required this.displayName,
    required this.assignToFileName,
  });

  final String displayName;

  /// File sẽ được gán ngay cho tài khoản vừa tạo; `null` khi chỉ tạo tài khoản.
  final String? assignToFileName;
}

/// Trả lời cảnh báo lệch số tài khoản (UC-02 bước 4).
final class ImportMismatchResolved extends ImportEvent {
  const ImportMismatchResolved({
    required this.fileName,
    required this.decision,
  });

  final String fileName;
  final MismatchDecision decision;
}

/// Đi tới bước kế tiếp của stepper.
final class ImportStepAdvanced extends ImportEvent {
  const ImportStepAdvanced();
}

/// Quay lại bước trước. Chỉ đi được ở hai bước đầu — bước 3 đang chạy và bước 4
/// là kết cục đã ghi xuống.
final class ImportStepReverted extends ImportEvent {
  const ImportStepReverted();
}

/// Bước 3 — bắt đầu nhập (UC-02 bước 5).
final class ImportRunRequested extends ImportEvent {
  const ImportRunRequested();
}

/// Bấm Huỷ trong lúc đang nhập.
///
/// Tín hiệu chỉ đọc được tại ranh giới giữa các lô, nên nút phản hồi trong vòng
/// một lô. Huỷ xong vẫn **đi tiếp sang bước 4**, không quay về bước 1: phần đã
/// ghi là kết quả thật và phải được tổng kết (UC-02 bước 7).
final class ImportRunCancelled extends ImportEvent {
  const ImportRunCancelled();
}

/// Bước 4 — bắt đầu một lượt mới, xoá sạch stepper.
final class ImportReset extends ImportEvent {
  const ImportReset();
}
