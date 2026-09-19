import 'package:flutter/material.dart';

/// [IndexedStack] có chuyển cảnh: khi đổi tab, trang mới mờ dần vào và trượt
/// nhẹ theo hướng của tab được chọn (tab bên phải thì trượt từ phải sang).
///
/// Vẫn là [IndexedStack] bên dưới — mọi trang giữ nguyên state khi rời đi, nên
/// lượt nhập đang chạy hay vị trí cuộn không bị dựng lại. Chỉ trang đang hiện
/// được vẽ, nên animate cả stack cũng chỉ là animate trang mới.
class TabTransition extends StatefulWidget {
  const TabTransition({
    required this.index,
    required this.children,
    this.enabled = true,
    super.key,
  });

  final int index;
  final List<Widget> children;

  /// Tắt thì đổi tab tức thì như [IndexedStack] thường.
  final bool enabled;

  @override
  State<TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<TabTransition>
    with SingleTickerProviderStateMixin {
  /// Đủ để mắt thấy hướng chuyển, đủ ngắn để không cản thao tác.
  static const Duration _duration = Duration(milliseconds: 320);

  /// Quãng trượt tính theo bề rộng trang — chỉ gợi hướng, không phải lật trang.
  static const double _slideFraction = 0.06;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  double _direction = 1;

  @override
  void didUpdateWidget(TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.index == oldWidget.index) return;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stack = IndexedStack(index: widget.index, children: widget.children);
    if (!widget.enabled) return stack;

    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => FractionalTranslation(
          translation: Offset(
            (1 - _curve.value) * _slideFraction * _direction,
            0,
          ),
          child: child,
        ),
        child: stack,
      ),
    );
  }
}
