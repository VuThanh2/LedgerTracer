import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/empty_state.dart';
import 'bloc/accounts_bloc.dart';
import 'bloc/accounts_event.dart';
import 'bloc/accounts_state.dart';
import 'view_models/account_view_model.dart';
import 'widgets/account_form_dialog.dart';
import 'widgets/account_list_tile.dart';
import 'widgets/delete_account_dialog.dart';

/// Màn Quản lý tài khoản (UC-01), vào từ Cài đặt.
///
/// BLoC được dựng ngay tại route này chứ không sống cùng khung ứng dụng: đây là
/// việc làm một lần rồi thôi, và giữ danh sách tài khoản trong bộ nhớ suốt phiên
/// chỉ để dùng vài phút là trả giá bằng một bản sao có thể cũ đi.
class AccountsPage extends StatelessWidget {
  const AccountsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AccountsPage());

  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context);
    return BlocProvider<AccountsBloc>(
      create: (_) =>
          AccountsBloc(manageAccounts: dependencies.manageAccounts)
            ..add(const AccountsStarted()),
      child: const _AccountsView(),
    );
  }
}

class _AccountsView extends StatelessWidget {
  const _AccountsView();

  Future<void> _openForm(
    BuildContext context, {
    AccountViewModel? account,
  }) async {
    final bloc = context.read<AccountsBloc>();
    final result = await AccountFormDialog.show(context, account: account);
    if (result == null) return;

    if (account == null) {
      bloc.add(AccountAdded(result.displayName));
      return;
    }

    if (result.displayName != account.displayName) {
      bloc.add(
        AccountRenamed(
          accountId: account.accountId,
          displayName: result.displayName,
        ),
      );
    }
    if (result.clearAccountNumber) {
      bloc.add(AccountNumberCleared(account.accountId));
    } else if (result.accountNumber case final String number) {
      bloc.add(
        AccountNumberChanged(
          accountId: account.accountId,
          accountNumber: number,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank accounts'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => _openForm(context),
                child: const Text('Add account'),
              ),
            ),
          ),
        ],
      ),
      body: BlocConsumer<AccountsBloc, AccountsState>(
        listenWhen: (previous, current) =>
            previous.notice != current.notice ||
            (previous.pendingDelete == null && current.pendingDelete != null),
        listener: (context, state) {
          if (state.pendingDelete != null) {
            DeleteAccountDialog.show(context);
            return;
          }
          if (state.notice case final notice?) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.message.text)));
          }
        },
        builder: (context, state) {
          if (state.status.isInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(Gap.screen),
            children: <Widget>[
              if (state.loadError case final FeedbackMessage error) ...<Widget>[
                BannerMessage(error),
                const SizedBox(height: Gap.lg),
              ],
              Text(
                'Account numbers are learned from imported files. Fix one here '
                'if a file taught the wrong number.',
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
              const SizedBox(height: Gap.lg),
              if (state.isEmpty)
                EmptyState(
                  title: 'No accounts declared yet',
                  message:
                      'An account is where the transactions of a statement '
                      'file land. Create one to start importing.',
                  icon: Icons.account_balance_outlined,
                  actionLabel: 'Add account',
                  onAction: () => _openForm(context),
                )
              else
                for (final account in state.accounts) ...<Widget>[
                  AccountListTile(
                    account: account,
                    onEdit: () => _openForm(context, account: account),
                    onDelete: () => context.read<AccountsBloc>().add(
                      AccountDeleteRequested(account.accountId),
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                ],
            ],
          );
        },
      ),
    );
  }
}
