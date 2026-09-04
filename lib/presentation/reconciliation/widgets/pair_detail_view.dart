import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/widgets/money_text.dart';
import '../view_models/pair_view_model.dart';

/// Hai vế của một cặp, đặt cạnh nhau ở web và xếp dọc ở mobile.
class PairLegs extends StatelessWidget {
  const PairLegs({required this.pair, required this.expanded, super.key});

  final PairRowViewModel pair;

  /// Bung thêm đối tác, nội dung và số dòng file gốc.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 720;
    final legs = <Widget>[
      _Leg(
        side: pair.outgoing,
        label: 'Money out',
        isIncoming: false,
        expanded: expanded,
      ),
      _Leg(
        side: pair.incoming,
        label: 'Money in',
        isIncoming: true,
        expanded: expanded,
      ),
    ];

    if (!isWide) {
      return Column(
        children: <Widget>[
          legs.first,
          const SizedBox(height: Gap.sm),
          legs.last,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: legs.first),
        const SizedBox(width: Gap.lg),
        Expanded(child: legs.last),
      ],
    );
  }
}

class _Leg extends StatelessWidget {
  const _Leg({
    required this.side,
    required this.label,
    required this.isIncoming,
    required this.expanded,
  });

  final PairSideViewModel side;
  final String label;
  final bool isIncoming;
  final bool expanded;

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
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
              ),
              const Spacer(),
              MoneyText(side.amountText, isIncoming: isIncoming),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            side.accountName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: LedgerText.bodySm.copyWith(color: colors.ink),
          ),
          Text(
            side.dateText,
            style: LedgerText.caption.copyWith(color: colors.inkMute),
          ),
          if (expanded) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Divider(color: colors.hairline, height: 1),
            const SizedBox(height: Gap.sm),
            Text(
              side.counterpartyText.isEmpty ? '—' : side.counterpartyText,
              style: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
            ),
            Text(
              '${side.descriptionText.isEmpty ? '—' : side.descriptionText} · '
              'row ${side.sourceLineText}',
              style: LedgerText.caption.copyWith(color: colors.inkMute),
            ),
          ],
        ],
      ),
    );
  }
}

/// Danh sách ứng viên thay thế của một cặp (UC-09 b2).
///
/// Có mặt vì gợi ý của hệ thống chỉ là **một** khả năng: khi hai giao dịch cùng
/// số tiền rơi vào cùng cửa sổ ngày, việc chọn vế nào là phán quyết của người
/// dùng. Không trưng các ứng viên khác ra thì họ xác nhận một cặp mà không biết
/// mình vừa loại cái gì.
class AlternativeCandidates extends StatelessWidget {
  const AlternativeCandidates({required this.detail, super.key});

  final PairDetailViewModel detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (!detail.hasAlternatives) {
      return Text(
        'No other candidate falls inside the current match window.',
        style: LedgerText.caption.copyWith(color: colors.inkMute),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'ALTERNATIVE CANDIDATES',
          style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: 6),
        for (final (label, sides) in <(String, List<PairSideViewModel>)>[
          ('For the money-out leg', detail.alternativesForOutgoing),
          ('For the money-in leg', detail.alternativesForIncoming),
        ])
          if (sides.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs, bottom: Gap.xs),
              child: Text(
                label,
                style: LedgerText.micro.copyWith(color: colors.inkMute),
              ),
            ),
            for (final side in sides)
              Container(
                margin: const EdgeInsets.only(bottom: Gap.xs),
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                decoration: BoxDecoration(
                  color: colors.canvasSoft,
                  borderRadius: Corner.radiusSm,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            side.accountName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LedgerText.bodySm.copyWith(
                              color: colors.ink,
                            ),
                          ),
                          Text(
                            '${side.dateText} · '
                            '${side.counterpartyText.isEmpty ? side.descriptionText : side.counterpartyText}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LedgerText.caption.copyWith(
                              color: colors.inkMute,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: Gap.md),
                    Text(
                      side.amountText,
                      style: LedgerText.bodyTabular.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        // Chọn thẳng một ứng viên chưa làm được: tầng dưới nhận phán quyết theo
        // `pairId`, không theo cặp giao dịch tự chọn. Cách đi hiện tại là từ
        // chối cặp này rồi chạy lại lượt quét.
        Padding(
          padding: const EdgeInsets.only(top: Gap.xs),
          child: Text(
            'To match against a different candidate: reject this pair, then run '
            'the scan again — the rejection is remembered, so the old pair will '
            'not come back.',
            style: LedgerText.micro.copyWith(color: colors.inkMute),
          ),
        ),
      ],
    );
  }
}
