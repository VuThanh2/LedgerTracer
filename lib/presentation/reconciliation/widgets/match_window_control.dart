import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Chỉnh `matchWindowDays` ngay tại màn Đối soát, **không** nằm trong Cài đặt.
///
/// Nó là một tham số của lần quét sắp chạy, không phải một tuỳ chọn của ứng
/// dụng: người dùng nới cửa sổ khi thấy lần quét trước bỏ sót, và quyết định đó
/// hình thành ngay trước mặt danh sách kết quả. Chôn nó vào Cài đặt là bắt họ
/// rời màn hình rồi quay lại để thử một con số.
class MatchWindowControl extends StatelessWidget {
  const MatchWindowControl({
    required this.days,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final int days;
  final ValueChanged<int> onChanged;

  /// Khoá trong lúc đang quét: đổi cửa sổ giữa chừng không ảnh hưởng lượt đang
  /// chạy, nên cho bấm là hứa một điều không xảy ra.
  final bool enabled;

  /// Cửa sổ tối thiểu là 1 ngày — `MatchWindow` từ chối số nhỏ hơn.
  static const int minDays = 1;
  static const int maxDays = 14;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'MATCH WINDOW',
          style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Gap.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _StepButton(
              icon: Icons.remove,
              onPressed: enabled && days > minDays
                  ? () => onChanged(days - 1)
                  : null,
            ),
            SizedBox(
              width: 76,
              child: Text(
                '± $days days',
                textAlign: TextAlign.center,
                style: LedgerText.bodyTabular.copyWith(color: colors.ink),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onPressed: enabled && days < maxDays
                  ? () => onChanged(days + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      borderRadius: Corner.pill,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? colors.hairlineControl : colors.hairline,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? colors.inkSecondary : colors.hairlineStructure,
        ),
      ),
    );
  }
}
