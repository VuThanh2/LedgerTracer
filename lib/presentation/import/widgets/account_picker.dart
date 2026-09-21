import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/entities/bank_account.dart';
import '../../shared/responsive/breakpoints.dart';

/// Ô chọn tài khoản đích trong dòng `row-account-select` của bước 2.
///
/// Tự dựng trên [MenuAnchor] thay vì `DropdownButtonFormField`: menu mặc định
/// của Material nổi ở elevation 8 với nền pha tint, bo góc và chiều cao dòng
/// riêng — không có bộ tham số nào kéo nó về đúng "menu thả xuống" của
/// DESIGN.md (nền canvas, viền hairline, bo `rounded.md`, bóng mức 1).
///
/// Và vì ô chọn mặc định không có đường lùi: chọn rồi thì chỉ đổi được sang tài
/// khoản khác. Ở đây có hai lối bỏ chọn — nút × ngay trên ô cho người đã biết,
/// và mục "Clear selection" cuối danh sách cho người đi tìm trong menu.
class AccountPicker extends StatefulWidget {
  const AccountPicker({
    required this.accounts,
    required this.selectedId,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final List<BankAccount> accounts;
  final int? selectedId;

  /// `null` là bỏ chọn.
  final ValueChanged<int?> onChanged;

  final bool enabled;

  @override
  State<AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<AccountPicker> {
  final MenuController _menu = MenuController();
  bool _open = false;

  /// Menu cao tối đa chừng sáu dòng rồi cuộn: danh sách tài khoản dài không
  /// được đẩy menu tràn khỏi màn hình trên mobile.
  static const double _menuMaxHeight = 320;

  BankAccount? get _selected {
    for (final account in widget.accounts) {
      if (account.accountId == widget.selectedId) return account;
    }
    return null;
  }

  void _toggle() => _menu.isOpen ? _menu.close() : _menu.open();

  void _choose(int? accountId) {
    if (accountId != widget.selectedId) widget.onChanged(accountId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    // Vùng chạm tối thiểu theo density: 48 trên mobile, 40 trên web.
    final touch = WindowSizeClass.of(MediaQuery.sizeOf(context).width)
        .usesBottomNavigation;
    final rowHeight = touch ? 48.0 : 40.0;
    final selected = _selected;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Menu rộng đúng bằng ô chọn: một menu hẹp hơn ô của nó trông như bị
        // cắt, rộng hơn thì lấn sang dòng bên cạnh.
        final width = constraints.maxWidth;
        return MenuAnchor(
          controller: _menu,
          onOpen: () => setState(() => _open = true),
          onClose: () => setState(() => _open = false),
          alignmentOffset: const Offset(0, Gap.xs),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll<Color>(colors.canvas),
            surfaceTintColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            // Mức 1 của DESIGN.md: một lớp bóng rất nhẹ gốc shadow-blue.
            elevation: const WidgetStatePropertyAll<double>(1),
            shadowColor: WidgetStatePropertyAll<Color>(colors.shadowBlue),
            side: WidgetStatePropertyAll<BorderSide>(
              BorderSide(color: colors.hairline),
            ),
            shape: const WidgetStatePropertyAll<OutlinedBorder>(
              RoundedRectangleBorder(borderRadius: Corner.radiusMd),
            ),
            padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
              EdgeInsets.symmetric(vertical: Gap.xs),
            ),
            minimumSize: WidgetStatePropertyAll<Size>(Size(width, 0)),
            maximumSize: WidgetStatePropertyAll<Size>(
              Size(width, _menuMaxHeight),
            ),
          ),
          menuChildren: <Widget>[
            if (widget.accounts.isEmpty)
              _EmptyNotice(minHeight: rowHeight)
            else
              for (final account in widget.accounts)
                _AccountItem(
                  account: account,
                  selected: account.accountId == widget.selectedId,
                  minHeight: rowHeight,
                  onPressed: () => _choose(account.accountId),
                ),
            if (selected != null) ...<Widget>[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.xs),
                child: Divider(),
              ),
              MenuItemButton(
                onPressed: () => _choose(null),
                style: _itemStyle(colors, rowHeight, selected: false),
                leadingIcon: Icon(
                  Icons.close,
                  size: 16,
                  color: colors.inkSecondary,
                ),
                child: Text(
                  'Clear selection',
                  style: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
                ),
              ),
            ],
          ],
          child: _Trigger(
            selected: selected,
            open: _open,
            enabled: widget.enabled,
            minHeight: rowHeight,
            onTap: _toggle,
            onClear: () => _choose(null),
          ),
        );
      },
    );
  }
}

/// Mặt ngoài của ô chọn — cùng hình học với `text-input`: nền canvas, viền
/// `hairline-control`, bo `rounded.sm`, viền chuyển sang `primary` khi menu
/// đang mở (tương đương trạng thái focus).
class _Trigger extends StatelessWidget {
  const _Trigger({
    required this.selected,
    required this.open,
    required this.enabled,
    required this.minHeight,
    required this.onTap,
    required this.onClear,
  });

  final BankAccount? selected;
  final bool open;
  final bool enabled;
  final double minHeight;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final account = selected;
    final iconColor = enabled ? colors.inkSecondary : colors.inkMute;

    return Semantics(
      button: true,
      expanded: open,
      label: account == null
          ? 'Choose an account'
          : 'Account: ${account.displayName}',
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: Corner.radiusSm,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: InputDecorator(
          isFocused: open,
          isEmpty: account == null,
          decoration: InputDecoration(
            enabled: enabled,
            hintText: 'Choose an account…',
            constraints: BoxConstraints(minHeight: minHeight),
            suffixIconConstraints: const BoxConstraints(),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (account != null && enabled)
                    IconButton(
                      tooltip: 'Clear selection',
                      onPressed: onClear,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(
                        width: 32,
                        height: 32,
                      ),
                      padding: EdgeInsets.zero,
                      iconSize: 16,
                      icon: Icon(Icons.close, color: iconColor),
                    ),
                  Icon(
                    open ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
          child: account == null
              ? null
              : Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LedgerText.bodyMd.copyWith(
                    color: enabled ? colors.ink : colors.inkMute,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Một dòng tài khoản trong menu: tên, và số tài khoản đã học (nếu có) để phân
/// biệt hai tài khoản đặt tên gần giống nhau.
class _AccountItem extends StatelessWidget {
  const _AccountItem({
    required this.account,
    required this.selected,
    required this.minHeight,
    required this.onPressed,
  });

  final BankAccount account;
  final bool selected;
  final double minHeight;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final number = account.accountNumber;
    return MenuItemButton(
      onPressed: onPressed,
      style: _itemStyle(colors, minHeight, selected: selected),
      trailingIcon: selected
          ? Icon(Icons.check, size: 16, color: colors.primaryDeep)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              account.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LedgerText.bodyMd.copyWith(
                color: selected ? colors.primaryDeep : colors.ink,
              ),
            ),
            if (number != null)
              Text(
                number,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
          ],
        ),
      ),
    );
  }
}

/// Chưa có tài khoản nào: nói rõ phải đi đâu, thay vì mở ra một menu rỗng.
class _EmptyNotice extends StatelessWidget {
  const _EmptyNotice({required this.minHeight});

  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        child: Text(
          'No accounts yet. Create one in Settings → Accounts.',
          style: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
        ),
      ),
    );
  }
}

/// Dòng menu: phẳng, không bo, không gợn sóng. Hover nền `canvas-soft`, dòng
/// đang chọn nền `primary-wash` — cùng quy ước với dòng bảng đang chọn.
ButtonStyle _itemStyle(
  LedgerColors colors,
  double minHeight, {
  required bool selected,
}) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll<Size>(Size(0, minHeight)),
  padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
    EdgeInsets.symmetric(horizontal: Gap.md),
  ),
  shape: const WidgetStatePropertyAll<OutlinedBorder>(RoundedRectangleBorder()),
  overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
  backgroundColor: WidgetStateProperty.resolveWith((states) {
    if (selected) return colors.primaryWash;
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return colors.canvasSoft;
    }
    return Colors.transparent;
  }),
  foregroundColor: WidgetStatePropertyAll<Color>(
    selected ? colors.primaryDeep : colors.ink,
  ),
);
