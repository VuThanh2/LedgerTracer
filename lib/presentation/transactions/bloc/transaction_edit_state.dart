import '../../shared/bloc/load_status.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/transaction_edit_draft.dart';

/// Trạng thái biểu mẫu sửa một giao dịch (UC-05).
final class TransactionEditState {
  const TransactionEditState({
    this.status = LoadStatus.initial,
    this.draft,
    this.validation,
    this.accountName = '',
    this.isInReconciledPair = false,
    this.isDirty = false,
    this.isSubmitting = false,
    this.savedCancellingPair,
    this.error,
  });

  final LoadStatus status;

  /// `null` cho tới khi giao dịch được nạp xong.
  final TransactionEditDraft? draft;

  /// Lỗi theo từng ô của lần bấm lưu gần nhất.
  final TransactionEditValidation? validation;

  /// Tài khoản của giao dịch — hiển thị nhưng không sửa được.
  final String accountName;

  /// Giao dịch đang thuộc một cặp đối soát.
  ///
  /// Cảnh báo hiện **ngay khi mở biểu mẫu**, không phải lúc bấm lưu: lưu xong
  /// mới báo "cặp đối soát vừa bị huỷ" là báo về một thứ không lùi lại được.
  /// Việc huỷ đó **không** được ghi thành phán quyết từ chối — người dùng đang
  /// sửa dữ liệu, không phủ nhận rằng hai giao dịch là một cặp (UC-05).
  final bool isInReconciledPair;

  final bool isDirty;

  final bool isSubmitting;

  /// Đã lưu xong. Giá trị nói cặp đối soát có bị huỷ theo hay không, để màn hình
  /// gọi báo đúng việc đã xảy ra; `null` nghĩa là chưa lưu.
  ///
  /// Là kiểu bool nullable chứ không phải một cờ `isSaved` riêng: hai thông tin
  /// ấy luôn đi cùng nhau, và tách ra là mở đường cho tổ hợp "chưa lưu nhưng đã
  /// huỷ cặp".
  final bool? savedCancellingPair;

  final FeedbackMessage? error;

  bool get isSaved => savedCancellingPair != null;

  /// Nút lưu có bấm được không.
  bool get canSubmit => draft != null && isDirty && !isSubmitting && !isSaved;

  TransactionEditState copyWith({
    LoadStatus? status,
    TransactionEditDraft? draft,
    TransactionEditValidation? validation,
    bool clearValidation = false,
    String? accountName,
    bool? isInReconciledPair,
    bool? isDirty,
    bool? isSubmitting,
    bool? savedCancellingPair,
    FeedbackMessage? error,
    bool clearError = false,
  }) => TransactionEditState(
    status: status ?? this.status,
    draft: draft ?? this.draft,
    validation: clearValidation ? null : (validation ?? this.validation),
    accountName: accountName ?? this.accountName,
    isInReconciledPair: isInReconciledPair ?? this.isInReconciledPair,
    isDirty: isDirty ?? this.isDirty,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    savedCancellingPair: savedCancellingPair ?? this.savedCancellingPair,
    error: clearError ? null : (error ?? this.error),
  );
}
