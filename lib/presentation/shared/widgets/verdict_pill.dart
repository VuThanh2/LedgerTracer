import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Ba trạng thái phán quyết của một cặp đối soát.
///
/// Không dùng thẳng `PairStatus` của Domain vì "đã từ chối" không phải một
/// [PairStatus]: cặp bị từ chối biến mất khỏi bảng cặp và chỉ còn lại ở sổ
/// `RejectedMatch`. Trên màn hình thì cả ba là **một** kênh thị giác, nên kênh
/// đó cần một kiểu riêng của tầng trình bày.
enum VerdictTone {
  /// Gợi ý — hệ thống đề xuất, người dùng chưa quyết.
  pending,

  confirmed,

  /// Xám trung tính: từ chối là một phán quyết hợp lệ, không phải sự cố.
  rejected,
}

/// Pill trạng thái: nền nhạt, căn trái, **không icon**.
///
/// Việc pill không bao giờ có icon còn banner thì luôn có là quy tắc tách hai
/// kênh ngữ nghĩa ở tầng nhận biết — người dùng phân biệt "trạng thái của một
/// dòng" với "hệ thống đang nói gì" bằng hình dạng trước khi đọc chữ.
class VerdictPill extends StatelessWidget {
  const VerdictPill({required this.tone, required this.label, super.key});

  final VerdictTone tone;

  /// Nhãn đã kèm số đếm nếu có, ví dụ `Gợi ý (47)`.
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final (background, foreground) = switch (tone) {
      VerdictTone.pending => (colors.canvasCream, colors.lemonInk),
      VerdictTone.confirmed => (colors.moneyInSoft, colors.moneyIn),
      VerdictTone.rejected => (colors.hairline, colors.inkSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      decoration: BoxDecoration(color: background, borderRadius: Corner.pill),
      child: Text(
        label.toUpperCase(),
        style: LedgerText.microCap.copyWith(color: foreground),
      ),
    );
  }
}

/// Pill trung tính, dùng cho nhãn không mang phán quyết — trạng thái một lượt
/// nhập, một định dạng file.
class TonePill extends StatelessWidget {
  const TonePill({
    required this.label,
    required this.background,
    required this.foreground,
    super.key,
  });

  /// Biến thể indigo dịu, dùng cho badge định dạng file và Context Chip tĩnh.
  factory TonePill.soft(BuildContext context, String label) {
    final colors = context.ledger;
    return TonePill(
      label: label,
      background: colors.primarySubdued,
      foreground: colors.primaryPress,
    );
  }

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
    decoration: BoxDecoration(color: background, borderRadius: Corner.pill),
    child: Text(
      label.toUpperCase(),
      style: LedgerText.microCap.copyWith(color: foreground),
    ),
  );
}

/// Nhãn "giao dịch nội bộ": **viền, không nền**, có icon dẫn đầu.
///
/// Cố ý là hạng thị giác thứ ba. Nó đứng cùng dòng với [VerdictPill] nên nếu
/// cũng tô nền thì hai nhãn tranh nhau, và người dùng mất tín hiệu "cái nào là
/// phán quyết".
class InternalBadge extends StatelessWidget {
  const InternalBadge({this.label = 'Internal', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: Corner.pill,
        border: Border.all(color: colors.hairlineControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.swap_horiz, size: 12, color: colors.inkSecondary),
          const SizedBox(width: Gap.xs),
          Text(
            label.toUpperCase(),
            style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
          ),
        ],
      ),
    );
  }
}
