import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../bloc/reconciliation_state.dart';
import '../view_models/pair_view_model.dart';

/// Sổ các phán quyết từ chối (UC-09 b5).
///
/// Không phải một danh sách cặp: cặp đã bị xoá lúc từ chối, thứ còn lại là bản
/// ghi "đừng gợi ý lại hai giao dịch này". Vì vậy hành động duy nhất ở đây là
/// **gỡ phán quyết**, và việc gỡ không dựng lại cặp — nó chỉ cho phép lượt quét
/// kế tiếp đề xuất lại. Nói rõ điều đó tránh việc người dùng gỡ xong rồi đi tìm
/// một dòng không tồn tại.
class RejectedList extends StatelessWidget {
  const RejectedList({required this.state, required this.onUndo, super.key});

  final ReconciliationState state;
  final ValueChanged<int> onUndo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      if (state.rejectedCountIsCapped) ...<Widget>[
        const BannerMessage(
          FeedbackMessage.info(
            'The rejection log is longer than this screen reads in. The list '
            'below shows the most recent verdicts.',
          ),
        ),
        const SizedBox(height: Gap.lg),
      ],
      for (final row in state.rejected) ...<Widget>[
        _RejectedRow(row: row, onUndo: () => onUndo(row.rejectedMatchId)),
        const SizedBox(height: Gap.sm),
      ],
    ],
  );
}

class _RejectedRow extends StatelessWidget {
  const _RejectedRow({required this.row, required this.onUndo});

  final RejectedRowViewModel row;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const VerdictPill(tone: VerdictTone.rejected, label: 'Rejected'),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  row.summaryText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.bodySm.copyWith(color: colors.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'Rejected at ${row.rejectedAtText}'
            '${row.isComplete ? '' : ' · one of the two rows has been deleted'}',
            style: LedgerText.caption.copyWith(color: colors.inkMute),
          ),
          if (row.sideA case final side? when row.isComplete) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(
              '${side.accountName} · ${side.dateText}  ⇄  '
              '${row.sideB!.accountName} · ${row.sideB!.dateText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerText.caption.copyWith(color: colors.inkSecondary),
            ),
          ],
          const SizedBox(height: Gap.md),
          Row(
            children: <Widget>[
              OutlinedButton(
                onPressed: onUndo,
                child: const Text('Lift the rejection'),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Text(
                  'Lifting it does not bring the pair back right away: it only '
                  'becomes a candidate again on the next scan.',
                  style: LedgerText.micro.copyWith(color: colors.inkMute),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
