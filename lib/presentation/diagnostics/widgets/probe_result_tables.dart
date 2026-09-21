import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../view_models/probe_view_models.dart';

/// Bảng độ trễ huỷ: mỗi dòng một cặp cỡ lô × chế độ chạy.
///
/// Đọc theo chiều dọc trong cùng một chế độ: độ trễ và số phần tử lọt qua sau
/// lệnh huỷ phải tăng theo cỡ lô. Đó là con số đứng sau câu "nút Huỷ chỉ phản
/// hồi tại ranh giới giữa các lô" (UC-02, UC-14).
class CancelProbeTable extends StatelessWidget {
  const CancelProbeTable({required this.runs, super.key});

  final List<CancelProbeViewModel> runs;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) return const _NothingYet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final run in runs) ...<Widget>[
          _ProbeCard(
            title: '${run.modeLabel} · batch ${run.batchSize}',
            metrics: <_MetricData>[
              _MetricData(run.latencyText, 'cancel → stopped'),
              _MetricData(run.itemsAfterText, 'items after cancel'),
              _MetricData(run.batchesAfterText, 'batches after cancel'),
            ],
          ),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

/// Bảng hàng đợi chờ ghi: có giới hạn, không giới hạn, và luồng chính.
///
/// Dòng "no limit" là dòng để so: số lô nằm chờ của nó tăng theo cỡ workload,
/// còn dòng có giới hạn thì đứng yên ở giới hạn. Dòng luồng chính luôn là 1 —
/// phân tích và ghi chung một luồng nên không có gì để dồn (UC-14).
class BackpressureProbeTable extends StatelessWidget {
  const BackpressureProbeTable({required this.runs, super.key});

  final List<BackpressureProbeViewModel> runs;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) return const _NothingYet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final run in runs) ...<Widget>[
          _ProbeCard(
            title:
                '${run.modeLabel} · batch ${run.batchSize} · '
                '${run.limitText}',
            highlight: !run.isCapped,
            metrics: <_MetricData>[
              _MetricData(run.peakBatchesText, 'peak batches waiting'),
              _MetricData(run.peakItemsText, 'peak items waiting'),
              _MetricData(run.producerText, 'reading finished'),
              _MetricData(run.consumerText, 'writing finished'),
            ],
          ),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) => Text(
    'No run measured yet. Press Run.',
    style: LedgerText.bodySm.copyWith(color: context.ledger.darkInkMute),
  );
}

final class _MetricData {
  const _MetricData(this.value, this.label);

  final String value;
  final String label;
}

/// Cùng hình dạng thẻ với bảng hiệu năng (`StrategyResultTable`) để ba bảng
/// đọc như một bộ. Không dùng lại thẻ của bảng đó vì nó gắn với phần thống kê
/// khung hình, thứ hai phép đo này không có.
class _ProbeCard extends StatelessWidget {
  const _ProbeCard({
    required this.title,
    required this.metrics,
    this.highlight = false,
  });

  final String title;
  final List<_MetricData> metrics;

  /// Dòng đối chứng (cấu hình cố ý tệ) được viền màu để mắt tìm ra ngay.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: colors.darkSurface,
        borderRadius: Corner.radiusMd,
        border: Border.all(
          color: highlight ? colors.magenta : colors.darkHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: LedgerText.bodySm.copyWith(color: colors.onPrimary),
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.xl,
            runSpacing: Gap.md,
            children: <Widget>[
              for (final metric in metrics)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      metric.value,
                      style: LedgerText.tabularLg.copyWith(
                        color: colors.primarySubdued,
                      ),
                    ),
                    Text(
                      metric.label.toUpperCase(),
                      style: LedgerText.microCap.copyWith(
                        fontSize: 12,
                        letterSpacing: 0.6,
                        color: colors.darkInkMute,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
