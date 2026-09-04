import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../view_models/navigation_intent.dart';
import 'nav_rail.dart' show navIconOf;

/// Thanh điều hướng đáy của bản mobile: bốn ô ứng với bốn việc lặp lại hằng
/// ngày.
///
/// Bốn ô chọn theo **tần suất**, không theo phân loại chức năng — Quản lý tài
/// khoản, Cài đặt và Sao lưu đều là việc làm một lần rồi thôi nên chúng nằm dưới
/// bánh răng, còn Lịch sử nhập là một tab bên trong màn Nhập.
class NavBar extends StatelessWidget {
  const NavBar({
    required this.destination,
    required this.onSelected,
    super.key,
  });

  final NavDestination destination;
  final ValueChanged<NavDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: EdgeInsets.only(
        top: Gap.sm,
        bottom: Gap.sm + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          for (final option in NavDestination.values)
            Expanded(
              child: _BarTile(
                icon: navIconOf(option),
                label: option.label,
                selected: option == destination,
                onTap: () => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarTile extends StatelessWidget {
  const _BarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final foreground = selected ? colors.primary : colors.inkMuteNav;

    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: Corner.pill,
        child: Container(
          // Vùng chạm tối thiểu 48px của breakpoint Compact.
          constraints: const BoxConstraints(minHeight: 48),
          margin: const EdgeInsets.symmetric(horizontal: Gap.xs),
          decoration: BoxDecoration(
            color: selected ? colors.primaryWash : Colors.transparent,
            borderRadius: Corner.pill,
          ),
          child: Column(
            // `bottomNavigationBar` được Scaffold đo bằng ràng buộc **lỏng**,
            // nên một Column cỡ `max` ở đây sẽ nuốt trọn chiều cao màn hình và
            // đẩy phần thân xuống còn 0px.
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 20, color: foreground),
              const SizedBox(height: Gap.xs),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LedgerText.microCap.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
