import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../domain/value_objects/pair_status.dart';
import '../shared/bloc/load_status.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import '../shell/bloc/app_shell_bloc.dart';
import '../shell/bloc/app_shell_event.dart';
import '../shell/view_models/navigation_intent.dart';
import 'bloc/transactions_bloc.dart';
import 'bloc/transactions_event.dart';
import 'bloc/transactions_state.dart';
import 'transaction_edit_page.dart';
import 'view_models/transaction_row_view_model.dart';
import 'widgets/delete_transaction_dialog.dart';
import 'widgets/transaction_detail_pane.dart';

/// Chi tiết giao dịch ở dạng route riêng — hình thái của breakpoint Compact.
///
/// Ở Expanded cùng nội dung này là pane bên phải; không có màn hình nào chỉ tồn
/// tại trên một nền tảng, chỉ có hai cách trình bày của cùng một nội dung.
///
/// Dùng lại `TransactionsBloc` của khung ứng dụng thay vì dựng một BLoC riêng:
/// chi tiết đang xem là một phần trạng thái của danh sách (`selectedId`,
/// `detail`), nên tách ra sẽ có hai nguồn sự thật cho cùng một câu hỏi.
class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({super.key});

  static Route<void> route(BuildContext context) {
    final transactions = context.read<TransactionsBloc>();
    return MaterialPageRoute<void>(
      builder: (_) => BlocProvider<TransactionsBloc>.value(
        value: transactions,
        child: const TransactionDetailPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocConsumer<TransactionsBloc, TransactionsState>(
        listenWhen: (previous, current) =>
            (previous.pendingDelete == null && current.pendingDelete != null) ||
            (previous.detail != null && current.detail == null),
        listener: (context, state) {
          // Giao dịch không còn: hoặc vừa bị xoá, hoặc vừa bị bỏ chọn. Cả hai
          // đều có nghĩa là route này không còn gì để hiển thị, nên đóng lại
          // thay vì đứng đó với một khung trống.
          if (state.detail == null) {
            Navigator.of(context).maybePop();
            return;
          }
          DeleteTransactionDialog.show(context);
        },
        builder: (context, state) {
          final detail = state.detail;
          return Scaffold(
            appBar: AppBar(title: const Text('Transaction')),
            body: switch ((state.detailStatus, detail)) {
              (LoadStatus.loading, _) || (LoadStatus.initial, _) =>
                const Center(child: CircularProgressIndicator()),
              // Đọc chi tiết hỏng là chuyện hồi phục được — thường là một lần
              // đọc đĩa lỗi, không phải dữ liệu biến mất. Không có nút thử lại
              // thì đường thoát duy nhất là quay ra rồi bấm lại đúng dòng đó
              // trong một danh sách hàng nghìn dòng.
              (LoadStatus.failed, _) => _DetailFailure(
                transactionId: state.selectedId,
              ),
              (_, null) => const Center(
                child: Text('This transaction is no longer there.'),
              ),
              (_, final TransactionDetailViewModel value) =>
                TransactionDetailPane(
                  detail: value,
                  onEdit: () => _openEditor(context, value.transactionId),
                  onDelete: () => context.read<TransactionsBloc>().add(
                    TransactionDeleteRequested(value.transactionId),
                  ),
                  onOpenReconciliation: () =>
                      _openReconciliation(context, value.confirmedPairId),
                ),
            },
          );
        },
      );

  Future<void> _openEditor(BuildContext context, int transactionId) async {
    final transactions = context.read<TransactionsBloc>();
    final saved = await Navigator.of(context)
        .push(TransactionEditPage.route(context, transactionId));
    if (saved ?? false) {
      transactions.add(
        TransactionsInvalidated(changedTransactionId: transactionId),
      );
    }
  }

  /// Quay về khung ứng dụng rồi chuyển sang tab Đối soát, mở sẵn đúng cặp.
  ///
  /// Nút này chỉ hiện khi giao dịch thuộc một cặp **đã xác nhận**, nên nhóm mở
  /// sẵn luôn là *Đã xác nhận* — mở đúng cặp ở một nhóm không chứa nó thì người
  /// dùng nhìn vào một danh sách rỗng.
  void _openReconciliation(BuildContext context, int? pairId) {
    context.read<AppShellBloc>().add(
      AppShellNavigationRequested(
        OpenReconciliation(focusPairId: pairId, status: PairStatus.confirmed),
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

/// Đọc chi tiết thất bại: nói ra và cho thử lại.
///
/// Trạng thái không phân biệt được "dòng đã bị xoá" với "lần đọc hỏng" — cả hai
/// đều là `failed`. Chữ ở đây nói cả hai khả năng thay vì đoán một cái: đoán sai
/// thì người dùng hoặc đi tìm một dòng không còn, hoặc bỏ cuộc trước một lỗi
/// tạm thời. Khi dòng thật sự đã mất, `TransactionsBloc` phát ra thông báo riêng
/// và màn danh sách tự nạp lại.
class _DetailFailure extends StatelessWidget {
  const _DetailFailure({required this.transactionId});

  final int? transactionId;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.screen),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const BannerMessage(
            FeedbackMessage.danger(
              'Could not open this transaction. It may have been deleted, or '
              'the read failed — try again to find out which.',
            ),
          ),
          const SizedBox(height: Gap.lg),
          OutlinedButton(
            onPressed: transactionId == null
                ? null
                : () => context.read<TransactionsBloc>().add(
                    TransactionDetailRequested(transactionId!),
                  ),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
