import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/progress_panel.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/web_limitation_banner.dart';
import '../bloc/import_state.dart';

/// Bước 3: tiến trình theo lô (UC-02 b5–b7 · UC-14).
///
/// Hai điều phải nói đúng ở màn này:
///
/// * **Huỷ có hiệu lực ở ranh giới lô**, không tức thì. Người dùng bấm Huỷ rồi
///   thấy số dòng vẫn nhích là chuyện bình thường, và nếu không nói trước thì họ
///   sẽ bấm thêm vài lần nữa.
/// * Trên bản Web, việc phân tích chia chung luồng giao diện. Chỉ báo suy biến
///   nói ra điều đó, còn Frame Pulse cạnh thanh tiến độ **chứng minh** nó.
class StepProgress extends StatelessWidget {
  const StepProgress({required this.state, super.key});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionCard(
          child: ProgressPanel(
            label: _labelOf(state),
            fraction: progress?.sessionFraction,
            detail:
                'The moving marks beside the bar show the screen is still '
                'responsive. If they freeze, the device is struggling to keep '
                'up.',
          ),
        ),
        const SizedBox(height: Gap.md),
        WebLimitationBanner(supportsIsolates: state.supportsIsolates),
        if (state.isCancelling) ...<Widget>[
          const SizedBox(height: Gap.md),
          const BannerMessage(
            FeedbackMessage.info(
              'Cancelling… The current batch finishes first. Everything '
              'saved so far is kept.',
            ),
          ),
        ],
      ],
    );
  }

  static String _labelOf(ImportState state) {
    final progress = state.progress;
    if (progress == null) return 'Preparing…';
    return '${progress.processedTotalText} rows read · file '
        '${progress.completedFiles + 1} of ${progress.fileCount} · '
        '${progress.reportingFileName}';
  }
}
