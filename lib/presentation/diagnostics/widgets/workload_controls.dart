import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../bloc/diagnostics_state.dart';
import '../view_models/benchmark_view_model.dart';

/// Bảng điều khiển của màn thực nghiệm: chọn workload, cỡ mẫu và cỡ lô.
///
/// Đặt trên nền tối `brand-dark-900`, nên nó không dùng được các token màu chữ
/// của giao diện sáng. Bảng màu tối là **cục bộ** cho màn này, đúng như DESIGN.md
/// quy định, và giới hạn đó chính là lý do màn này có widget điều khiển riêng
/// thay vì dùng lại `ToggleChip` của giao diện sáng.
class WorkloadControls extends StatelessWidget {
  const WorkloadControls({
    required this.state,
    required this.onWorkloadSelected,
    required this.onBatchSizeSelected,
    required this.onSampleSizeSelected,
    required this.onRun,
    super.key,
  });

  final DiagnosticsState state;
  final ValueChanged<BenchmarkWorkload> onWorkloadSelected;
  final ValueChanged<int> onBatchSizeSelected;
  final ValueChanged<int> onSampleSizeSelected;
  final VoidCallback onRun;

  static const List<int> batchSizes = <int>[500, 2000, 8000];
  static const List<int> sampleSizes = <int>[50000, 200000, 500000];

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Wrap(
      spacing: Gap.xl,
      runSpacing: Gap.lg,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: <Widget>[
        _ChipGroup(
          label: 'Workload',
          children: <Widget>[
            for (final workload in BenchmarkWorkload.values)
              _DarkChip(
                label: workload.label,
                selected: state.workload == workload,
                onTap: state.isRunning
                    ? null
                    : () => onWorkloadSelected(workload),
              ),
          ],
        ),
        _ChipGroup(
          label: 'Batch size',
          children: <Widget>[
            for (final size in batchSizes)
              _DarkChip(
                label: '$size',
                selected: state.batchSize == size,
                onTap: state.isRunning ? null : () => onBatchSizeSelected(size),
              ),
          ],
        ),
        _ChipGroup(
          label: 'Item count',
          children: <Widget>[
            for (final size in sampleSizes)
              _DarkChip(
                label: '${size ~/ 1000}k',
                selected: state.sampleSize == size,
                onTap: state.isRunning
                    ? null
                    : () => onSampleSizeSelected(size),
              ),
          ],
        ),
        FilledButton(
          onPressed: state.isRunning ? null : onRun,
          child: Text(state.isRunning ? 'Running…' : 'Run workload'),
        ),
        if (!state.supportsIsolates)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              'This platform has no isolates, so only the interface-thread '
              'strategy can be measured.',
              style: LedgerText.caption.copyWith(color: colors.darkInkMute),
            ),
          ),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: LedgerText.microCap.copyWith(color: colors.darkInkMute),
        ),
        const SizedBox(height: Gap.sm),
        Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: children),
      ],
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.pill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        constraints: const BoxConstraints(minHeight: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? colors.primary : Colors.transparent,
          borderRadius: Corner.pill,
          border: Border.all(
            color: selected ? colors.primary : colors.darkHairline,
          ),
        ),
        child: Text(
          label,
          style: LedgerText.micro.copyWith(
            color: selected ? colors.onPrimary : colors.darkInkMute,
          ),
        ),
      ),
    );
  }
}
