import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/frame_pulse.dart';
import 'bloc/diagnostics_bloc.dart';
import 'bloc/diagnostics_event.dart';
import 'bloc/diagnostics_state.dart';
import 'widgets/strategy_result_table.dart';
import 'widgets/workload_controls.dart';

/// Màn Developer Diagnostics — phục vụ phần thực nghiệm, nằm ngoài Domain.
///
/// Chạy cùng một workload qua từng chiến lược đồng thời và đo lại: tổng thời
/// gian, thống kê frame time, số lô. Đây là chỗ duy nhất của ứng dụng dùng bảng
/// màu tối, và bảng màu ấy **cục bộ** — bọc riêng màn này bằng một `Theme` chứ
/// không đụng tới theme gốc.
///
/// Frame Pulse ở đây không phải trang trí: nó chạy cạnh thanh tiến độ trong lúc
/// workload chiếm luồng, nên nó là bản đọc trực quan của chính con số p95 mà
/// bảng kết quả in ra.
class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const DiagnosticsPage());

  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context);
    return BlocProvider<DiagnosticsBloc>(
      create: (_) => DiagnosticsBloc(
        runBenchmark: dependencies.runBenchmark,
        capabilities: dependencies.capabilities,
      )..add(const DiagnosticsStarted()),
      child: Theme(
        data: LedgerTheme.diagnostics(Theme.of(context)),
        child: const _DiagnosticsView(),
      ),
    );
  }
}

class _DiagnosticsView extends StatelessWidget {
  const _DiagnosticsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer diagnostics'),
        actions: <Widget>[
          BlocBuilder<DiagnosticsBloc, DiagnosticsState>(
            buildWhen: (previous, current) =>
                previous.hasResults != current.hasResults ||
                previous.isRunning != current.isRunning,
            builder: (context, state) => TextButton(
              onPressed: state.hasResults && !state.isRunning
                  ? () => context.read<DiagnosticsBloc>().add(
                      const DiagnosticsCleared(),
                    )
                  : null,
              child: const Text('Clear results'),
            ),
          ),
        ],
      ),
      body: BlocBuilder<DiagnosticsBloc, DiagnosticsState>(
        builder: (context, state) {
          final bloc = context.read<DiagnosticsBloc>();
          return ListView(
            padding: const EdgeInsets.all(Gap.screen),
            children: <Widget>[
              WorkloadControls(
                state: state,
                onWorkloadSelected: (workload) =>
                    bloc.add(DiagnosticsWorkloadSelected(workload)),
                onBatchSizeSelected: (size) =>
                    bloc.add(DiagnosticsBatchSizeChanged(size)),
                onSampleSizeSelected: (size) =>
                    bloc.add(DiagnosticsSampleSizeChanged(size)),
                onRun: () => bloc.add(const DiagnosticsRunRequested()),
              ),
              const SizedBox(height: Gap.lg),

              if (state.error case final FeedbackMessage error) ...<Widget>[
                BannerMessage(error),
                const SizedBox(height: Gap.lg),
              ],

              _RunProgress(state: state),
              const SizedBox(height: Gap.lg),

              Text(
                'MACHINE: ${state.processorCount} cores · '
                '${state.supportsIsolates ? 'isolates available' : 'no isolates'}',
                style: LedgerText.microCap.copyWith(color: colors.darkInkMute),
              ),
              const SizedBox(height: Gap.md),

              StrategyResultTable(runs: state.runs),
              const SizedBox(height: Gap.xxl),
            ],
          );
        },
      ),
    );
  }
}

class _RunProgress extends StatelessWidget {
  const _RunProgress({required this.state});

  final DiagnosticsState state;

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
                child: ClipRRect(
                  borderRadius: Corner.pill,
                  child: LinearProgressIndicator(
                    value: state.isRunning ? state.progress : 0,
                    minHeight: 4,
                    backgroundColor: colors.darkHairline,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: Gap.md),
              FramePulse(onDark: true, running: state.isRunning),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(
            state.isRunning
                ? 'Strategy ${state.runningStrategyIndex + 1}/'
                      '${state.strategyCount} · ${state.sampleSize} items · '
                      'batch ${state.batchSize}'
                : 'Idle.',
            style: LedgerText.monoLog.copyWith(color: colors.darkInkMute),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            'The pulse runs off the frame ticker. It stalls exactly when the '
            'workload holds the interface thread — which is what the p95 figure '
            'below measures.',
            style: LedgerText.monoLog.copyWith(color: colors.darkInkMute),
          ),
        ],
      ),
    );
  }
}
