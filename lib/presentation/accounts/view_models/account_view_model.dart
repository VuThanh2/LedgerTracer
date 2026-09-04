import '../../../application/accounts/manage_accounts/manage_accounts_use_case.dart';
import '../../../domain/entities/bank_account.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/number_formatter.dart';

/// Một tài khoản trong danh sách quản lý (UC-01).
final class AccountViewModel {
  const AccountViewModel({
    required this.accountId,
    required this.displayName,
    required this.accountNumber,
    required this.hasAccountNumber,
    required this.createdAtText,
  });

  factory AccountViewModel.of(BankAccount account) => AccountViewModel(
    accountId: account.accountId!,
    displayName: account.displayName,
    // Số tài khoản **không phải trường người dùng tự khai khi tạo**: nó được học
    // từ file sao kê đầu tiên có mang nó. Màn hình này chỉ hiển thị số đã học và
    // cho sửa/xoá phòng khi học nhầm (UC-01, UC-02 bước 4).
    accountNumber: account.accountNumber ?? '',
    hasAccountNumber: account.hasAccountNumber,
    createdAtText: DateFormatter.day(account.createdAt),
  );

  final int accountId;
  final String displayName;
  final String accountNumber;
  final bool hasAccountNumber;
  final String createdAtText;
}

/// Những gì việc xoá một tài khoản sẽ động tới, đã thành chữ (UC-01).
final class AccountDeletionImpactViewModel {
  const AccountDeletionImpactViewModel({
    required this.transactionText,
    required this.reconciledPairText,
    required this.reconciledPairCount,
  });

  factory AccountDeletionImpactViewModel.of(AccountDeletionImpact impact) =>
      AccountDeletionImpactViewModel(
        transactionText: NumberFormatter.count(impact.transactionCount),
        reconciledPairText: NumberFormatter.count(impact.reconciledPairCount),
        reconciledPairCount: impact.reconciledPairCount,
      );

  final String transactionText;
  final String reconciledPairText;
  final int reconciledPairCount;

  bool get cancelsPairs => reconciledPairCount > 0;
}

/// Nội dung Account Form Dialog **đang được gõ** (UC-01).
///
/// Dialog này có **hai điểm vào** — màn hình quản lý tài khoản và bước 2 của
/// luồng nhập — và đó chính là lý do bản nháp cùng phép kiểm của nó nằm ở một
/// lớp riêng thay vì trong state của một trong hai BLoC: hai bản chép tay của
/// cùng một quy tắc là hai chỗ sẽ nhận hai tập giá trị khác nhau.
final class AccountFormDraft {
  const AccountFormDraft({this.accountId, this.displayName = ''});

  /// `null` khi đang tạo mới.
  final int? accountId;

  final String displayName;

  bool get isEditing => accountId != null;

  AccountFormDraft copyWith({String? displayName}) => AccountFormDraft(
    accountId: accountId,
    displayName: displayName ?? this.displayName,
  );

  /// Lỗi của ô tên, hoặc `null` khi hợp lệ.
  ///
  /// Phép kiểm này lặp lại đúng luật mà `BankAccount` thi hành bằng cách ném
  /// `EmptyAccountNameError`, và sự lặp lại đó là có chủ đích: Domain chặn để dữ
  /// liệu sai không bao giờ vào được, còn ở đây chặn để người dùng biết ô nào
  /// sai **trước khi** bấm lưu. Bỏ vế thứ hai thì lỗi duy nhất họ nhận được là
  /// một `ValidationFailure` chung chung không gắn với ô nào.
  String? get displayNameError =>
      displayName.trim().isEmpty ? 'Nhập tên tài khoản.' : null;

  bool get isValid => displayNameError == null;
}
