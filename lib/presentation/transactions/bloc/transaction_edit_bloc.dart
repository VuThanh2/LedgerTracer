import 'package:bloc/bloc.dart';

import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../application/transactions/delete_transaction/delete_transaction_use_case.dart';
import '../../../application/transactions/edit_transaction/edit_transaction_dto.dart';
import '../../../application/transactions/edit_transaction/edit_transaction_use_case.dart';
import '../../../application/transactions/query_transactions/query_transactions_use_case.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/transaction.dart';
import '../../shared/bloc/event_transformers.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/failures/failure_presenter.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/transaction_edit_draft.dart';
import 'transaction_edit_event.dart';
import 'transaction_edit_state.dart';

/// Biểu mẫu sửa một giao dịch bị nhập sai (UC-05).
///
/// Tách khỏi `TransactionsBloc` chứ không gộp vào, và lý do là **vòng đời**: một
/// biểu mẫu sống từ lúc mở tới lúc lưu hoặc bỏ, mang trạng thái dở dang của
/// riêng nó (đã gõ tới đâu, ô nào sai, có dirty chưa), và bị vứt đi nguyên vẹn
/// khi đóng. Danh sách thì sống suốt thời gian màn hình mở. Gộp lại nghĩa là
/// trạng thái biểu mẫu phải được dọn tay ở mọi đường thoát, và chỗ quên dọn
/// chính là chỗ mở lại biểu mẫu thấy chữ của lần trước.
///
/// Kết quả một lần lưu được để lại trong state (`savedCancellingPair`); màn hình
/// gọi đọc nó rồi bắn `TransactionsInvalidated` sang BLoC danh sách. Hai BLoC
/// không gọi thẳng nhau — chúng không biết nhau tồn tại, và đó là điều kiện để
/// biểu mẫu này mở được từ cả pane phải lẫn một route riêng.
final class TransactionEditBloc
    extends Bloc<TransactionEditEvent, TransactionEditState> {
  TransactionEditBloc({
    required EditTransactionUseCase editTransaction,
    required QueryTransactionsUseCase queryTransactions,
    required DeleteTransactionUseCase deleteTransaction,
    required ManageAccountsUseCase manageAccounts,
  }) : _edit = editTransaction,
       _query = queryTransactions,
       _pairs = deleteTransaction,
       _accounts = manageAccounts,
       super(const TransactionEditState()) {
    on<TransactionEditStarted>(
      _onStarted,
      transformer: EventTransformers.restartable(),
    );
    on<TransactionEditDateChanged>(
      (event, emit) => _mutate(
        emit,
        (draft) => draft.copyWith(bookingDate: event.bookingDate),
      ),
    );
    on<TransactionEditAmountChanged>(
      (event, emit) => _mutate(
        emit,
        (draft) => draft.copyWith(amountText: event.amountText),
      ),
    );
    on<TransactionEditDirectionChanged>(
      (event, emit) =>
          _mutate(emit, (draft) => draft.copyWith(direction: event.direction)),
    );
    on<TransactionEditCurrencyChanged>(
      (event, emit) =>
          _mutate(emit, (draft) => draft.copyWith(currency: event.currency)),
    );
    on<TransactionEditCounterpartyChanged>(
      (event, emit) => _mutate(
        emit,
        (draft) => draft.copyWith(counterpartyName: event.counterpartyName),
      ),
    );
    on<TransactionEditDescriptionChanged>(
      (event, emit) => _mutate(
        emit,
        (draft) => draft.copyWith(description: event.description),
      ),
    );
    // Tuần tự: hai lần bấm lưu liên tiếp không được thành hai lần ghi.
    on<TransactionEditSubmitted>(
      _onSubmitted,
      transformer: EventTransformers.sequential(),
    );
  }

  final EditTransactionUseCase _edit;
  final QueryTransactionsUseCase _query;
  final DeleteTransactionUseCase _pairs;
  final ManageAccountsUseCase _accounts;

  /// Bản gốc, giữ để so xem biểu mẫu đã đổi gì chưa.
  Transaction? _original;

  Future<void> _onStarted(
    TransactionEditStarted event,
    Emitter<TransactionEditState> emit,
  ) async {
    emit(const TransactionEditState(status: LoadStatus.loading));

    final loaded = await _query.findById(event.transactionId);
    switch (loaded) {
      case Err<Transaction?>(:final failure):
        emit(
          state.copyWith(
            status: LoadStatus.failed,
            error: FailurePresenter.of(failure, context: 'transaction'),
          ),
        );
        return;
      case Ok<Transaction?>(value: final tx):
        if (tx == null) {
          emit(
            state.copyWith(status: LoadStatus.failed, error: _transactionGone),
          );
          return;
        }
        _original = tx;
        emit(
          state.copyWith(
            status: LoadStatus.ready,
            draft: TransactionEditDraft.of(tx),
            accountName: await _accountName(tx.accountId),
            // Cảnh báo được dựng ngay lúc mở, không đợi tới lúc lưu (UC-05).
            isInReconciledPair:
                (await _pairs.isInPair(event.transactionId)).valueOrNull ??
                false,
            isDirty: false,
          ),
        );
    }
  }

  /// Sửa một ô: cập nhật bản nháp, tính lại cờ dirty, và **xoá lỗi cũ**.
  ///
  /// Xoá lỗi ngay khi gõ chứ không đợi bấm lưu lần nữa: một thông báo lỗi còn
  /// treo bên dưới ô mà người dùng vừa sửa xong là thông báo nói về quá khứ.
  void _mutate(
    Emitter<TransactionEditState> emit,
    TransactionEditDraft Function(TransactionEditDraft draft) change,
  ) {
    final draft = state.draft;
    final original = _original;
    if (draft == null || original == null || state.isSaved) return;
    final updated = change(draft);
    emit(
      state.copyWith(
        draft: updated,
        isDirty: updated.isDirtyAgainst(original),
        clearValidation: true,
        clearError: true,
      ),
    );
  }

  Future<void> _onSubmitted(
    TransactionEditSubmitted event,
    Emitter<TransactionEditState> emit,
  ) async {
    final draft = state.draft;
    if (draft == null || state.isSubmitting || state.isSaved) return;

    final validation = draft.validate();
    if (!validation.isValid) {
      emit(state.copyWith(validation: validation));
      return;
    }

    emit(
      state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearValidation: true,
      ),
    );
    final result = await _edit.execute(validation.request!);
    switch (result) {
      case Err<EditTransactionResult>(:final failure):
        emit(
          state.copyWith(
            isSubmitting: false,
            error: FailurePresenter.of(failure, context: 'transaction'),
          ),
        );
      case Ok<EditTransactionResult>(:final value):
        _original = value.transaction;
        emit(
          state.copyWith(
            isSubmitting: false,
            isDirty: false,
            draft: TransactionEditDraft.of(value.transaction),
            savedCancellingPair: value.cancelledReconciliation,
          ),
        );
    }
  }

  Future<String> _accountName(int accountId) async {
    final accounts = (await _accounts.list()).valueOrNull;
    if (accounts == null) return '';
    for (final account in accounts) {
      if (account.accountId == accountId) return account.displayName;
    }
    return '';
  }
}

/// Giao dịch đã biến mất giữa lúc mở biểu mẫu.
///
/// Không đi qua `FailurePresenter` vì ở đây không có `Failure` nào để dịch: use
/// case trả về `null` — "không tìm thấy" là một **kết quả** hợp lệ của một phép
/// đọc, không phải một thất bại. Câu chữ vẫn phải trùng ý với nhánh
/// `NotFoundFailure`: thứ người dùng cần làm là như nhau.
const FeedbackMessage _transactionGone = FeedbackMessage.warning(
  'This transaction no longer exists. It may have been deleted, or the import '
  'run that created it was reverted.',
);
