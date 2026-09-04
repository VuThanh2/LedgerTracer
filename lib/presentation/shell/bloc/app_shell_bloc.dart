import 'package:bloc/bloc.dart';

import '../../../application/import/recover_interrupted_imports/recover_interrupted_imports_dto.dart';
import '../../../application/import/recover_interrupted_imports/recover_interrupted_imports_use_case.dart';
import '../../../core/concurrency/platform_capabilities.dart';
import '../../../core/result/result.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/navigation_intent.dart';
import 'app_shell_event.dart';
import 'app_shell_state.dart';

/// Khung điều hướng bao ngoài toàn bộ ứng dụng.
///
/// Hai việc, và cả hai đều không thuộc về màn hình nào cụ thể:
///
/// * **Dọn dẹp lúc khởi động.** Các lượt nhập còn dở từ một tiến trình đã chết
///   phải được nhận ra ở đây, đúng một lần, và trước khi bất kỳ màn hình nào đọc
///   lịch sử. Suy luận này chỉ đúng tại thời điểm khởi động: chỉ có một tiến
///   trình, một cơ sở dữ liệu, một người dùng — nên mọi lượt còn ở trạng thái
///   đang chạy đều là mồ côi, chắc chắn chứ không phải nhiều khả năng.
/// * **Điều hướng có mang ngữ cảnh.** Khoan xuống từ Thống kê, xem giao dịch của
///   một lượt nhập, mở cặp đối soát từ chi tiết giao dịch — ba đường đi giữa các
///   ô điều hướng, mỗi đường mang theo một mảnh ngữ cảnh phải tới được đích
///   nguyên vẹn. Cho các màn hình gọi thẳng nhau nghĩa là mỗi màn hình phải biết
///   những màn hình còn lại; qua đây thì chúng chỉ cần biết một kiểu ngữ cảnh.
final class AppShellBloc extends Bloc<AppShellEvent, AppShellState> {
  AppShellBloc({
    required RecoverInterruptedImportsUseCase recoverImports,
    required this.capabilities,
  }) : _recover = recoverImports,
       super(const AppShellState()) {
    on<AppShellStarted>(_onStarted, transformer: EventTransformers.droppable());
    on<AppShellDestinationSelected>(_onDestinationSelected);
    on<AppShellNavigationRequested>(_onNavigationRequested);
    on<AppShellNavigationConsumed>(_onNavigationConsumed);
    on<AppShellRecoveryNoticeDismissed>(_onRecoveryDismissed);
  }

  final RecoverInterruptedImportsUseCase _recover;

  final PlatformCapabilities capabilities;

  int _navigationSequence = 0;

  Future<void> _onStarted(
    AppShellStarted event,
    Emitter<AppShellState> emit,
  ) async {
    emit(
      state.copyWith(
        status: LoadStatus.loading,
        supportsIsolates: capabilities.supportsIsolates,
      ),
    );

    final result = await _recover.execute();
    switch (result) {
      case Err<ImportRecoveryReport>(:final failure):
        // Dọn dẹp thất bại **không** chặn ứng dụng khởi động: hệ quả tệ nhất là
        // một lượt nhập cũ hiện sai trạng thái trong lịch sử, còn chặn màn hình
        // chính lại vì nó là đổi một phiền toái nhỏ lấy một ứng dụng không mở
        // được.
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            recoveryNotice: FailurePresenter.of(
              failure,
              context: 'import history',
            ),
          ),
        );
      case Ok<ImportRecoveryReport>(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            recoveryNotice: value.hasInterruptedSessions
                ? _interruptedNoticeOf(value)
                : null,
            // Không có lượt nào bị gián đoạn thì **xoá** thông báo, không phải
            // để `copyWith` hiểu `null` là "giữ nguyên" — lượt dọn dẹp lần này
            // sạch mà banner của lần trước vẫn treo là một thông báo nói dối.
            clearRecoveryNotice: !value.hasInterruptedSessions,
          ),
        );
    }
  }

  void _onDestinationSelected(
    AppShellDestinationSelected event,
    Emitter<AppShellState> emit,
  ) {
    if (event.destination == state.destination) return;
    // Chuyển ô bằng tay **xoá** yêu cầu điều hướng còn treo: người dùng vừa nói
    // rõ mình muốn đi đâu, và áp một ngữ cảnh cũ lên đó là ghi đè lên ý định vừa
    // được nói ra.
    emit(
      state.copyWith(
        destination: event.destination,
        clearPendingNavigation: true,
      ),
    );
  }

  void _onNavigationRequested(
    AppShellNavigationRequested event,
    Emitter<AppShellState> emit,
  ) => emit(
    state.copyWith(
      destination: event.intent.destination,
      pendingNavigation: PendingNavigation(event.intent, ++_navigationSequence),
    ),
  );

  void _onNavigationConsumed(
    AppShellNavigationConsumed event,
    Emitter<AppShellState> emit,
  ) => emit(state.copyWith(clearPendingNavigation: true));

  void _onRecoveryDismissed(
    AppShellRecoveryNoticeDismissed event,
    Emitter<AppShellState> emit,
  ) => emit(state.copyWith(clearRecoveryNotice: true));

  /// Câu báo về các lượt bị gián đoạn.
  ///
  /// Nói ra cả ba điều người dùng cần: chuyện gì đã xảy ra, phần đã ghi vẫn còn,
  /// và nhập lại thì an toàn — vế cuối đúng vì chống trùng là phép **đếm**, nên
  /// nhập lại nguyên file chỉ bổ sung phần còn thiếu (UC-02, UC-03).
  FeedbackMessage _interruptedNoticeOf(ImportRecoveryReport report) {
    final count = report.interruptedSessionCount;
    return FeedbackMessage.warning(
      '$count import runs were interrupted last time. Committed rows are kept; '
      'importing those same files again only fills in what is missing.',
    );
  }
}
