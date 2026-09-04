import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/money_text.dart';
import '../view_models/transaction_row_view_model.dart';

/// Chi tiết một giao dịch (UC-04 b3, b4).
///
/// Cùng một widget cho hai hình thái: pane bên phải ở Expanded, và thân của
/// `TransactionDetailPage` ở Compact.
///
/// Chỉ báo "đã đối soát" là **liên kết**, không phải nhãn: từ một giao dịch,
/// câu hỏi tiếp theo của người dùng luôn là "ghép với cái gì", và bắt họ tự tìm
/// lại cặp đó ở màn Đối soát là bỏ rơi họ giữa đường.
class TransactionDetailPane extends StatelessWidget {
  const TransactionDetailPane({
    required this.detail,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenReconciliation,
    this.onClose,
    super.key,
  });

  final TransactionDetailViewModel detail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenReconciliation;

  /// `null` khi widget là thân của một route riêng — ở đó nút quay lại của
  /// app bar đã làm việc này.
  final VoidCallback? onClose;

  static const double paneWidth = 320;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (onClose != null)
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.hairline)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Transaction',
                    style: LedgerText.headingSm.copyWith(color: colors.ink),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Gap.lg),
            children: <Widget>[
              MoneyText(
                detail.amountText,
                isIncoming: detail.amount.isIncoming,
                textAlign: TextAlign.left,
                style: LedgerText.displayLg,
              ),
              const SizedBox(height: Gap.xs),
              Text(
                detail.dateText,
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
              const SizedBox(height: Gap.lg),

              if (detail.isReconciled) ...<Widget>[
                BannerMessage(
                  const FeedbackMessage.success(
                    'Matched to an internal transfer.',
                  ),
                  action: TextButton(
                    onPressed: onOpenReconciliation,
                    child: const Text('Open the pair in Reconcile'),
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ],
              if (detail.isManuallyEdited) ...<Widget>[
                const BannerMessage(
                  FeedbackMessage.info(
                    'This row was edited by hand after the import, so it no '
                    'longer matches the original file word for word.',
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ],

              _FieldBox(
                fields: <(String, String)>[
                  ('Account', detail.accountName),
                  ('Counterparty', _orDash(detail.counterpartyText)),
                  ('Memo', _orDash(detail.descriptionText)),
                  ('Row in the source file', detail.sourceLineText),
                  ('Imported at', detail.importedAtText),
                ],
              ),
              const SizedBox(height: Gap.lg),

              Row(
                children: <Widget>[
                  OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
                  const SizedBox(width: Gap.sm),
                  DestructiveButton(label: 'Delete', onPressed: onDelete),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _orDash(String value) => value.trim().isEmpty ? '—' : value;
}

class _FieldBox extends StatelessWidget {
  const _FieldBox({required this.fields});

  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final (label, value) in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label.toUpperCase(),
                    style: LedgerText.microCap.copyWith(
                      color: colors.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: Gap.xxs),
                  Text(
                    value,
                    style: LedgerText.bodyMd.copyWith(color: colors.ink),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
