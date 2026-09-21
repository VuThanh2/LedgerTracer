import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../shared/bloc/load_status.dart';
import '../shared/responsive/breakpoints.dart';
import 'bloc/transaction_edit_bloc.dart';
import 'bloc/transaction_edit_event.dart';
import 'bloc/transaction_edit_state.dart';
import 'widgets/transaction_edit_form.dart';

/// Trình sửa một giao dịch (UC-05).
///
/// Sửa là một phiên có trạng thái nháp và có thể bỏ dở, nên nó luôn cần một
/// ranh giới rõ ràng để "đóng" mang nghĩa "bỏ thay đổi". Hình thái của ranh
/// giới đó đi theo bề rộng cửa sổ: một route đầy màn hình ở
/// [WindowSizeClass.compact], một hộp thoại ở các lớp rộng hơn. Form chỉ có năm
/// trường; trải nó ra cả bề ngang một màn hình desktop biến mỗi ô nhập thành
/// một dải rộng hơn nhiều lần nội dung nó nhận, và đẩy người dùng rời hẳn khỏi
/// danh sách mà họ vừa bấm sửa từ đó.
///
/// Trả về `true` khi đã lưu, để màn danh sách biết mình phải nạp lại.
class TransactionEditPage extends StatelessWidget {
  const TransactionEditPage({
    required this.transactionId,
    this.asDialog = false,
    super.key,
  });

  final int transactionId;

  /// Vỏ ngoài là hộp thoại thay vì [Scaffold] đầy màn hình.
  final bool asDialog;

  static Route<bool> route(BuildContext context, int transactionId) =>
      MaterialPageRoute<bool>(
        builder: (_) => TransactionEditPage(transactionId: transactionId),
      );

  /// Mở trình sửa ở hình thái hợp với bề rộng cửa sổ.
  ///
  /// Là điểm vào **duy nhất**: để mỗi nơi gọi tự chọn route hay dialog là cách
  /// hai màn hình mở cùng một việc theo hai kiểu khác nhau.
  static Future<bool?> open(BuildContext context, int transactionId) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);
    if (sizeClass == WindowSizeClass.compact) {
      return Navigator.of(context).push(route(context, transactionId));
    }
    // `showDialog` mở bằng một lần mờ dần 150ms, không có chuyển động — ở cỡ
    // một hộp thoại form thì nó đọc như hộp thoại "nảy" ra tại chỗ. Đổi sang
    // một route riêng để nắm cả thời lượng lẫn đường cong: mờ dần cộng một
    // đoạn trượt lên ngắn, đủ để mắt bám được hộp thoại từ lúc nó xuất hiện.
    final navigator = Navigator.of(context, rootNavigator: true);
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    return navigator.push(
      RawDialogRoute<bool>(
        // Chạm ra ngoài **không** đóng hộp thoại: ở đây nó sẽ vứt bản nháp đang
        // gõ mà không hỏi. Đường lùi là nút Cancel, một hành động có chủ ý.
        barrierDismissible: false,
        barrierLabel: MaterialLocalizations.of(context)
            .modalBarrierDismissLabel,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 220),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.035),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        pageBuilder: (_, _, _) => themes.wrap(
          SafeArea(
            child: TransactionEditPage(
              transactionId: transactionId,
              asDialog: true,
            ),
          ),
        ),
      ),
    );
  }

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
      child: _TransactionEditView(asDialog: asDialog),
    );
  }
}

class _TransactionEditView extends StatelessWidget {
  const _TransactionEditView({required this.asDialog});

  final bool asDialog;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TransactionEditBloc, TransactionEditState>(
      listenWhen: (previous, current) => !previous.isSaved && current.isSaved,
      listener: (context, state) => Navigator.of(context).pop(true),
      builder: (context, state) {
        final bloc = context.read<TransactionEditBloc>();
        final isLoading =
            state.status == LoadStatus.initial ||
            state.status == LoadStatus.loading;

        // Một nút Lưu duy nhất, đặt ở hai chỗ khác nhau: điều kiện bật/tắt của
        // nó là luật nghiệp vụ, và nhân đôi nó là cách hai hình thái trôi ra
        // hai hành vi.
        final saveButton = FilledButton(
          onPressed: state.canSubmit
              ? () => bloc.add(const TransactionEditSubmitted())
              : null,
          child: Text(state.isSubmitting ? 'Saving…' : 'Save'),
        );
        final form = TransactionEditForm(
          state: state,
          inDialog: asDialog,
          onDateChanged: (value) => bloc.add(TransactionEditDateChanged(value)),
          onAmountChanged: (value) =>
              bloc.add(TransactionEditAmountChanged(value)),
          onDirectionChanged: (value) =>
              bloc.add(TransactionEditDirectionChanged(value)),
          onCounterpartyChanged: (value) =>
              bloc.add(TransactionEditCounterpartyChanged(value)),
          onDescriptionChanged: (value) =>
              bloc.add(TransactionEditDescriptionChanged(value)),
        );

        if (asDialog) {
          return AlertDialog(
            scrollable: true,
            title: const Text('Edit transaction'),
            // Bề rộng đủ cho một dòng memo của sao kê ngân hàng, không hơn: ô
            // nhập rộng hơn nội dung nó nhận là khoảng trống, không phải sự
            // thoáng đãng. Chốt cứng thay vì thả theo `IntrinsicWidth` của
            // [AlertDialog], nếu không hộp thoại rộng hẹp khác nhau tuỳ độ dài
            // memo của đúng dòng đang sửa.
            content: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 112).clamp(
                280.0,
                520.0,
              ),
              // Bản nháp nạp xong sau ít nhất một khung hình, nên nội dung
              // chuyển từ vòng quay sang form khi hộp thoại đã mở. Không có
              // [AnimatedSize] thì hộp thoại giật một nấc cao ngay lúc đó —
              // đúng khoảnh khắc mắt đang bám vào nó.
              child: AnimatedSize(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: isLoading
                    ? const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : form,
              ),
            ),
            actions: <Widget>[
              OutlinedButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              saveButton,
            ],
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit transaction'),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
                child: saveButton,
              ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : form,
        );
      },
    );
  }
}
