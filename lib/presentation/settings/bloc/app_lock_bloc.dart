import 'package:bloc/bloc.dart';

import '../../../application/settings/app_lock/app_lock_use_case.dart';
import '../../../application/settings/reset_app/reset_app_use_case.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/failures/feedback_message.dart';
import 'app_lock_event.dart';
import 'app_lock_state.dart';

/// Cổng khoá đặt trước toàn bộ ứng dụng (UC-12).
///
/// Tách khỏi `SettingsBloc` vì hai vòng đời khác hẳn nhau: BLoC này sống từ lúc
/// ứng dụng khởi động và là thứ quyết định có được vẽ nội dung hay không, còn
/// màn hình Thiết lập chỉ sống khi người dùng mở nó ra. Gộp lại nghĩa là cổng
/// khoá phụ thuộc vào một màn hình có thể chưa từng được mở.
///
/// Sinh trắc học là lớp mở nhanh đặt **trên** mã PIN, không thay thế nó: màn
/// hình khoá luôn có ô nhập PIN, và nút sinh trắc học chỉ là một lối tắt. Cảm
/// biến hỏng, ngón tay ướt, hay một nền tảng không có cảm biến đều không được
/// khoá người dùng ra khỏi dữ liệu của chính họ.
final class AppLockBloc extends Bloc<AppLockEvent, AppLockState> {
  AppLockBloc({
    required AppLockUseCase appLock,
    required ResetAppUseCase resetApp,
  }) : _lock = appLock,
       _reset = resetApp,
       super(const AppLockState()) {
    on<AppLockChecked>(_onChecked, transformer: EventTransformers.restartable());
    // Tuần tự: một mã PIN đang được kiểm là một phép băm chậm có chủ đích, và
    // hai lần kiểm chồng nhau chỉ làm nó chậm gấp đôi.
    on<AppLockPinSubmitted>(_onPinSubmitted, transformer: EventTransformers.sequential());
    // Hộp thoại sinh trắc học của hệ điều hành không được mở hai lần chồng nhau.
    on<AppLockBiometricRequested>(_onBiometricRequested, transformer: EventTransformers.droppable());
    on<AppLockResetRequested>(_onResetRequested);
    on<AppLockResetDismissed>(_onResetDismissed);
    on<AppLockResetConfirmationTyped>(_onResetConfirmationTyped);
    on<AppLockResetConfirmed>(_onResetConfirmed, transformer: EventTransformers.droppable());
  }

  final AppLockUseCase _lock;
  final ResetAppUseCase _reset;

  Future<void> _onChecked(
    AppLockChecked event,
    Emitter<AppLockState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearError: true));

    final result = await _lock.status();
    switch (result) {
      case Err<AppLockStatus>(:final failure):
        // Không đọc được thiết lập thì **khoá lại**, không mở ra. Đoán sai theo
        // hướng an toàn khiến người dùng phải gõ PIN; đoán sai theo hướng kia
        // mở toàn bộ dữ liệu cho bất kỳ ai đang cầm thiết bị.
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            gate: AppLockGate.locked,
            error: FailurePresenter.of(failure, context: 'thiết lập bảo mật'),
          ),
        );
      case Ok<AppLockStatus>(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            gate: value.appLockEnabled
                ? AppLockGate.locked
                : AppLockGate.unlocked,
            biometricEnabled: value.biometricEnabled,
            biometricAvailable: value.biometricAvailable,
          ),
        );
    }
  }

  Future<void> _onPinSubmitted(
    AppLockPinSubmitted event,
    Emitter<AppLockState> emit,
  ) async {
    if (state.isVerifying) return;
    emit(state.copyWith(isVerifying: true, clearPinError: true));

    final result = await _lock.unlockWithPin(event.pin);
    switch (result) {
      case Err<bool>(:final failure):
        emit(
          state.copyWith(
            isVerifying: false,
            pinError: FailurePresenter.of(failure, context: 'mã PIN').text,
          ),
        );
      case Ok<bool>(value: final unlocked):
        emit(
          state.copyWith(
            isVerifying: false,
            gate: unlocked ? AppLockGate.unlocked : state.gate,
            // Câu chữ không nói bí mật sai ở chỗ nào, và không đếm số lần sai:
            // đây là thiết bị của chính người dùng, không phải một dịch vụ cần
            // chống dò mật khẩu từ xa.
            pinError: unlocked ? null : 'Mã PIN không đúng.',
            clearPinError: unlocked,
          ),
        );
    }
  }

  Future<void> _onBiometricRequested(
    AppLockBiometricRequested event,
    Emitter<AppLockState> emit,
  ) async {
    if (!state.canUseBiometric || state.isVerifying) return;
    emit(state.copyWith(isVerifying: true, clearPinError: true));

    final result = await _lock.unlockWithBiometric();
    switch (result) {
      case Err<bool>(:final failure):
        emit(
          state.copyWith(
            isVerifying: false,
            error: FailurePresenter.of(failure, context: 'sinh trắc học'),
          ),
        );
      case Ok<bool>(value: final unlocked):
        emit(
          state.copyWith(
            isVerifying: false,
            gate: unlocked ? AppLockGate.unlocked : state.gate,
            // Cảm biến không nhận **không** phải một lỗi đáng báo động: ô nhập
            // PIN vẫn ở ngay đó và vẫn là đường vào chính.
            error: unlocked
                ? null
                : const FeedbackMessage.info(
                    'Không nhận được sinh trắc học. Hãy nhập mã PIN.',
                  ),
            clearError: unlocked,
          ),
        );
    }
  }

  void _onResetRequested(
    AppLockResetRequested event,
    Emitter<AppLockState> emit,
  ) => emit(
    state.copyWith(
      isResetPending: true,
      resetConfirmationText: '',
      clearError: true,
    ),
  );

  void _onResetDismissed(
    AppLockResetDismissed event,
    Emitter<AppLockState> emit,
  ) => emit(state.copyWith(isResetPending: false, resetConfirmationText: ''));

  void _onResetConfirmationTyped(
    AppLockResetConfirmationTyped event,
    Emitter<AppLockState> emit,
  ) => emit(state.copyWith(resetConfirmationText: event.text));

  Future<void> _onResetConfirmed(
    AppLockResetConfirmed event,
    Emitter<AppLockState> emit,
  ) async {
    // Chuỗi xác nhận được kiểm lại ở đây, không chỉ ở nút bấm: một nút bị vô
    // hiệu hoá là một gợi ý về giao diện, không phải một rào chắn.
    if (!state.isResetPending || !state.canConfirmReset || state.isResetting) {
      return;
    }
    emit(state.copyWith(isResetting: true));

    final result = await _reset.execute();
    switch (result) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            isResetting: false,
            error: FailurePresenter.of(failure, context: 'dữ liệu cục bộ'),
          ),
        );
      case Ok<void>():
        // Xoá sạch **bao gồm cả thiết lập và mã PIN** — đó là toàn bộ lý do
        // thao tác này tồn tại. Chừa lại thiết lập nghĩa là ứng dụng sau khi xoá
        // vẫn khoá bằng đúng mã PIN đã quên, và use case tự triệt tiêu.
        emit(
          const AppLockState(
            status: LoadStatus.ready,
            gate: AppLockGate.unlocked,
            error: FeedbackMessage.warning(
              'Đã xoá toàn bộ dữ liệu cục bộ. Khôi phục từ bản sao lưu nếu bạn '
              'có, ở Thiết lập › Dữ liệu.',
            ),
          ),
        );
    }
  }
}
