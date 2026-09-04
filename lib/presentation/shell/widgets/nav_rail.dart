import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../view_models/navigation_intent.dart';

/// Nav rail dọc bên trái của bản web.
///
/// Ở breakpoint Expanded nó mở rộng kèm nhãn; ở Medium nó thu lại còn icon. Cả
/// hai đều là **cùng một** thanh điều hướng với cùng bốn ô — khác biệt giữa hai
/// nền tảng nằm ở hình thái trình bày, không ở tập tính năng.
///
/// Không dùng [NavigationRail] của Material: nó áp bảng màu và hình học riêng
/// (indicator hình viên thuốc, nền `surface`, nhãn ở dưới icon) mà hệ thống này
/// không dùng, và ghi đè từng mảnh của nó tốn nhiều dòng hơn là vẽ thẳng.
class NavRail extends StatelessWidget {
  const NavRail({
    required this.destination,
    required this.onSelected,
    required this.onSettings,
    this.showLabels = true,
    this.settingsSelected = false,
    super.key,
  });

  final NavDestination destination;
  final ValueChanged<NavDestination> onSelected;

  /// Settings không phải một ô nav — nó là bánh răng ở chân rail.
  final VoidCallback onSettings;

  final bool showLabels;

  final bool settingsSelected;

  static const double expandedWidth = 216;
  static const double collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      width: showLabels ? expandedWidth : collapsedWidth,
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.md),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        border: Border(right: BorderSide(color: colors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showLabels)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.sm, 6, Gap.sm, Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'LedgerTracer',
                    style: LedgerText.headingSm.copyWith(color: colors.ink),
                  ),
                  Text(
                    'Offline · on this device',
                    style: LedgerText.caption.copyWith(color: colors.inkMute),
                  ),
                ],
              ),
            ),
          for (final option in NavDestination.values)
            _RailTile(
              icon: navIconOf(option),
              label: option.label,
              selected: option == destination,
              showLabel: showLabels,
              onTap: () => onSelected(option),
            ),
          const Spacer(),
          Divider(color: colors.hairline, height: Gap.lg),
          _RailTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: settingsSelected,
            showLabel: showLabels,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

/// Icon của mỗi ô nav, dùng chung cho rail và bottom bar để hai hình thái không
/// trôi khỏi nhau.
IconData navIconOf(NavDestination destination) => switch (destination) {
  NavDestination.transactions => Icons.format_list_bulleted,
  NavDestination.import => Icons.file_download_outlined,
  NavDestination.reconciliation => Icons.swap_horiz,
  NavDestination.statistics => Icons.bar_chart,
};

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final foreground = selected ? colors.primaryDeep : colors.inkSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Tooltip(
        message: showLabel ? '' : label,
        child: InkWell(
          onTap: onTap,
          borderRadius: Corner.radiusSm,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? colors.primaryWash : Colors.transparent,
              borderRadius: Corner.radiusSm,
            ),
            child: Row(
              mainAxisAlignment: showLabel
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: <Widget>[
                Icon(icon, size: 16, color: foreground),
                if (showLabel) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LedgerText.bodySm.copyWith(color: foreground),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
