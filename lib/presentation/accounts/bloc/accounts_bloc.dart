import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/bank_account.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/failure_presenter.dart';
import '../view_models/account_view_model.dart';
import 'accounts_event.dart';
import 'accounts_state.dart';

/// Màn hình quản lý tài khoản ngân hàng (UC-01).
///
/// Tài khoản ở đây là **nhãn tự đặt**, không có kết nối hay xác thực nào với
/// ngân hàng thật — ứng dụng offline-first không có tài khoản người dùng, không
/// đăng nhập, không đồng bộ.
///
/// Xoá tài khoản là thao tác phá huỷ nhất của toàn ứng dụng: nó kéo theo giao
/// dịch, bản ghi nhập, cặp đối soát và phán quyết từ chối. Vì thế nó đi hai
/// nhịp, giống hoàn tác ở UC-03: hỏi hệ quả trước, xin xác nhận sau. Chuỗi xoá
/// dây chuyền do tầng dưới lo trong một transaction; việc của BLoC này chỉ là
/// không để một cú bấm thành một lần xoá.
final class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  AccountsBloc({required ManageAccountsUseCase manageAccounts})
    : _accounts = manageAccounts,
      super(const AccountsState()) {
    on<AccountsStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    // Mọi lệnh ghi đều tuần tự: hai lệnh chồng nhau thì lệnh sau đọc phải trạng
    // thái trước khi lệnh trước kịp xong.
    on<AccountAdded>(_onAdded, transformer: EventTransformers.sequential());
    on<AccountRenamed>(_onRenamed, transformer: EventTransformers.sequential());
    on<AccountNumberChanged>(
      _onNumberChanged,
      transformer: EventTransformers.sequential(),
    );
    on<AccountNumberCleared>(
      _onNumberCleared,
      transformer: EventTransformers.sequential(),
    );
    on<AccountDeleteRequested>(
      _onDeleteRequested,
      transformer: EventTransformers.sequential(),
    );
    on<AccountDeleteDismissed>(_onDeleteDismissed);
    on<AccountDeleteConfirmed>(
      _onDeleteConfirmed,
      transformer: EventTransformers.sequential(),
    );
  }

  final ManageAccountsUseCase _accounts;
  final NoticeSink _notices = NoticeSink();

  Future<void> _onStarted(
    AccountsStarted event,
    Emitter<AccountsState> emit,
  ) async {
    emit(state.copyWith(status: LoadStatus.loading, clearLoadError: true));
    await _reload(emit);
  }

  Future<void> _onAdded(AccountAdded event, Emitter<AccountsState> emit) async {
    final result = await _accounts.add(event.displayName);
    await _applyMutation(
      emit,
      result,
      onSuccess: (account) => 'Account "${account.displayName}" added.',
    );
  }

  Future<void> _onRenamed(
    AccountRenamed event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _accounts.rename(event.accountId, event.displayName);
    await _applyMutation(
      emit,
      result,
      onSuccess: (account) => 'Renamed to "${account.displayName}".',
    );
  }

  Future<void> _onNumberChanged(
    AccountNumberChanged event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _accounts.setAccountNumber(
      event.accountId,
      event.accountNumber,
    );
    await _applyMutation(
      emit,
      result,
      onSuccess: (account) =>
          'Account number updated. Later imports will check against it.',
    );
  }

  Future<void> _onNumberCleared(
    AccountNumberCleared event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _accounts.clearAccountNumber(event.accountId);
    await _applyMutation(
      emit,
      result,
      onSuccess: (_) =>
          'Account number cleared. The next import will learn it again from '
          'the statement file.',
    );
  }

  Future<void> _onDeleteRequested(
    AccountDeleteRequested event,
    Emitter<AccountsState> emit,
  ) async {
    final result = await _accounts.previewDeletion(event.accountId);
    switch (result) {
      case Err<AccountDeletionImpact>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'account')));
      case Ok<AccountDeletionImpact>(:final value):
        emit(
          state.copyWith(
            pendingDelete: AccountDeletionConfirmation(
              accountId: event.accountId,
              displayName: _nameOf(event.accountId),
              impact: AccountDeletionImpactViewModel.of(value),
            ),
          ),
        );
    }
  }

  void _onDeleteDismissed(
    AccountDeleteDismissed event,
    Emitter<AccountsState> emit,
  ) => emit(state.copyWith(clearPendingDelete: true));

  Future<void> _onDeleteConfirmed(
    AccountDeleteConfirmed event,
    Emitter<AccountsState> emit,
  ) async {
    final pending = state.pendingDelete;
    if (pending == null || pending.isDeleting) return;
    emit(state.copyWith(pendingDelete: pending.deleting()));

    final result = await _accounts.delete(pending.accountId);
    switch (result) {
      case Err<void>(:final failure):
        emit(
          state.copyWith(
            clearPendingDelete: true,
            notice: _noticeOf(failure, 'account'),
          ),
        );
      case Ok<void>():
        emit(
          state.copyWith(
            clearPendingDelete: true,
            notice: _notices.success(
              'Account "${pending.displayName}" and all of its data were '
              'deleted.',
            ),
          ),
        );
        await _reload(emit);
    }
  }

  /// Đọc lại danh sách sau mỗi lần ghi thành công.
  ///
  /// Đọc lại thay vì sửa tại chỗ, dù chỉ đổi một tên: `setAccountNumber` chuẩn
  /// hoá chuỗi trước khi lưu (bỏ dấu cách, viết hoa), nên thứ nằm trong cơ sở dữ
  /// liệu không phải thứ người dùng vừa gõ. Vẽ lại chuỗi họ gõ là hiển thị một
  /// giá trị không tồn tại ở đâu cả.
  Future<void> _applyMutation(
    Emitter<AccountsState> emit,
    Result<BankAccount> result, {
    required String Function(BankAccount account) onSuccess,
  }) async {
    switch (result) {
      case Err<BankAccount>(:final failure):
        emit(state.copyWith(notice: _noticeOf(failure, 'account')));
      case Ok<BankAccount>(:final value):
        emit(state.copyWith(notice: _notices.success(onSuccess(value))));
        await _reload(emit);
    }
  }

  Future<void> _reload(Emitter<AccountsState> emit) async {
    final result = await _accounts.list();
    switch (result) {
      case Err<List<BankAccount>>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            loadError: FailurePresenter.of(failure, context: 'account'),
          ),
        );
      case Ok<List<BankAccount>>(:final value):
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            accounts: <AccountViewModel>[
              for (final account in value)
                if (account.accountId != null) AccountViewModel.of(account),
            ],
          ),
        );
    }
  }

  String _nameOf(int accountId) {
    for (final account in state.accounts) {
      if (account.accountId == accountId) return account.displayName;
    }
    return '';
  }

  TransientNotice _noticeOf(Failure failure, String subject) =>
      _notices.of(FailurePresenter.of(failure, context: subject));
}
