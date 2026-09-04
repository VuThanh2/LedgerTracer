import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../failures/feedback_message.dart';
import 'banner_message.dart';

/// Hộp thoại xác nhận một hành động phá huỷ.
///
/// Ba quy tắc của DESIGN.md được đóng cứng ở đây thay vì lặp lại ở mỗi điểm gọi:
/// nút phá huỷ **không bao giờ tô nền đặc** — hành động phá huỷ cần được chọn có
/// chủ ý, không cần được làm cho hấp dẫn; nút giữ nguyên hiện trạng là nút được
/// nhấn mạnh; và hệ quả của hành động phải nằm trong một banner có icon chứ
/// không phải một câu chữ thường.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    required this.title,
    required this.confirmLabel,
    this.body,
    this.consequence,
    this.cancelLabel = 'Keep it',
    this.isBusy = false,
    this.canConfirm = true,
    this.extra,
    this.onConfirm,
    this.onCancel,
    super.key,
  });

  final String title;

  /// Câu dẫn, đặt trên banner hệ quả.
  final String? body;

  /// Hệ quả không thể hoàn tác của hành động. Hiển thị bằng [BannerMessage] nên
  /// nó luôn có icon.
  final FeedbackMessage? consequence;

  final String confirmLabel;
  final String cancelLabel;

  /// Đang chạy: khoá cả hai nút để một lần bấm đúp không thành hai lệnh.
  final bool isBusy;

  /// `false` khi hộp thoại còn đòi thêm một điều kiện — ví dụ chuỗi xác nhận
  /// chưa gõ đúng. Nút phá huỷ khi ấy phải **xám**, không phải bấm được mà không
  /// làm gì: một nút im lặng khi bấm đọc như ứng dụng bị treo.
  final bool canConfirm;

  /// Nội dung thêm giữa banner và hàng nút, ví dụ ô gõ chuỗi xác nhận.
  final Widget? extra;

  /// Mặc định là `Navigator.pop(true)`.
  ///
  /// Ghi đè khi quyết định thuộc về một BLoC: ở những chỗ đó việc xoá là bất
  /// đồng bộ và có thể thất bại, nên dialog phải ở lại cho tới khi BLoC nói xong
  /// chứ không được đóng ngay lúc bấm.
  final VoidCallback? onConfirm;

  /// Mặc định là `Navigator.pop(false)`.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(Gap.xxl),
      contentPadding: const EdgeInsets.fromLTRB(Gap.xl, Gap.lg, Gap.xl, 0),
      titlePadding: const EdgeInsets.fromLTRB(Gap.xl, Gap.xl, Gap.xl, 0),
      actionsPadding: const EdgeInsets.all(Gap.xl),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 512),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (body case final String text) ...<Widget>[
              Text(
                text,
                style: LedgerText.bodyLg.copyWith(color: colors.inkSecondary),
              ),
              const SizedBox(height: Gap.lg),
            ],
            if (consequence case final FeedbackMessage message) ...<Widget>[
              BannerMessage(message),
              const SizedBox(height: Gap.lg),
            ],
            ?extra,
          ],
        ),
      ),
      actions: <Widget>[
        OutlinedButton(
          onPressed: isBusy
              ? null
              : (onCancel ?? () => Navigator.of(context).pop(false)),
          child: Text(cancelLabel),
        ),
        DestructiveButton(
          label: confirmLabel,
          onPressed: isBusy || !canConfirm
              ? null
              : (onConfirm ?? () => Navigator.of(context).pop(true)),
        ),
      ],
    );
  }
}

/// Nút phá huỷ: viền và chữ `ruby-ink` trên nền trắng, không bao giờ tô đặc.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final style = OutlinedButton.styleFrom(
      foregroundColor: colors.moneyOut,
      backgroundColor: colors.canvas,
      disabledForegroundColor: colors.inkMute,
      side: BorderSide(
        color: onPressed == null ? colors.hairline : colors.moneyOut,
      ),
      textStyle: LedgerText.buttonSm,
      shape: Corner.pillBorder,
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
    );

    if (icon == null) {
      return OutlinedButton(
        onPressed: onPressed,
        style: style,
        child: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// Mở [ConfirmDialog] và trả về `true` khi người dùng xác nhận.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? body,
  FeedbackMessage? consequence,
  String cancelLabel = 'Keep it',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ConfirmDialog(
      title: title,
      body: body,
      consequence: consequence,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return confirmed ?? false;
}
