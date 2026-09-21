import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../responsive/breakpoints.dart';

/// Khối nội dung chuẩn: nền trắng, viền 1px hairline, **elevation 0**.
///
/// Bề mặt của hệ thống này phẳng tuyệt đối. Đổ bóng chỉ tồn tại ở menu nổi và
/// dialog, vì mỗi lớp bóng là một lần raster lại mỗi khi bảng dài cuộn qua — và
/// độ mượt khung hình ở đây là thứ ứng dụng đang đem ra trưng bày.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.background,
    this.fill = false,
    super.key,
  });

  final Widget child;

  /// Tiêu đề card, kiểu `heading-sm`.
  final String? title;

  final String? subtitle;

  /// Hành động ở góc phải tiêu đề.
  final Widget? trailing;

  /// Mặc định theo density: 16px ở web, 24px ở mobile.
  final EdgeInsetsGeometry? padding;

  final Color? background;

  /// Cho [child] chiếm hết chiều cao còn lại khi card bị kéo cao hơn nội dung
  /// — dùng khi hai card đứng cạnh nhau phải cao bằng nhau. Chỉ bật khi card
  /// nhận chiều cao hữu hạn (ví dụ trong `IntrinsicHeight`).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(sizeClass.cardPadding),
      decoration: BoxDecoration(
        color: background ?? colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title!,
                    style: LedgerText.headingSm.copyWith(color: colors.ink),
                  ),
                ),
                ?trailing,
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: Gap.xs),
              Text(
                subtitle!,
                style: LedgerText.caption.copyWith(color: colors.inkMute),
              ),
            ],
            const SizedBox(height: Gap.lg),
          ],
          if (fill) Expanded(child: child) else child,
        ],
      ),
    );
  }
}

/// Nhãn nhóm viết hoa đứng trên một khối, kiểu `micro-cap`.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gap.sm),
    child: Text(
      text.toUpperCase(),
      style: LedgerText.microCap.copyWith(color: context.ledger.inkSecondary),
    ),
  );
}
