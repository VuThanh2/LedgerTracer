import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../view_models/pair_view_model.dart';
import 'pair_table.dart';

/// Thẻ cặp trên mobile: vuốt phải để xác nhận, vuốt trái để từ chối.
///
/// Cử chỉ vuốt bị **khoá khi thẻ đang mở rộng**. Thẻ mở rộng cao hơn màn hình
/// nên người dùng phải cuộn dọc để đọc hết, và ở trạng thái đó mọi cử chỉ ngang
/// đều dễ bị hiểu nhầm — một lần vuốt vô ý ở đây ghi thẳng một phán quyết.
///
/// Vuốt và nút cùng tồn tại, không thay thế nhau: phán quyết ở đây là quyết định
/// nghiệp vụ, nên nó phải làm được bằng đường không cần cử chỉ.
class PairSwipeCard extends StatelessWidget {
  const PairSwipeCard({
    required this.pair,
    required this.expanded,
    required this.onToggleDetail,
    required this.onConfirm,
    required this.onReject,
    this.detail,
    this.detailLoading = false,
    super.key,
  });

  final PairRowViewModel pair;
  final PairDetailViewModel? detail;
  final bool expanded;
  final bool detailLoading;
  final VoidCallback onToggleDetail;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final isConfirmed = pair.status == PairStatus.confirmed;

    final card = PairCard(
      pair: pair,
      detail: detail,
      expanded: expanded,
      detailLoading: detailLoading,
      onToggleDetail: onToggleDetail,
      onConfirm: onConfirm,
      onReject: onReject,
      footnote: expanded
          ? 'Swipe is locked while the card is expanded — use the buttons.'
          : isConfirmed
          ? 'Swipe left to reject this pair.'
          : 'Swipe right to confirm, left to reject.',
    );

    if (expanded) return card;

    return Dismissible(
      key: ValueKey<int>(pair.pairId),
      // Không tự xoá thẻ khỏi cây: danh sách được dựng lại từ BLoC sau mỗi phán
      // quyết, nên `confirmDismiss` phát sự kiện rồi trả `false` để tránh hai
      // nguồn cùng quyết định thẻ này còn hay mất.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          if (!isConfirmed) onConfirm();
        } else {
          onReject();
        }
        return false;
      },
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        color: colors.moneyInSoft,
        foreground: colors.moneyIn,
        icon: Icons.check,
        label: isConfirmed ? 'Confirmed' : 'Confirm',
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        color: colors.rubyWash,
        foreground: colors.moneyOut,
        icon: Icons.close,
        label: 'Reject',
      ),
      child: card,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
    decoration: BoxDecoration(color: color, borderRadius: Corner.radiusLg),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: Gap.sm),
        Text(
          label.toUpperCase(),
          style: LedgerText.microCap.copyWith(color: foreground),
        ),
      ],
    ),
  );
}
