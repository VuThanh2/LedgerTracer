import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../shared/bloc/load_status.dart';
import 'bloc/transaction_edit_bloc.dart';
import 'bloc/transaction_edit_event.dart';
import 'bloc/transaction_edit_state.dart';
import 'widgets/transaction_edit_form.dart';

/// Màn hình sửa một giao dịch (UC-05).
///
/// Là một route riêng trên cả hai nền tảng, kể cả ở Expanded nơi chi tiết mở
/// bằng pane: sửa là một phiên có trạng thái nháp và có thể bỏ dở, nên nó cần
/// một ranh giới rõ ràng để "quay lại" mang nghĩa "bỏ thay đổi".
///
/// Trả về `true` khi đã lưu, để màn danh sách biết mình phải nạp lại.
class TransactionEditPage extends StatelessWidget {
  const TransactionEditPage({required this.transactionId, super.key});

  final int transactionId;

  static Route<bool> route(BuildContext context, int transactionId) =>
      MaterialPageRoute<bool>(
        builder: (_) => TransactionEditPage(transactionId: transactionId),
      );

  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context);
    return BlocProvider<TransactionEditBloc>(
      create: (_) => TransactionEditBloc(
        editTransaction: dependencies.editTransaction,
        queryTransactions: dependencies.queryTransactions,
        deleteTransaction: dependencies.deleteTransaction,
        manageAccounts: dependencies.manageAccounts,
      )..add(TransactionEditStarted(transactionId)),
      child: const _TransactionEditView(),
    );
  }
}

class _TransactionEditView extends StatelessWidget {
  const _TransactionEditView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TransactionEditBloc, TransactionEditState>(
      listenWhen: (previous, current) => !previous.isSaved && current.isSaved,
      listener: (context, state) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final bloc = context.read<TransactionEditBloc>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit transaction'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: FilledButton(
                  onPressed: state.canSubmit
                      ? () => bloc.add(const TransactionEditSubmitted())
                      : null,
                  child: Text(state.isSubmitting ? 'Saving…' : 'Save'),
                ),
              ),
            ],
          ),
          body: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            LoadStatus.failed || LoadStatus.ready => TransactionEditForm(
              state: state,
              onDateChanged: (value) =>
                  bloc.add(TransactionEditDateChanged(value)),
              onAmountChanged: (value) =>
                  bloc.add(TransactionEditAmountChanged(value)),
              onDirectionChanged: (value) =>
                  bloc.add(TransactionEditDirectionChanged(value)),
              onCounterpartyChanged: (value) =>
                  bloc.add(TransactionEditCounterpartyChanged(value)),
              onDescriptionChanged: (value) =>
                  bloc.add(TransactionEditDescriptionChanged(value)),
            ),
          },
        );
      },
    );
  }
}
