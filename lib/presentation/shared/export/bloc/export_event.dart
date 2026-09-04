import '../../../../application/export/export_dataset/export_dataset_dto.dart';
import '../view_models/export_source.dart';

/// Những gì xảy ra trong Export Dialog (UC-11).
sealed class ExportEvent {
  const ExportEvent();
}

/// Mở dialog từ một trong năm điểm vào.
final class ExportOpened extends ExportEvent {
  const ExportOpened(this.source);

  final ExportSource source;
}

/// Đổi định dạng file.
final class ExportFormatSelected extends ExportEvent {
  const ExportFormatSelected(this.format);

  final ExportFormat format;
}

/// Bấm xuất.
final class ExportRequested extends ExportEvent {
  const ExportRequested();
}

/// Bấm Huỷ trong lúc đang gom dữ liệu.
///
/// An toàn tuyệt đối ở đây, khác hẳn huỷ ở lúc nhập: xuất là thao tác **chỉ
/// đọc** — không có gì đã ghi để phải quay lui, không có bản ghi nào bị đánh
/// dấu (UC-11).
final class ExportCancelled extends ExportEvent {
  const ExportCancelled();
}

/// Đóng dialog.
final class ExportDismissed extends ExportEvent {
  const ExportDismissed();
}
