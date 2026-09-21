import 'package:flutter/material.dart';

import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../bloc/statistics_state.dart';

/// Ghi chú khi công tắc loại trừ đang bật mà chưa loại được gì (UC-10).
///
/// Không có nó, người dùng bật công tắc, thấy biểu đồ không đổi, và kết luận sai
/// một trong hai điều: công tắc hỏng, hoặc dữ liệu của họ không có chuyển khoản
/// nội bộ. Sự thật là chưa có cặp nào **được xác nhận** — và lối thoát khác nhau
/// tuỳ tình huống, nên liên kết cũng phải khác nhau: chưa đủ hai tài khoản thì
/// đường đi là Nhập, đủ rồi thì đường đi là Đối soát.
class ZeroEffectBanner extends StatelessWidget {
  const ZeroEffectBanner({
    required this.notice,
    required this.onGoToImport,
    required this.onGoToReconciliation,
    super.key,
  });

  final ZeroEffectNotice notice;
  final VoidCallback onGoToImport;
  final VoidCallback onGoToReconciliation;

  @override
  Widget build(BuildContext context) => switch (notice) {
    ZeroEffectNotice.none => const SizedBox.shrink(),
    ZeroEffectNotice.needsMoreAccounts => BannerMessage(
      const FeedbackMessage.info(
        'Excluding internal transfers has no effect yet — reconciliation needs '
        'transactions in at least two accounts.',
      ),
      action: TextButton(
        onPressed: onGoToImport,
        child: const Text('Import more statements'),
      ),
    ),
    ZeroEffectNotice.needsConfirmedPairs => BannerMessage(
      const FeedbackMessage.info(
        'Excluding internal transfers has no effect yet — no transfer pair '
        'has been confirmed.',
      ),
      action: TextButton(
        onPressed: onGoToReconciliation,
        child: const Text('Open reconciliation'),
      ),
    ),
  };
}
