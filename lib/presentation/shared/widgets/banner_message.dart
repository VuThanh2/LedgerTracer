import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../failures/feedback_message.dart';

/// Banner phản hồi hệ thống: full-width, viền trái 3px, **luôn có icon**.
///
/// Icon là thứ tách banner khỏi [VerdictPill] ở tầng nhận biết: pill nói "dòng
/// này đang ở trạng thái nào", banner nói "hệ thống vừa gặp chuyện gì". Hai kênh
/// dùng chung vài hue nên chúng phải khác nhau ở hình dạng.
class BannerMessage extends StatelessWidget {
  const BannerMessage(this.message, {this.onDismiss, this.action, super.key});

  final FeedbackMessage message;

  /// Nút đóng ở mép phải. `null` nghĩa là banner không tự đóng được — dùng cho
  /// những cảnh báo mô tả ràng buộc của nền tảng, vốn không "hết hạn".
  final VoidCallback? onDismiss;

  /// Hành động tuỳ chọn đặt dưới phần chữ, ví dụ liên kết dẫn sang màn khác.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final (background, foreground, icon) = switch (message.severity) {
      FeedbackSeverity.info => (
        colors.primaryWash,
        colors.primaryDeep,
        Icons.info_outline,
      ),
      FeedbackSeverity.success => (
        colors.moneyInSoft,
        colors.moneyIn,
        Icons.check_circle_outline,
      ),
      FeedbackSeverity.warning => (
        colors.creamWash,
        colors.lemonInk,
        Icons.warning_amber_outlined,
      ),
      FeedbackSeverity.danger => (
        colors.rubyWash,
        colors.moneyOut,
        Icons.error_outline,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Corner.radiusMd,
        border: Border(left: BorderSide(color: foreground, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  message.text,
                  style: LedgerText.bodySm.copyWith(color: foreground),
                ),
                if (message.detail case final String detail
                    when detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: Gap.xs),
                  Text(
                    detail,
                    style: LedgerText.micro.copyWith(
                      color: foreground.withValues(alpha: 0.85),
                    ),
                  ),
                ],
                if (action != null) ...<Widget>[
                  const SizedBox(height: Gap.sm),
                  action!,
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            _DismissButton(color: foreground, onPressed: onDismiss!),
        ],
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.color, required this.onPressed});

  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    icon: Icon(Icons.close, size: 16, color: color),
    tooltip: 'Dismiss',
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 28, height: 28),
  );
}
