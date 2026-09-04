import 'package:bloc/bloc.dart';

import '../../../application/import/prepare_import/prepare_import_dto.dart';
import '../../../application/settings/backup_restore/backup_restore_dto.dart';
import '../../../application/settings/backup_restore/backup_restore_use_case.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../ports/backup_file_picker.dart';
import '../view_models/backup_manifest_view_model.dart';
import 'backup_restore_event.dart';
import 'backup_restore_state.dart';

/// Màn hình Sao lưu & Khôi phục (UC-13).
///
/// Khôi phục đi **hai bước** và BLoC này giữ nguyên trình tự đó: [RestorePrepared]
/// giải mã và kiểm tra mà không đụng tới dữ liệu hiện có, [RestoreCommitted] mới
/// ghi đè. Kiểu tham số của `commitRestore` là thứ bảo đảm không có đường nào đi
/// tắt — nó chỉ nhận một `RestorePlan`, thứ chỉ ra đời từ bước kiểm.
///
/// Bản kế hoạch ấy — cùng khối bytes đã giải mã trong nó — nằm trong một trường
/// riêng của BLoC, **không** trong state: state là thứ giao diện đọc và là thứ
/// bị chụp lại trong log, còn đây là toàn bộ dữ liệu tài chính của người dùng.
final class BackupRestoreBloc
    extends Bloc<BackupRestoreEvent, BackupRestoreState> {
  BackupRestoreBloc({
    required BackupRestoreUseCase backupRestore,
    required BackupFilePicker filePicker,
  }) : _useCase = backupRestore,
       _picker = filePicker,
       super(const BackupRestoreState()) {
    on<BackupRestoreStarted>(_onStarted);
    on<BackupPasswordChanged>(_onBackupPasswordChanged);
    on<BackupRequested>(
      _onBackupRequested,
      transformer: EventTransformers.droppable(),
    );
    on<RestoreFilePicked>(
      _onFilePicked,
      transformer: EventTransformers.droppable(),
    );
    on<RestorePasswordChanged>(_onRestorePasswordChanged);
    on<RestorePrepared>(
      _onRestorePrepared,
      transformer: EventTransformers.droppable(),
    );
    on<RestoreDismissed>(_onRestoreDismissed);
    on<RestoreCommitted>(
      _onRestoreCommitted,
      transformer: EventTransformers.droppable(),
    );
  }

  final BackupRestoreUseCase _useCase;
  final BackupFilePicker _picker;
  final NoticeSink _notices = NoticeSink();

  /// File người dùng vừa chọn, chờ giải mã.
  PickedFile? _pickedFile;

  /// Bản khôi phục đã kiểm, chờ xác nhận ghi đè.
  RestorePlan? _plan;

  void _onStarted(
    BackupRestoreStarted event,
    Emitter<BackupRestoreState> emit,
  ) {
    _pickedFile = null;
    _plan = null;
    emit(const BackupRestoreState());
  }

  void _onBackupPasswordChanged(
    BackupPasswordChanged event,
    Emitter<BackupRestoreState> emit,
  ) => emit(
    state.copyWith(
      backupPassword: event.password,
      backupPasswordConfirm: event.confirm,
      clearBackupPasswordError: true,
    ),
  );

  Future<void> _onBackupRequested(
    BackupRequested event,
    Emitter<BackupRestoreState> emit,
  ) async {
    final error = _backupPasswordError();
    if (error != null) {
      emit(state.copyWith(backupPasswordError: error));
      return;
    }
    emit(state.copyWith(isBackingUp: true, clearBackupPasswordError: true));

    final result = await _useCase.backup(
      BackupRequest(password: state.backupPassword),
    );
    switch (result) {
      case Err<BackupResult>(:final failure):
        emit(
          state.copyWith(
            isBackingUp: false,
            notice: _notices.of(
              FailurePresenter.of(failure, context: 'backup'),
            ),
          ),
        );
      case Ok<BackupResult>(:final value):
        emit(
          state.copyWith(
            isBackingUp: false,
            savedLocationText: _locationTextOf(value.location),
            // Mất mật khẩu là mất luôn file — nhắc lại sau khi lưu, vì đây là
            // lúc người dùng còn nhớ mình vừa đặt cái gì.
            notice: _notices.success(
              'Backup created. Without that password the file cannot be opened '
              'again by any means.',
            ),
          ),
        );
    }
  }

  Future<void> _onFilePicked(
    RestoreFilePicked event,
    Emitter<BackupRestoreState> emit,
  ) async {
    final PickedFile? file;
    try {
      file = await _picker.pickBackup();
    } on Object catch (error) {
      emit(
        state.copyWith(
          notice: _notices.danger('Could not open the file picker: $error'),
        ),
      );
      return;
    }
    if (file == null) return;

    _pickedFile = file;
    _plan = null;
    emit(
      state.copyWith(
        pickedFileName: file.fileName,
        clearManifest: true,
        clearRestoreError: true,
      ),
    );
  }

  void _onRestorePasswordChanged(
    RestorePasswordChanged event,
    Emitter<BackupRestoreState> emit,
  ) => emit(
    state.copyWith(restorePassword: event.password, clearRestoreError: true),
  );

  Future<void> _onRestorePrepared(
    RestorePrepared event,
    Emitter<BackupRestoreState> emit,
  ) async {
    final file = _pickedFile;
    if (file == null || state.isPreparing) return;
    emit(state.copyWith(isPreparing: true, clearRestoreError: true));

    final result = await _useCase.prepareRestore(
      RestoreRequest(bytes: file.bytes, password: state.restorePassword),
    );
    switch (result) {
      case Err<RestorePlan>(:final failure):
        // Dừng lại đúng ở đây, khi dữ liệu hiện có còn nguyên vẹn.
        emit(
          state.copyWith(
            isPreparing: false,
            restoreError: FailurePresenter.of(failure, context: 'backup file'),
          ),
        );
      case Ok<RestorePlan>(:final value):
        _plan = value;
        emit(
          state.copyWith(
            isPreparing: false,
            manifest: BackupManifestViewModel.of(value.manifest),
          ),
        );
    }
  }

  void _onRestoreDismissed(
    RestoreDismissed event,
    Emitter<BackupRestoreState> emit,
  ) {
    _plan = null;
    emit(state.copyWith(clearManifest: true));
  }

  Future<void> _onRestoreCommitted(
    RestoreCommitted event,
    Emitter<BackupRestoreState> emit,
  ) async {
    final plan = _plan;
    if (plan == null || state.isRestoring) return;
    emit(state.copyWith(isRestoring: true));

    final result = await _useCase.commitRestore(plan);
    switch (result) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            isRestoring: false,
            restoreError: FailurePresenter.of(failure, context: 'backup'),
          ),
        );
      case Ok<void>():
        // Giữ lại khối bytes đã giải mã sau khi ghi xong là giữ một bản sao toàn
        // bộ dữ liệu trong bộ nhớ mà không ai còn cần tới.
        _plan = null;
        _pickedFile = null;
        emit(
          state.copyWith(
            isRestoring: false,
            isRestored: true,
            clearManifest: true,
            restorePassword: '',
            notice: _notices.success(
              'Restore finished. Everything that was here before is replaced.',
            ),
          ),
        );
    }
  }

  String? _backupPasswordError() {
    if (state.backupPassword.isEmpty) return 'Set a password for the file.';
    if (state.backupPassword != state.backupPasswordConfirm) {
      return 'The two passwords do not match.';
    }
    return null;
  }

  /// Nói đúng nơi file đã tới.
  ///
  /// Trên Web trình duyệt không cho chọn nơi lưu, nên câu chữ phải nói về cơ chế
  /// tải xuống thay vì đọc ra một đường dẫn không tồn tại (UC-13).
  String _locationTextOf(BackupLocation location) =>
      location.viaBrowserDownload || location.path == null
      ? 'Downloaded through the browser.'
      : 'Saved to ${location.path}';
}
