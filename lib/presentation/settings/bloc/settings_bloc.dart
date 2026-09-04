import 'package:bloc/bloc.dart';

import '../../../application/settings/app_lock/app_lock_use_case.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import 'settings_event.dart';
import 'settings_state.dart';

/// Màn hình Thiết lập: **cấu hình** lớp khoá ứng dụng (UC-12).
///
/// Ba quy tắc dưới đây được thi hành ở đây chứ không ở giao diện, vì chúng là
/// luật chứ không phải cách trình bày:
///
/// * PIN mới phải được gõ hai lần khớp nhau. Đặt nhầm một mã PIN nghĩa là tự
///   khoá mình ra khỏi dữ liệu của chính mình, và đường ra duy nhất là xoá sạch
///   rồi khôi phục từ bản sao lưu.
/// * Đổi PIN và tắt khoá **luôn** đòi PIN hiện tại. Việc kiểm nằm ở tầng dưới;
///   việc của BLoC là không có đường nào đi vòng qua nó.
/// * Bật sinh trắc học đòi khoá đang bật và nền tảng có hỗ trợ. Sinh trắc học là
///   lớp mở nhanh đặt **trên** mã PIN, không phải thứ thay thế nó — cảm biến
///   hỏng không được khoá người dùng ra ngoài.
final class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({required AppLockUseCase appLock, this.hiddenTapsRequired = 7})
    : _lock = appLock,
      super(const SettingsState()) {
    on<SettingsStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    on<SettingsLockEnabled>(
      _onLockEnabled,
      transformer: EventTransformers.sequential(),
    );
    on<SettingsLockDisabled>(
      _onLockDisabled,
      transformer: EventTransformers.sequential(),
    );
    on<SettingsPinChanged>(
      _onPinChanged,
      transformer: EventTransformers.sequential(),
    );
    on<SettingsBiometricToggled>(
      _onBiometricToggled,
      transformer: EventTransformers.sequential(),
    );
    on<SettingsHiddenEntryTapped>(_onHiddenTapped);
  }

  final AppLockUseCase _lock;
  final NoticeSink _notices = NoticeSink();

  /// Số lần chạm để lộ mục vào màn hình chẩn đoán.
  final int hiddenTapsRequired;

  Future<void> _onStarted(
    SettingsStarted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearLoadError: true));
    await _reloadStatus(emit);
  }

  Future<void> _onLockEnabled(
    SettingsLockEnabled event,
    Emitter<SettingsState> emit,
  ) async {
    final mismatch = _pinMismatchError(event.pin, event.confirmPin);
    if (mismatch != null) {
      emit(state.copyWith(pinError: mismatch));
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearPinError: true));

    final result = await _lock.enableLock(event.pin);
    await _finishPinOperation(
      emit,
      result,
      successText:
          'App lock is on. If you forget the PIN the only way back in is to '
          'delete all local data, so make a backup first.',
    );
  }

  Future<void> _onLockDisabled(
    SettingsLockDisabled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearPinError: true));
    final result = await _lock.disableLock(event.currentPin);
    await _finishPinOperation(emit, result, successText: 'App lock is off.');
  }

  Future<void> _onPinChanged(
    SettingsPinChanged event,
    Emitter<SettingsState> emit,
  ) async {
    final mismatch = _pinMismatchError(event.newPin, event.confirmPin);
    if (mismatch != null) {
      emit(state.copyWith(pinError: mismatch));
      return;
    }
    emit(state.copyWith(isSubmitting: true, clearPinError: true));

    final result = await _lock.changePin(
      currentPin: event.currentPin,
      newPin: event.newPin,
    );
    await _finishPinOperation(emit, result, successText: 'PIN updated.');
  }

  Future<void> _onBiometricToggled(
    SettingsBiometricToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    final result = await _lock.setBiometric(event.enabled);
    switch (result) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            isSubmitting: false,
            notice: _noticeOf(failure, 'security settings'),
          ),
        );
      case Ok<void>():
        emit(
          state.copyWith(
            isSubmitting: false,
            notice: _notices.success(
              event.enabled
                  ? 'Biometric unlock is on. The PIN still works when the '
                        'sensor refuses.'
                  : 'Biometric unlock is off.',
            ),
          ),
        );
    }
    await _reloadStatus(emit);
  }

  void _onHiddenTapped(
    SettingsHiddenEntryTapped event,
    Emitter<SettingsState> emit,
  ) {
    if (state.diagnosticsUnlocked) return;
    final taps = state.hiddenTapCount + 1;
    emit(
      state.copyWith(
        hiddenTapCount: taps,
        diagnosticsUnlocked: taps >= hiddenTapsRequired,
        notice: taps >= hiddenTapsRequired
            ? _notices.info(
                'Developer diagnostics unlocked at the bottom of '
                'this page.',
              )
            : null,
      ),
    );
  }

  /// Kết thúc một thao tác đụng tới mã PIN.
  ///
  /// Sai PIN hiện tại về như `SecurityFailure`, và nó được gắn vào **ô nhập**
  /// chứ không ném lên một snackbar: người dùng đang đứng trước một biểu mẫu và
  /// việc cần làm là gõ lại, ngay tại chỗ.
  Future<void> _finishPinOperation(
    Emitter<SettingsState> emit,
    Result<void> result, {
    required String successText,
  }) async {
    switch (result) {
      case Err<void>(:final failure):
        final message = FailurePresenter.of(failure, context: 'PIN');
        final isWrongPin = failure is SecurityFailure;
        emit(
          state.copyWith(
            isSubmitting: false,
            pinError: isWrongPin ? message.text : null,
            // `clearPinError` chứ không phải truyền `null`: `copyWith` hiểu
            // `null` là "giữ nguyên", nên một thất bại **không** phải sai PIN sẽ
            // để lại nguyên câu "Sai mã PIN" của lần trước bên dưới ô nhập.
            clearPinError: !isWrongPin,
            notice: isWrongPin ? null : _notices.of(message),
          ),
        );
      case Ok<void>():
        emit(
          state.copyWith(
            isSubmitting: false,
            clearPinError: true,
            notice: _notices.success(successText),
          ),
        );
        await _reloadStatus(emit);
    }
  }

  Future<void> _reloadStatus(Emitter<SettingsState> emit) async {
    final result = await _lock.status();
    switch (result) {
      case Err<AppLockStatus>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            loadError: FailurePresenter.of(failure, context: 'settings'),
          ),
        );
      case Ok<AppLockStatus>(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            appLockEnabled: value.appLockEnabled,
            biometricEnabled: value.biometricEnabled,
            biometricAvailable: value.biometricAvailable,
          ),
        );
    }
  }

  String? _pinMismatchError(String pin, String confirmPin) {
    if (pin.isEmpty) return 'Enter a PIN.';
    if (pin != confirmPin) return 'The two PINs do not match.';
    return null;
  }

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}
