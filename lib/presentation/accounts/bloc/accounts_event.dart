/// Những gì xảy ra trên màn hình quản lý tài khoản ngân hàng (UC-01).
sealed class AccountsEvent {
  const AccountsEvent();
}

final class AccountsStarted extends AccountsEvent {
  const AccountsStarted();
}

/// Thêm một tài khoản mới bằng tên hiển thị.
///
/// Không có tham số số tài khoản, và đó là chủ đích: số tài khoản được **học** từ
/// file sao kê đầu tiên mang nó, không phải do người dùng gõ vào (UC-02 bước 4).
/// Một ô nhập cho nó ở đây sẽ mời người dùng gõ một con số mà lần nhập đầu tiên
/// có thể mâu thuẫn ngay.
final class AccountAdded extends AccountsEvent {
  const AccountAdded(this.displayName);

  final String displayName;
}

final class AccountRenamed extends AccountsEvent {
  const AccountRenamed({required this.accountId, required this.displayName});

  final int accountId;
  final String displayName;
}

/// Sửa số tài khoản đã ghi nhận, phòng khi lần nhập đầu học sai (UC-01).
final class AccountNumberChanged extends AccountsEvent {
  const AccountNumberChanged({
    required this.accountId,
    required this.accountNumber,
  });

  final int accountId;
  final String accountNumber;
}

/// Xoá số tài khoản đã ghi nhận. Lần nhập kế tiếp sẽ học lại từ file.
final class AccountNumberCleared extends AccountsEvent {
  const AccountNumberCleared(this.accountId);

  final int accountId;
}

/// Bấm xoá tài khoản: hỏi trước số giao dịch và số cặp đối soát bị ảnh hưởng, để
/// hộp thoại xác nhận nói được con số cụ thể (UC-01).
final class AccountDeleteRequested extends AccountsEvent {
  const AccountDeleteRequested(this.accountId);

  final int accountId;
}

final class AccountDeleteDismissed extends AccountsEvent {
  const AccountDeleteDismissed();
}

final class AccountDeleteConfirmed extends AccountsEvent {
  const AccountDeleteConfirmed();
}
