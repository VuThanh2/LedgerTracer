import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../frame_timing_recorder.dart';
import '../view_models/benchmark_view_model.dart';

/// Kết quả đo của từng chiến lược đồng thời.
///
/// Bốn số đo đứng cạnh nhau cho mỗi lượt chạy vì chúng chỉ có nghĩa khi đọc
/// cùng: tổng thời gian nói chiến lược nào nhanh hơn, còn thống kê frame time
/// nói cái giá phải trả cho tốc độ đó. Một chiến lược nhanh hơn 20% mà đẩy p95
/// vượt ngưỡng 16ms là một chiến lược tệ hơn cho màn hình này.
class StrategyResultTable extends StatelessWidget {
  const StrategyResultTable({required this.runs, super.key});

  final List<BenchmarkRunViewModel> runs;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (runs.isEmpty) {
      return Text(
        'No run measured yet. Pick a workload and press Run.',
        style: LedgerText.caption.copyWith(color: colors.darkInkMute),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final run in runs) ...<Widget>[
          _RunCard(run: run),
          const SizedBox(height: Gap.md),
        ],
      ],
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({required this.run});

  final BenchmarkRunViewModel run;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: colors.darkSurface,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.darkHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${run.modeLabel} ×${run.parallelism} · batch '
                  '${run.batchSize}',
                  style: LedgerText.bodySm.copyWith(color: colors.onPrimary),
                ),
              ),
              if (run.degraded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: Gap.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.canvasCream,
                    borderRadius: Corner.pill,
                  ),
                  child: Text(
                    'FELL BACK TO THE INTERFACE THREAD',
                    style: LedgerText.microCap.copyWith(color: colors.lemonInk),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Wrap(
            spacing: Gap.xl,
            runSpacing: Gap.md,
            children: <Widget>[
              _Metric(value: run.elapsedText, label: 'total time'),
              _Metric(value: run.throughputText, label: 'throughput'),
              _Metric(value: run.batchCountText, label: 'batches'),
              _Metric(value: run.itemsProcessedText, label: 'items'),
            ],
          ),
          const SizedBox(height: Gap.md),
          _FrameStats(frames: run.frames),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          value,
          style: LedgerText.tabularLg.copyWith(color: colors.primarySubdued),
        ),
        Text(
          label.toUpperCase(),
          style: LedgerText.microCap.copyWith(color: colors.darkInkMute),
        ),
      ],
    );
  }
}

/// Thống kê frame time của lượt chạy, kèm dải cột so với ngưỡng ngân sách.
///
/// Cột vượt ngân sách 16ms tô magenta — màu chỉ dùng ở đây, và chỉ để nói một
/// điều: khung hình này đã trễ.
class _FrameStats extends StatelessWidget {
  const _FrameStats({required this.frames});

  final FrameTimingStats frames;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (frames.frameCount == 0) {
      return Text(
        'No frames were recorded during this run.',
        style: LedgerText.monoLog.copyWith(color: colors.darkInkMute),
      );
    }

    final jankyPercent = (frames.jankyRatio * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'FRAME TIME · BUDGET '
          '${FrameTimingRecorder.frameBudgetMillis.toStringAsFixed(1)}MS',
          style: LedgerText.microCap.copyWith(color: colors.darkInkMute),
        ),
        const SizedBox(height: Gap.sm),
        Text(
          'average ${frames.averageMillis.toStringAsFixed(1)}ms · '
          'p95 ${frames.p95Millis.toStringAsFixed(1)}ms · '
          'worst ${frames.worstMillis.toStringAsFixed(1)}ms · '
          '${frames.jankyFrameCount}/${frames.frameCount} frames over budget '
          '($jankyPercent%)',
          style: LedgerText.monoLog.copyWith(
            color: frames.jankyFrameCount > 0
                ? colors.magenta
                : colors.primarySubdued,
          ),
        ),
      ],
    );
  }
}
