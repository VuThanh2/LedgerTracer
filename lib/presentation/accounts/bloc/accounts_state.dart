import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/account_view_model.dart';

/// Một lần xoá tài khoản đang chờ xác nhận (UC-01).
final class AccountDeletionConfirmation {
  const AccountDeletionConfirmation({
    required this.accountId,
    required this.displayName,
    required this.impact,
    this.isDeleting = false,
  });

  final int accountId;
  final String displayName;
  final AccountDeletionImpactViewModel impact;
  final bool isDeleting;

  AccountDeletionConfirmation deleting() => AccountDeletionConfirmation(
    accountId: accountId,
    displayName: displayName,
    impact: impact,
    isDeleting: true,
  );
}

/// Trạng thái màn hình quản lý tài khoản (UC-01).
final class AccountsState {
  const AccountsState({
    this.status = LoadStatus.initial,
    this.accounts = const <AccountViewModel>[],
    this.pendingDelete,
    this.notice,
    this.loadError,
  });

  final LoadStatus status;

  final List<AccountViewModel> accounts;

  final AccountDeletionConfirmation? pendingDelete;

  final TransientNotice? notice;

  final FeedbackMessage? loadError;

  bool get isEmpty => status.isReady && accounts.isEmpty;

  AccountsState copyWith({
    LoadStatus? status,
    List<AccountViewModel>? accounts,
    AccountDeletionConfirmation? pendingDelete,
    bool clearPendingDelete = false,
    TransientNotice? notice,
    FeedbackMessage? loadError,
    bool clearLoadError = false,
  }) => AccountsState(
    status: status ?? this.status,
    accounts: accounts ?? this.accounts,
    pendingDelete: clearPendingDelete
        ? null
        : (pendingDelete ?? this.pendingDelete),
    notice: notice ?? this.notice,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}
