import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme.dart';

/// Dải vạch chuyển động cạnh mọi thanh tiến độ — phần tử chuyển động **duy
/// nhất** của hệ thống, và nó tồn tại vì lý do chức năng.
///
/// Thanh tiến độ cập nhật theo lô dữ liệu, nên khi một tác vụ nặng chạy trên
/// luồng giao diện thì nó chỉ đứng yên rồi nhảy — trạng thái đó không phân biệt
/// được với xử lý bình thường. Frame Pulse tiến một vạch mỗi hai **khung hình**,
/// do [Ticker] điều khiển chứ tuyệt đối không do tiến độ dữ liệu, nên nó khựng
/// lại đúng lúc luồng giao diện bị chặn. Đó là tín hiệu quan sát được, và với
/// bản Web — nơi không có isolate — nó là bằng chứng trực tiếp cho điều UC-14
/// cảnh báo.
///
/// Vẽ bằng [CustomPaint] trong một [RepaintBoundary]: nó nhấp nháy 60 lần mỗi
/// giây ngay cạnh một bảng dài, nên nó không được kéo theo phần còn lại của cây
/// widget vào mỗi khung hình.
class FramePulse extends StatefulWidget {
  const FramePulse({
    this.barCount = 12,
    this.onDark = false,
    this.running = true,
    super.key,
  });

  /// Bản thu nhỏ 6 vạch dùng trên app bar khi người dùng chuyển sang tab khác
  /// trong lúc tác vụ vẫn chạy.
  const FramePulse.compact({bool onDark = false, bool running = true, Key? key})
    : this(barCount: 6, onDark: onDark, running: running, key: key);

  final int barCount;

  /// Trên nền tối của màn Diagnostics.
  final bool onDark;

  /// Dừng ticker khi tác vụ kết thúc: một ticker chạy không mục đích vẫn tiêu
  /// tốn một khung hình mỗi 16ms.
  final bool running;

  static const double barWidth = 3;
  static const double barHeight = 12;
  static const double barGap = 3;

  @override
  State<FramePulse> createState() => _FramePulseState();
}

class _FramePulseState extends State<FramePulse>
    with SingleTickerProviderStateMixin {
  /// Chỉ số vạch đang sáng. Là [ValueNotifier] chứ không phải `setState` để chỉ
  /// [_FramePulsePainter] vẽ lại, không phải cả subtree.
  final ValueNotifier<int> _cursor = ValueNotifier<int>(0);

  late final Ticker _ticker = createTicker(_onFrame);

  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.running) _ticker.start();
  }

  @override
  void didUpdateWidget(FramePulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.running == oldWidget.running) return;
    if (widget.running) {
      _ticker.start();
    } else {
      _ticker.stop();
      _cursor.value = 0;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _cursor.dispose();
    super.dispose();
  }

  /// Đếm **khung hình**, không đọc `elapsed`: nếu đo bằng thời gian thì một
  /// luồng giao diện bị chặn 200ms sẽ nhảy vọt sáu vạch khi khung hình kế tiếp
  /// đến, và dấu hiệu giật lại biến mất đúng lúc cần nhìn thấy nó.
  void _onFrame(Duration _) {
    _frameCount++;
    if (_frameCount.isOdd) return;
    _cursor.value = (_cursor.value + 1) % widget.barCount;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(
          widget.barCount * (FramePulse.barWidth + FramePulse.barGap) -
              FramePulse.barGap,
          FramePulse.barHeight,
        ),
        painter: _FramePulsePainter(
          cursor: _cursor,
          barCount: widget.barCount,
          // Màu đặc, không sắc độ nhạt: bản ghi hình của màn hình này sẽ bị nén,
          // và một vạch mờ không sống sót qua phép nén đó.
          activeColor: colors.primary,
          idleColor: widget.onDark
              ? colors.darkHairline
              : colors.hairlineStructure,
        ),
      ),
    );
  }
}

class _FramePulsePainter extends CustomPainter {
  _FramePulsePainter({
    required this.cursor,
    required this.barCount,
    required this.activeColor,
    required this.idleColor,
  }) : super(repaint: cursor);

  final ValueNotifier<int> cursor;
  final int barCount;
  final Color activeColor;
  final Color idleColor;

  @override
  void paint(Canvas canvas, Size size) {
    final active = cursor.value;
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < barCount; i++) {
      paint.color = i == active ? activeColor : idleColor;
      final left = i * (FramePulse.barWidth + FramePulse.barGap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, 0, FramePulse.barWidth, size.height),
          const Radius.circular(1),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_FramePulsePainter oldDelegate) =>
      oldDelegate.barCount != barCount ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.idleColor != idleColor;
}
