import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/money_text.dart';
import '../../shared/widgets/section_card.dart';
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
                    'Edited by hand after import, so it may differ from the '
                    'original file.',
                  ),
                ),
                const SizedBox(height: Gap.lg),
              ],

              // Hai nhóm thay cho một khối năm trường: ba trường đầu là **nội
              // dung** giao dịch, hai trường sau là **nguồn gốc** của dòng — thứ
              // chỉ cần khi đối chiếu lại với file sao kê. Tách ra thì mắt
              // dừng ở nhóm đầu mà không phải đọc qua hai dòng kỹ thuật.
              const SectionLabel('Details'),
              _FieldGroup(
                fields: <(String, String)>[
                  ('Account', detail.accountName),
                  ('Counterparty', detail.counterpartyText),
                  ('Memo', detail.descriptionText),
                ],
              ),
              const SizedBox(height: Gap.xl),
              const SectionLabel('Source'),
              _FieldGroup(
                fields: <(String, String)>[
                  ('Row in the source file', detail.sourceLineText),
                  ('Imported at', detail.importedAtText),
                ],
              ),
              const SizedBox(height: Gap.xl),

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

}

/// Một nhóm trường, mỗi trường một ô ngăn bằng đường kẻ mảnh.
///
/// Trước đây nhãn và giá trị chỉ cách nhau 2px, còn giữa hai trường là 12px
/// và không có gì ngăn: mắt không biết nhãn này thuộc giá trị phía trên hay
/// phía dưới, và năm trường đọc như một đoạn văn. Ở đây mỗi trường là một ô
/// có ranh giới riêng, nhãn nhỏ và nhạt, giá trị lớn và đậm hơn một bậc — hai
/// tầng chữ khác hẳn nhau nên nhìn lướt cũng tách được.
class _FieldGroup extends StatelessWidget {
  const _FieldGroup({required this.fields});

  final List<(String, String)> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final (index, (label, value)) in fields.indexed) ...<Widget>[
            if (index > 0)
              Divider(height: 1, thickness: 1, color: colors.hairline),
            _Field(label: label, value: value),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    // Trường trống hiện "—" màu nhạt, không đậm như giá trị thật: một gạch
    // ngang in đậm đọc như dữ liệu, trong khi nó nói rằng không có dữ liệu.
    // View model đôi khi đã tự điền "—" (dòng nguồn không rõ), nên coi nó như
    // trống luôn.
    final empty = value.trim().isEmpty || value == '—';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
          ),
          const SizedBox(height: Gap.xs),
          SelectableText(
            empty ? '—' : value,
            style: LedgerText.bodyMd.copyWith(
              color: empty ? colors.inkMute : colors.ink,
              fontWeight: empty ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
