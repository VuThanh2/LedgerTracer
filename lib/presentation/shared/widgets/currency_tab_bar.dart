import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../../domain/value_objects/currency.dart';

/// Segmented control chung của hệ thống: rãnh `canvas-soft`, padding 3px, ô
/// đang chọn nổi lên bằng nền `canvas` cộng elevation level 1.
///
/// Đặt ở đây, cạnh [CurrencyTabBar], vì dãy tab loại tiền là hiện thân chính của
/// hình dạng này; nhóm phán quyết ở màn Đối soát dùng lại đúng hình học đó qua
/// `VerdictSegmentedControl`. Hai chỗ vẽ lại cùng một control là hai chỗ để nó
/// lệch nhau.
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.expand = false,
    super.key,
  });

  final List<SegmentOption<T>> segments;

  final T selected;

  final ValueChanged<T> onSelected;

  /// Trải đều các ô trên toàn bộ bề rộng — hình dạng của bản mobile.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final children = <Widget>[
      for (final segment in segments)
        _Segment<T>(
          option: segment,
          isSelected: segment.value == selected,
          expand: expand,
          onTap: () => onSelected(segment.value),
        ),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusMd,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          for (final child in children)
            if (expand) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Một ô của [SegmentedControl].
@immutable
final class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;

  /// Nhãn đã kèm số đếm nếu có. Nhóm rỗng vẫn phải hiện số 0 chứ không biến
  /// mất: một tab biến mất là một tab người dùng không biết mình đang thiếu.
  final String label;
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.option,
    required this.isSelected,
    required this.expand,
    required this.onTap,
  });

  final SegmentOption<T> option;
  final bool isSelected;
  final bool expand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.radiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 6),
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? colors.canvas : Colors.transparent,
          borderRadius: Corner.radiusSm,
          boxShadow: isSelected ? Elevations.level1(colors.shadowBlue) : null,
        ),
        child: Text(
          option.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LedgerText.micro.copyWith(
            color: isSelected ? colors.primaryDeep : colors.inkSecondary,
          ),
        ),
      ),
    );
  }
}

/// Dãy tab loại tiền, **luôn nhìn thấy** ở màn Thống kê.
///
/// Các loại tiền không bao giờ cộng gộp và không quy đổi, nên loại tiền không
/// phải một bộ lọc nằm trong panel mà là chiều tách của toàn bộ số liệu. Nó phải
/// hiện ngay cả khi chỉ có một loại tiền, để con số trên màn hình không bao giờ
/// bị đọc là "tổng của mọi thứ".
class CurrencyTabBar extends StatelessWidget {
  const CurrencyTabBar({
    required this.currencies,
    required this.selected,
    required this.onSelected,
    this.expand = false,
    super.key,
  });

  final List<CurrencyUsage> currencies;

  final Currency? selected;

  final ValueChanged<Currency> onSelected;

  final bool expand;

  @override
  Widget build(BuildContext context) {
    if (currencies.isEmpty) return const SizedBox.shrink();
    final active = selected ?? currencies.first.currency;
    return SegmentedControl<String>(
      expand: expand,
      selected: active.code,
      onSelected: (code) => onSelected(
        currencies.firstWhere((usage) => usage.currency.code == code).currency,
      ),
      segments: <SegmentOption<String>>[
        for (final usage in currencies)
          SegmentOption<String>(
            value: usage.currency.code,
            label: usage.currency.code,
          ),
      ],
    );
  }
}
