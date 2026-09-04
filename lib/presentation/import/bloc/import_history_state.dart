import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/import_history_view_model.dart';
import 'import_history_event.dart';

/// Một lần hoàn tác đang chờ người dùng xác nhận (UC-03 bước 4).
final class RevertConfirmation {
  const RevertConfirmation({
    required this.target,
    required this.id,
    required this.label,
    required this.impact,
    this.isReverting = false,
  });

  final RevertTarget target;
  final int id;

  /// Tên file hoặc mốc thời gian của lượt — để hộp thoại nói rõ đang hoàn tác
  /// cái gì, không chỉ "bản ghi này".
  final String label;

  final RevertImpactViewModel impact;

  final bool isReverting;

  RevertConfirmation reverting() => RevertConfirmation(
    target: target,
    id: id,
    label: label,
    impact: impact,
    isReverting: true,
  );
}

/// Trạng thái tab *Lịch sử* (UC-03).
final class ImportHistoryState {
  const ImportHistoryState({
    this.status = LoadStatus.initial,
    this.sessions = const <ImportSessionViewModel>[],
    this.expandedSessionIds = const <int>{},
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.pendingRevert,
    this.notice,
    this.loadError,
  });

  final LoadStatus status;

  /// Lượt gần nhất trước.
  final List<ImportSessionViewModel> sessions;

  /// Lượt nào đang mở ra xem các file con.
  final Set<int> expandedSessionIds;

  final int totalCount;
  final bool hasMore;
  final bool isLoadingMore;

  final RevertConfirmation? pendingRevert;

  final TransientNotice? notice;

  final FeedbackMessage? loadError;

  bool get isEmpty => status.isReady && sessions.isEmpty;

  ImportHistoryState copyWith({
    LoadStatus? status,
    List<ImportSessionViewModel>? sessions,
    Set<int>? expandedSessionIds,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    RevertConfirmation? pendingRevert,
    bool clearPendingRevert = false,
    TransientNotice? notice,
    FeedbackMessage? loadError,
    bool clearLoadError = false,
  }) => ImportHistoryState(
    status: status ?? this.status,
    sessions: sessions ?? this.sessions,
    expandedSessionIds: expandedSessionIds ?? this.expandedSessionIds,
    totalCount: totalCount ?? this.totalCount,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    pendingRevert: clearPendingRevert
        ? null
        : (pendingRevert ?? this.pendingRevert),
    notice: notice ?? this.notice,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}
