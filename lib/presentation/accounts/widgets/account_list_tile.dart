import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../view_models/account_view_model.dart';

/// Một tài khoản trong danh sách quản lý (UC-01).
///
/// Số tài khoản hiển thị bằng `caption` với chữ số tabular, và khi chưa học được
/// thì nói thẳng là chưa có — chứ không để trống. Ô trống ở đây đọc như một lỗi
/// hiển thị, còn "chưa học được số" là một trạng thái bình thường và có ý nghĩa:
/// nó giải thích vì sao lần nhập tới sẽ không có cảnh báo lệch số.
class AccountListTile extends StatelessWidget {
  const AccountListTile({
    required this.account,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final AccountViewModel account;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.bodyMd.copyWith(color: colors.ink),
                ),
                const SizedBox(height: Gap.xxs),
                Text(
                  account.hasAccountNumber
                      ? 'Learned number: ${account.accountNumber}'
                      : 'No account number learned from any file yet.',
                  style: LedgerText.caption.copyWith(
                    color: account.hasAccountNumber
                        ? colors.inkSecondary
                        : colors.inkMute,
                  ),
                ),
                Text(
                  'Created ${account.createdAtText}',
                  style: LedgerText.caption.copyWith(color: colors.inkMute),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.md),
          Wrap(
            spacing: Gap.sm,
            children: <Widget>[
              OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
              DestructiveButton(label: 'Delete', onPressed: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}
