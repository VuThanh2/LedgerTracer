import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../../shared/widgets/verdict_pill.dart';
import '../bloc/reconciliation_state.dart';
import '../view_models/pair_view_model.dart';
import 'pair_detail_view.dart';

/// Danh sách cặp ở hình thái web: thẻ hai cột, thao tác bằng nút.
///
/// Trong nhóm *Đã xác nhận*, hành động khả dụng vẫn là **Từ chối** — không có
/// nút "bỏ xác nhận" riêng. Bỏ xác nhận và từ chối là cùng một việc dưới góc
/// nhìn dữ liệu (cặp bị gỡ), nhưng từ chối còn ghi lại phán quyết để lần quét
/// sau không gợi ý lại; thêm một nút thứ hai chỉ tạo một đường đi lặng lẽ đánh
/// mất trí nhớ đó.
class PairTable extends StatelessWidget {
  const PairTable({
    required this.state,
    required this.onToggleDetail,
    required this.onConfirm,
    required this.onReject,
    super.key,
  });

  final ReconciliationState state;
  final ValueChanged<int?> onToggleDetail;
  final ValueChanged<int> onConfirm;
  final ValueChanged<int> onReject;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (final pair in state.pairs) ...<Widget>[
        PairCard(
          pair: pair,
          detail: state.openPairId == pair.pairId ? state.detail : null,
          expanded: state.openPairId == pair.pairId,
          detailLoading:
              state.openPairId == pair.pairId && state.detailStatus.isLoading,
          onToggleDetail: () => onToggleDetail(
            state.openPairId == pair.pairId ? null : pair.pairId,
          ),
          onConfirm: () => onConfirm(pair.pairId),
          onReject: () => onReject(pair.pairId),
        ),
        const SizedBox(height: Gap.sm),
      ],
    ],
  );
}

/// Một cặp ở dạng thẻ. Dùng chung cho web và cho phần thân của thẻ vuốt trên
/// mobile, nên hai nền tảng không bao giờ hiển thị hai bộ thông tin khác nhau.
class PairCard extends StatelessWidget {
  const PairCard({
    required this.pair,
    required this.expanded,
    required this.onToggleDetail,
    required this.onConfirm,
    required this.onReject,
    this.detail,
    this.detailLoading = false,
    this.footnote,
    super.key,
  });

  final PairRowViewModel pair;
  final PairDetailViewModel? detail;
  final bool expanded;
  final bool detailLoading;
  final VoidCallback onToggleDetail;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  /// Dòng chú thích cuối thẻ, ví dụ gợi ý về cử chỉ vuốt trên mobile.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final isConfirmed = pair.status == PairStatus.confirmed;

    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusLg,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: Gap.md,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              VerdictPill(
                tone: isConfirmed ? VerdictTone.confirmed : VerdictTone.pending,
                label: isConfirmed ? 'Confirmed' : 'Suggested',
              ),
              const InternalBadge(),
              Text(
                '${pair.amountText} · ${pair.driftText}',
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
            ],
          ),
          const SizedBox(height: Gap.md),

          PairLegs(pair: pair, expanded: expanded),

          if (expanded) ...<Widget>[
            const SizedBox(height: Gap.md),
            if (detailLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(Gap.md),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (detail case final value?)
              AlternativeCandidates(detail: value),
          ],

          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: onToggleDetail,
                child: Text(expanded ? 'Hide details' : 'Show both legs'),
              ),
              if (!isConfirmed)
                OutlinedButton(
                  onPressed: onConfirm,
                  child: const Text('Confirm pair'),
                ),
              DestructiveButton(label: 'Reject', onPressed: onReject),
              Text(
                isConfirmed
                    ? 'Confirmed pairs keep only Reject — there is no separate '
                          'un-confirm.'
                    : 'Rejecting is remembered forever; this pair will not be '
                          'suggested again.',
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
            ],
          ),
          if (footnote case final String text) ...<Widget>[
            const SizedBox(height: Gap.sm),
            Text(text, style: LedgerText.micro.copyWith(color: colors.inkMute)),
          ],
        ],
      ),
    );
  }
}
