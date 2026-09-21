import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../shared/responsive/breakpoints.dart';
import '../bloc/diagnostics_state.dart';
import '../view_models/benchmark_view_model.dart';
import '../view_models/probe_view_models.dart';

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
    required this.onTestSelected,
    required this.onRepeatsSelected,
    super.key,
  });

  final DiagnosticsState state;
  final ValueChanged<BenchmarkWorkload> onWorkloadSelected;
  final ValueChanged<int> onBatchSizeSelected;
  final ValueChanged<int> onSampleSizeSelected;
  final VoidCallback onRun;
  final ValueChanged<DiagnosticsTest> onTestSelected;
  final ValueChanged<int> onRepeatsSelected;

  static const List<int> repeatCounts = <int>[1, 3, 5];

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
          label: 'Test',
          children: <Widget>[
            for (final test in DiagnosticsTest.values)
              _DarkChip(
                label: test.label,
                selected: state.test == test,
                onTap: state.isRunning ? null : () => onTestSelected(test),
              ),
          ],
        ),
        // Hai phép đo mới chạy thẳng trên workload tổng hợp và tự chọn cấu
        // hình của chúng, nên các núm chỉ có nghĩa với bảng hiệu năng được ẩn
        // đi thay vì để đó mà không tác dụng.
        if (state.test == DiagnosticsTest.throughput)
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
        if (state.test != DiagnosticsTest.cancellation)
          _ChipGroup(
            label: 'Batch size',
            children: <Widget>[
              for (final size in batchSizes)
                _DarkChip(
                  label: '$size',
                  selected: state.batchSize == size,
                  onTap: state.isRunning
                      ? null
                      : () => onBatchSizeSelected(size),
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
        if (state.test == DiagnosticsTest.throughput)
          _ChipGroup(
            label: 'Repeats',
            children: <Widget>[
              for (final count in repeatCounts)
                _DarkChip(
                  label: '×$count',
                  selected: state.repeats == count,
                  onTap: state.isRunning
                      ? null
                      : () => onRepeatsSelected(count),
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
              style: LedgerText.bodySm.copyWith(color: colors.darkInkMute),
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
          style: LedgerText.microCap.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: colors.darkInkMute,
          ),
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
    final disabled = onTap == null;
    final compact =
        WindowSizeClass.of(MediaQuery.sizeOf(context).width) ==
        WindowSizeClass.compact;
    return InkWell(
      onTap: onTap,
      borderRadius: Corner.pill,
      // **Không** đặt `alignment` ở [Container]: một Container có alignment mà
      // không có bề rộng cố định sẽ nở hết ràng buộc cha đưa xuống, và trong
      // một [Wrap] thì ràng buộc đó là trọn bề ngang màn hình. Đó là lý do mỗi
      // chip từng chiếm một dòng riêng, kéo bảng điều khiển dài ra vài màn.
      //
      // Chiều cao điều khiển bằng đệm dọc chứ không bằng `constraints`: đệm đối
      // xứng vẫn canh giữa được chữ mà không cần alignment. Con số ở bản hẹp đưa
      // chip lên ≈ 48dp — vùng chạm tối thiểu của [WindowSizeClass.compact].
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: compact ? 14 : 9,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.primarySoft : colors.darkSurface,
          borderRadius: Corner.pill,
          border: Border.all(
            color: selected ? colors.primarySoft : colors.darkHairline,
          ),
        ),
        child: Text(
          label,
          style: LedgerText.bodySm.copyWith(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? colors.onPrimary
                : disabled
                ? colors.darkInkMute
                : colors.darkInk,
          ),
        ),
      ),
    );
  }
}
