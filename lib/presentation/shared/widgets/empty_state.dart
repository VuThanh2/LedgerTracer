import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Màn trống — **lời mời hành động, không phải lời xin lỗi**.
///
/// Vì vậy [message] phải nói điều gì sẽ đưa dữ liệu vào đây ("Chưa có giao dịch
/// nào. Nhập một file sao kê để bắt đầu.") thay vì mô tả sự vắng mặt ("Không tìm
/// thấy dữ liệu"), và một `button-secondary` dẫn thẳng tới hành động đó.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Một dòng `display-md`, nói tình huống.
  final String title;

  /// Một dòng `body-lg`, nói cách thoát khỏi tình huống đó.
  final String message;

  final IconData icon;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.lg,
        vertical: Gap.xxl,
      ),
      decoration: BoxDecoration(
        color: colors.canvasSoft,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 32, color: colors.hairlineStructure),
          const SizedBox(height: Gap.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: LedgerText.displayMd.copyWith(color: colors.ink),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: LedgerText.bodyLg.copyWith(color: colors.inkSecondary),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: Gap.lg),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
