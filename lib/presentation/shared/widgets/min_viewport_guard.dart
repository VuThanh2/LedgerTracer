import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../responsive/breakpoints.dart';

/// Sàn kích thước của cả ứng dụng: nhỏ hơn [minSize], ứng dụng thôi co lại và
/// cho cuộn, thay vì tràn ra ngoài mép.
///
/// Mỗi màn hình được thiết kế cho một bề rộng tối thiểu (điện thoại nhỏ nhất
/// ~320px). Trên web người dùng kéo cửa sổ nhỏ hơn thế được, và khi đó không
/// layout nào còn đủ chỗ — chỉ còn dải sọc vàng đen của lỗi tràn. Ở đây cửa sổ
/// nhỏ hơn sàn thì ứng dụng vẫn dựng ở đúng cỡ sàn, và người dùng cuộn để tới
/// phần bị che.
///
/// Cây widget có **cùng một hình dạng** ở mọi kích thước, kể cả khi cửa sổ lớn
/// hơn sàn: nếu chỉ bọc vào lúc cần, kéo cửa sổ qua ngưỡng sẽ đổi kiểu widget ở
/// gốc và dựng lại cả ứng dụng, mất hết trạng thái. Khi đủ chỗ, khung cuộn bên
/// ngoài có `SizedBox` đúng bằng viewport nên không có gì để cuộn.
class MinViewportGuard extends StatelessWidget {
  const MinViewportGuard({
    required this.child,
    this.minSize = defaultMinSize,
    super.key,
  });

  /// Cỡ nhỏ nhất mà mọi màn hình đã được kiểm không tràn.
  static const Size defaultMinSize = Size(320, 320);

  /// Sàn chiều cao riêng của layout điện thoại (bề rộng dưới
  /// [WindowSizeClass.mediumMinWidth]). Ở đó app bar, bottom nav, stepper và
  /// banner báo lượt nhập dở đều là chrome cố định xếp chồng theo chiều dọc, và
  /// các tab Nhập / Đối soát cần cỡ 455px mới còn chỗ cho nội dung; layout rộng
  /// thì chrome nằm ngang nên vẫn chạy tốt ở 320px.
  static const double compactMinHeight = 480;

  final Widget child;
  final Size minSize;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      // Ràng buộc vô hạn (đặt trong một khung cuộn khác) thì không có gì để
      // nới lên, dùng đúng sàn.
      final width = constraints.hasBoundedWidth
          ? math.max(constraints.maxWidth, minSize.width)
          : minSize.width;
      final minHeight = width < WindowSizeClass.mediumMinWidth
          ? math.max(minSize.height, compactMinHeight)
          : minSize.height;
      final height = constraints.hasBoundedHeight
          ? math.max(constraints.maxHeight, minHeight)
          : minHeight;
      final size = Size(width, height);

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: SizedBox(
            width: size.width,
            height: size.height,
            // Cỡ mà các breakpoint đọc phải là cỡ đã được nới, không phải cỡ
            // cửa sổ thật, nếu không `WindowSizeClass` chọn layout theo một bề
            // rộng mà ứng dụng không hề được dựng ở đó.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(size: size),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
