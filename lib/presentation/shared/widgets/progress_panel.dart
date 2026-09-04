import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'frame_pulse.dart';

/// Thanh tiến độ 4px kèm [FramePulse] và một nhãn đếm.
///
/// Hai chỉ báo luôn đi cùng nhau và mỗi cái trả lời một câu hỏi khác: thanh nói
/// "còn bao nhiêu nữa", Frame Pulse nói "giao diện có còn thở không". Tách rời
/// chúng là bỏ mất nửa thông tin, nên widget này không cho phép hiển thị thanh
/// mà thiếu dải vạch.
class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    required this.label,
    this.fraction,
    this.detail,
    this.trailing,
    super.key,
  });

  /// Nhãn đếm, ví dụ `1.240 / 3.000`.
  final String label;

  /// `null` khi chưa biết tổng — thanh chuyển sang chạy vô hạn.
  final double? fraction;

  /// Dòng giải thích dưới thanh.
  final String? detail;

  /// Hành động ở mép phải, thường là nút Huỷ.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: Corner.pill,
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 4,
                      backgroundColor: colors.hairline,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    label,
                    style: LedgerText.caption.copyWith(color: colors.inkMute),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.lg),
            const FramePulse(),
            if (trailing != null) ...<Widget>[
              const SizedBox(width: Gap.lg),
              trailing!,
            ],
          ],
        ),
        if (detail case final String text when text.isNotEmpty) ...<Widget>[
          const SizedBox(height: Gap.md),
          Text(
            text,
            style: LedgerText.bodySm.copyWith(color: colors.inkSecondary),
          ),
        ],
      ],
    );
  }
}
