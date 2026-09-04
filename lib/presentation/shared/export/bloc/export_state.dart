import '../../../../application/export/export_dataset/export_dataset_dto.dart';
import '../../failures/feedback_message.dart';
import '../../failures/platform_notices.dart';
import '../view_models/export_source.dart';

/// Trạng thái Export Dialog (UC-11).
final class ExportState {
  const ExportState({
    this.source,
    this.format = ExportFormat.csv,
    this.stage,
    this.processed = 0,
    this.total,
    this.isRunning = false,
    this.isCancelling = false,
    this.savedLocationText,
    this.rowCount,
    this.outcome,
  });

  /// Cảnh báo phải hiện ngay trong dialog, ở mọi điểm vào (UC-11).
  static const FeedbackMessage notEncryptedWarning =
      PlatformNotices.exportNotEncrypted;

  /// `null` khi dialog đóng.
  final ExportSource? source;

  /// CSV là mặc định: nó mở được bằng mọi thứ, kể cả khi người nhận không có
  /// Excel. Người cần Excel biết mình cần Excel.
  final ExportFormat format;

  final ExportStage? stage;

  final int processed;

  final int? total;

  final bool isRunning;

  final bool isCancelling;

  /// Nơi file đã tới; `null` khi chưa xuất xong.
  final String? savedLocationText;

  final int? rowCount;

  /// Kết cục của lần xuất gần nhất.
  ///
  /// **Không** tên là `error`: huỷ cũng về qua đây, và huỷ là một kết cục chứ
  /// không phải một lỗi — `FailurePresenter` đã dịch nó thành một câu thông tin.
  /// Mức độ nằm trong chính [FeedbackMessage.severity]; đặt tên trường là "lỗi"
  /// sẽ mời giao diện tô đỏ một câu nói "bạn vừa bấm dừng".
  final FeedbackMessage? outcome;

  bool get isOpen => source != null;

  bool get isDone => savedLocationText != null;

  /// Chỉ giai đoạn gom dữ liệu mới huỷ được: mã hoá chạy trong một isolate như
  /// một lượt duy nhất, và lưu file thì đã nằm trong tay nền tảng.
  bool get canCancel => isRunning && stage == ExportStage.collecting;

  double? get fraction {
    final expected = total;
    if (expected == null || expected <= 0) return null;
    final ratio = processed / expected;
    return ratio > 1 ? 1 : ratio;
  }

  String get stageLabel => switch (stage) {
    ExportStage.collecting => 'Collecting rows…',
    ExportStage.encoding => 'Encoding the file…',
    ExportStage.saving => 'Saving…',
    null => '',
  };

  ExportState copyWith({
    ExportSource? source,
    bool clearSource = false,
    ExportFormat? format,
    ExportStage? stage,
    bool clearStage = false,
    int? processed,
    int? total,
    bool clearTotal = false,
    bool? isRunning,
    bool? isCancelling,
    String? savedLocationText,
    int? rowCount,
    FeedbackMessage? outcome,
    bool clearOutcome = false,
  }) => ExportState(
    source: clearSource ? null : (source ?? this.source),
    format: format ?? this.format,
    stage: clearStage ? null : (stage ?? this.stage),
    processed: processed ?? this.processed,
    total: clearTotal ? null : (total ?? this.total),
    isRunning: isRunning ?? this.isRunning,
    isCancelling: isCancelling ?? this.isCancelling,
    savedLocationText: savedLocationText ?? this.savedLocationText,
    rowCount: rowCount ?? this.rowCount,
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
  );
}
