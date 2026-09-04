import 'package:bloc/bloc.dart';

import '../../../../application/export/export_dataset/export_dataset_dto.dart';
import '../../../../application/export/export_dataset/export_dataset_use_case.dart';
import '../../../../core/concurrency/cancellation_signal.dart';
import '../../../../core/result/result.dart';
import '../../bloc/event_transformers.dart';
import '../../failures/failure_presenter.dart';
import 'export_event.dart';
import 'export_state.dart';

/// Export Dialog — thành phần dùng chung với **năm điểm vào** (UC-11).
///
/// Một BLoC cho cả năm chứ không phải một đường xuất trong mỗi màn hình: chúng
/// dùng chung một luồng ba giai đoạn, một bộ quy tắc và một câu cảnh báo ("file
/// xuất không được mã hoá"). Chép nó ra năm chỗ là chép cả năm bản sẽ lệch nhau,
/// và lệch ở đây nghĩa là một file xuất mô tả sai chính dữ liệu bên trong nó.
///
/// Huỷ chỉ có nghĩa ở giai đoạn gom dữ liệu, và ở đó nó an toàn tuyệt đối: xuất
/// là thao tác **chỉ đọc**, không có gì đã ghi để phải quay lui.
final class ExportBloc extends Bloc<ExportEvent, ExportState> {
  ExportBloc({required ExportDatasetUseCase exportDataset})
    : _export = exportDataset,
      super(const ExportState()) {
    on<ExportOpened>(_onOpened);
    on<ExportFormatSelected>(_onFormatSelected);
    on<ExportRequested>(
      _onRequested,
      transformer: EventTransformers.droppable(),
    );
    on<ExportCancelled>(_onCancelled);
    on<ExportDismissed>(_onDismissed);
  }

  final ExportDatasetUseCase _export;

  CancellationSignal? _cancellation;

  @override
  Future<void> close() {
    _cancellation?.cancel();
    return super.close();
  }

  void _onOpened(ExportOpened event, Emitter<ExportState> emit) =>
      emit(ExportState(source: event.source, format: state.format));

  void _onFormatSelected(
    ExportFormatSelected event,
    Emitter<ExportState> emit,
  ) {
    if (state.isRunning) return;
    emit(state.copyWith(format: event.format));
  }

  Future<void> _onRequested(
    ExportRequested event,
    Emitter<ExportState> emit,
  ) async {
    final source = state.source;
    if (source == null || state.isRunning) return;

    final cancellation = CancellationSignal();
    _cancellation = cancellation;
    emit(
      state.copyWith(
        isRunning: true,
        isCancelling: false,
        stage: ExportStage.collecting,
        processed: 0,
        clearTotal: true,
        clearOutcome: true,
      ),
    );

    final result = await _export.execute(
      ExportDatasetRequest(
        dataset: source.toRequest(state.format),
        cancellation: cancellation,
      ),
      onProgress: (progress) {
        if (isClosed) return;
        emit(
          state.copyWith(
            stage: progress.stage,
            processed: progress.processed,
            total: progress.total,
            clearTotal: progress.total == null,
          ),
        );
      },
    );

    _cancellation = null;
    switch (result) {
      case Err<ExportResult>(:final failure):
        final message = FailurePresenter.of(failure, context: 'export');
        emit(
          state.copyWith(
            isRunning: false,
            isCancelling: false,
            clearStage: true,
            // Huỷ về như một `CancelledFailure`, và `FailurePresenter` đã dịch
            // nó thành một câu thông tin chứ không phải một câu báo lỗi — không
            // có gì hỏng cả, người dùng chỉ đổi ý.
            outcome: message,
          ),
        );
      case Ok<ExportResult>(:final value):
        emit(
          state.copyWith(
            isRunning: false,
            isCancelling: false,
            clearStage: true,
            rowCount: value.rowCount,
            savedLocationText: _locationTextOf(value.file),
          ),
        );
    }
  }

  void _onCancelled(ExportCancelled event, Emitter<ExportState> emit) {
    if (!state.canCancel || state.isCancelling) return;
    _cancellation?.cancel();
    emit(state.copyWith(isCancelling: true));
  }

  void _onDismissed(ExportDismissed event, Emitter<ExportState> emit) {
    _cancellation?.cancel();
    _cancellation = null;
    // Giữ lại [format] qua các lần mở: người xuất CSV lần này gần như chắc chắn
    // vẫn xuất CSV lần sau.
    emit(ExportState(format: state.format));
  }

  /// Trên Web trình duyệt không cho chọn nơi lưu, nên câu chữ nói về cơ chế tải
  /// xuống thay vì đọc ra một đường dẫn không tồn tại (UC-11).
  String _locationTextOf(SavedFile file) =>
      file.viaBrowserDownload || file.path == null
      ? 'Downloaded through the browser.'
      : 'Saved to ${file.path}';
}
