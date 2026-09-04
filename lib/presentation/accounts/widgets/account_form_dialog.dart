import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../view_models/account_view_model.dart';

/// Kết quả người dùng gửi đi từ form tài khoản.
///
/// Là một kiểu riêng chứ không phải bộ ba tham số rời vì "số tài khoản" có **ba**
/// trạng thái chứ không phải hai: giữ nguyên, đổi thành một số khác, hoặc xoá
/// hẳn. Một `String?` không phân biệt được "không đụng tới" với "xoá đi", và đó
/// đúng là chỗ dễ mất dữ liệu nhất của màn này.
@immutable
final class AccountFormResult {
  const AccountFormResult({
    required this.displayName,
    required this.accountNumber,
    required this.clearAccountNumber,
  });

  final String displayName;

  /// `null` nghĩa là không đổi.
  final String? accountNumber;

  final bool clearAccountNumber;
}

/// Thêm hoặc sửa một tài khoản (UC-01).
///
/// **Một** component, hai điểm vào: màn Quản lý tài khoản và bước 2 của luồng
/// Nhập. Ở điểm vào thứ hai người dùng đang giữa chừng một việc khác, nên form
/// phải ngắn — chỉ tên là bắt buộc.
///
/// Số tài khoản được hệ thống **học** từ file sao kê, nên ô này chỉ hiện khi
/// sửa: bắt gõ tay lúc tạo mới là mời gõ sai một chuỗi mà hệ thống sắp tự biết.
class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({this.account, super.key});

  /// `null` khi tạo mới.
  final AccountViewModel? account;

  static Future<AccountFormResult?> show(
    BuildContext context, {
    AccountViewModel? account,
  }) => showDialog<AccountFormResult>(
    context: context,
    builder: (_) => AccountFormDialog(account: account),
  );

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  late AccountFormDraft _draft = AccountFormDraft(
    accountId: widget.account?.accountId,
    displayName: widget.account?.displayName ?? '',
  );

  late final TextEditingController _name = TextEditingController(
    text: _draft.displayName,
  );
  late final TextEditingController _number = TextEditingController(
    text: widget.account?.accountNumber ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_draft.isValid) return;
    final original = widget.account?.accountNumber ?? '';
    final typed = _number.text.trim();
    Navigator.of(context).pop(
      AccountFormResult(
        displayName: _draft.displayName.trim(),
        accountNumber: typed.isEmpty || typed == original ? null : typed,
        clearAccountNumber:
            _draft.isEditing && original.isNotEmpty && typed.isEmpty,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return AlertDialog(
      title: Text(_draft.isEditing ? 'Edit account' : 'Bank account'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'NAME',
              style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
            ),
            const SizedBox(height: Gap.xs),
            TextField(
              controller: _name,
              autofocus: true,
              style: LedgerText.bodyMd.copyWith(color: colors.ink),
              decoration: InputDecoration(
                hintText: 'Operating',
                errorText: _name.text.isEmpty ? null : _draft.displayNameError,
              ),
              onChanged: (value) =>
                  setState(() => _draft = _draft.copyWith(displayName: value)),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.lg),

            if (_draft.isEditing) ...<Widget>[
              Text(
                'LEARNED ACCOUNT NUMBER',
                style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
              ),
              const SizedBox(height: Gap.xs),
              TextField(
                controller: _number,
                style: LedgerText.bodyMd.copyWith(color: colors.ink),
                decoration: const InputDecoration(
                  hintText: 'Leave empty to clear the learned number',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: Gap.md),
              const BannerMessage(
                FeedbackMessage.info(
                  'The app read this number from a statement file. Fix it when '
                  'a file taught the wrong one; clear it to let the app learn '
                  'again on the next import.',
                ),
              ),
            ] else
              const BannerMessage(
                FeedbackMessage.info(
                  'You do not type the account number: the app learns it from '
                  'the statement file on the first import.',
                ),
              ),
          ],
        ),
      ),
      actions: <Widget>[
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _draft.isValid ? _submit : null,
          child: Text(_draft.isEditing ? 'Save' : 'Create account'),
        ),
      ],
    );
  }
}
