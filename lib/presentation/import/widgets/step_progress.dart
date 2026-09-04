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
                'The pulse beside the bar runs off the frame ticker, not the '
                'data. If it stalls, the interface thread is blocked.',
          ),
        ),
        const SizedBox(height: Gap.md),
        WebLimitationBanner(supportsIsolates: state.supportsIsolates),
        if (state.isCancelling) ...<Widget>[
          const SizedBox(height: Gap.md),
          const BannerMessage(
            FeedbackMessage.info(
              'Cancel requested. It takes effect at the next batch boundary; '
              'rows already committed stay.',
            ),
          ),
        ],
      ],
    );
  }

  static String _labelOf(ImportState state) {
    final progress = state.progress;
    if (progress == null) return 'Preparing…';
    return '${progress.processedTotalText} rows committed · file '
        '${progress.completedFiles + 1}/${progress.fileCount} · '
        '${progress.reportingFileName}';
  }
}
