import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../shared/export/view_models/export_source.dart';
import '../shared/export/widgets/export_dialog.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/currency_tab_bar.dart';
import '../shared/widgets/empty_state.dart';
import '../shared/widgets/viewport_center.dart';
import '../shared/widgets/section_card.dart';
import '../shell/bloc/app_shell_bloc.dart';
import '../shell/bloc/app_shell_event.dart';
import '../shell/view_models/navigation_intent.dart';
import 'bloc/statistics_bloc.dart';
import 'bloc/statistics_event.dart';
import 'bloc/statistics_state.dart';
import 'view_models/cash_flow_view_model.dart';
import 'widgets/cash_flow_chart.dart';
import 'widgets/period_selector.dart';
import 'widgets/zero_effect_notice.dart';

/// Màn Thống kê (UC-10).
///
/// Ba điều được đóng cứng ở đây vì chúng là quy tắc nghiệp vụ, không phải tuỳ
/// chọn trình bày:
///
/// * Số liệu luôn thuộc về **đúng một loại tiền**. Dãy tab loại tiền luôn hiện,
///   kể cả khi chỉ có một loại, để không con số nào bị đọc nhầm là tổng của mọi
///   thứ.
/// * Công tắc loại trừ giao dịch nội bộ **mặc định bật và không ghi nhớ** giữa
///   các lần mở: nó là một câu hỏi ("nhìn theo cách nào") chứ không phải một cấu
///   hình, và một cấu hình bị quên sẽ âm thầm đổi nghĩa mọi con số ở lần mở sau.
/// * Bấm vào một cột mở danh sách giao dịch với đúng ngữ cảnh vừa bấm, kèm
///   Context Chip nói ra ngữ cảnh đó.
class StatisticsPage extends StatelessWidget {
  const StatisticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);
    final compact = sizeClass.usesBottomNavigation;

    return BlocBuilder<StatisticsBloc, StatisticsState>(
      builder: (context, state) {
        if (state.status.isInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.isEmpty) {
          return ViewportCenter(
            child: EmptyState(
              title: 'No figures yet',
              message:
                  'Statistics are built from imported transactions. Import a '
                  'statement file to get started.',
              icon: Icons.bar_chart,
              actionLabel: 'Go to Import',
              onAction: () => context.read<AppShellBloc>().add(
                const AppShellNavigationRequested(OpenImport()),
              ),
            ),
          );
        }

        final bloc = context.read<StatisticsBloc>();
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _Toolbar(state: state, compact: compact),
            if (state.error case final FeedbackMessage error)
              Padding(
                padding: const EdgeInsets.all(Gap.screen),
                child: BannerMessage(error),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.screen,
                vertical: Gap.md,
              ),
              child: ZeroEffectBanner(
                notice: state.zeroEffectNotice,
                onGoToImport: () => context.read<AppShellBloc>().add(
                  const AppShellNavigationRequested(OpenImport()),
                ),
                onGoToReconciliation: () => context.read<AppShellBloc>().add(
                  const AppShellNavigationRequested(OpenReconciliation()),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                Gap.sm,
                Gap.screen,
                Gap.lg,
              ),
              child: _Totals(state: state, sizeClass: sizeClass),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.screen,
                0,
                Gap.screen,
                Gap.xxl,
              ),
              child: _Charts(
                state: state,
                compact: compact,
                sideBySide: sizeClass == WindowSizeClass.expanded,
                onDrillDown: (bar) {
                  final intent = state.drillDownForBar(bar);
                  if (intent == null) return;
                  context.read<AppShellBloc>().add(
                    AppShellNavigationRequested(intent),
                  );
                },
                onExport: (grouping) {
                  final currency = state.currency;
                  if (currency == null) return;
                  ExportDialog.open(
                    context,
                    ExportStatisticsSource(
                      currency: currency,
                      grouping: grouping,
                      period: state.period,
                      dateRange: state.dateRange,
                      excludeInternalTransfers: state.excludeInternalTransfers,
                    ),
                  );
                },
                onPeriodChanged: (period) =>
                    bloc.add(StatisticsPeriodChanged(period)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.state, required this.compact});

  final StatisticsState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final bloc = context.read<StatisticsBloc>();

    // Ở bản hẹp dãy tab **ôm theo nội dung** chứ không trải hết bề ngang: trường
    // hợp phổ biến nhất là chỉ có một loại tiền, và một ô "VND" kéo dài cả màn
    // trông như một nút bấm chứ không phải một tab. Nhiều loại tiền mà không đủ
    // chỗ thì dãy cuộn ngang thay vì bóp nhãn thành "…".
    final tabs = CurrencyTabBar(
      currencies: state.currencies,
      selected: state.currency,
      onSelected: (currency) => bloc.add(StatisticsCurrencySelected(currency)),
    );
    final currencies = compact
        ? SingleChildScrollView(scrollDirection: Axis.horizontal, child: tabs)
        : tabs;
    final toggle = _ExcludeToggle(
      value: state.excludeInternalTransfers,
      onChanged: (value) => bloc.add(StatisticsInternalTransfersToggled(value)),
    );

    return Container(
      padding: const EdgeInsets.all(Gap.screen),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(bottom: BorderSide(color: colors.hairline)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                currencies,
                const SizedBox(height: Gap.md),
                toggle,
              ],
            )
          : Row(
              children: <Widget>[
                currencies,
                const SizedBox(width: Gap.lg),
                Flexible(child: toggle),
              ],
            ),
    );
  }
}

class _ExcludeToggle extends StatelessWidget {
  const _ExcludeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: Corner.radiusSm,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
        child: Row(
          children: <Widget>[
            Switch(value: value, onChanged: onChanged),
            const SizedBox(width: Gap.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Exclude confirmed internal transfers',
                    style: LedgerText.bodyMd.copyWith(color: colors.ink),
                  ),
                  Text(
                    'Resets to on every time this screen opens.',
                    style: LedgerText.caption.copyWith(color: colors.inkMute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ba số tổng, hạ bậc cỡ chữ theo breakpoint: 32 → 26 → 26px.
///
/// DESIGN.md đặt `display-xxl` (56px) cho số tổng ở Expanded. Con số đó dựng
/// cho một số tổng đứng **một mình**; ở đây có ba ô nằm ngay trên hai thẻ biểu
/// đồ, và ở cỡ ấy chúng nặng hơn hẳn phần chúng đang tóm tắt — mắt đọc ba con
/// số trước, hai biểu đồ sau, đúng ngược thứ tự mà màn hình này phục vụ.
///
/// Có một hệ quả phụ đáng giá: [FittedBox] chỉ thu **nhỏ**, nên ở cỡ cũ mỗi ô
/// hiển thị ở một cỡ chữ khác nhau tuỳ độ dài chuỗi tiền. Dưới trần mới thì cả
/// ba chuỗi đều vừa chỗ, nên ba ô cuối cùng cùng một cỡ chữ.
class _Totals extends StatelessWidget {
  const _Totals({required this.state, required this.sizeClass});

  final StatisticsState state;
  final WindowSizeClass sizeClass;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final chart = state.byPeriod;
    if (chart == null) return const SizedBox.shrink();

    final compact = sizeClass.usesBottomNavigation;
    final numberStyle = switch (sizeClass) {
      WindowSizeClass.expanded => LedgerText.displayLg,
      WindowSizeClass.medium || WindowSizeClass.compact => LedgerText.displayMd,
    };

    final tiles = <Widget>[
      _TotalTile(
        label: 'Money in',
        value: chart.totalInflowText,
        background: colors.moneyInSoft,
        foreground: colors.moneyIn,
        numberStyle: numberStyle,
        inline: compact,
      ),
      _TotalTile(
        label: 'Money out',
        value: chart.totalOutflowText,
        background: colors.rubyWash,
        foreground: colors.moneyOut,
        numberStyle: numberStyle,
        inline: compact,
      ),
      _TotalTile(
        label: 'Net',
        value: chart.totalNetText,
        background: colors.primaryWash,
        foreground: colors.primaryDeep,
        numberStyle: numberStyle,
        inline: compact,
      ),
    ];

    if (compact) {
      return Column(
        children: <Widget>[
          for (final tile in tiles)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.sm),
              child: tile,
            ),
        ],
      );
    }
    // `stretch` cần biết chiều cao trước, nhưng hàng này nằm trong một ListView
    // nên chiều cao dọc là vô hạn. `IntrinsicHeight` đo chiều cao của ô cao nhất
    // rồi mới kéo hai ô còn lại cho bằng — ba ô lệch nhau vài pixel trông như
    // một lỗi căn chỉnh, và ở đây chỉ có ba ô nên chi phí đo thêm là không đáng
    // kể.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final tile in tiles) ...<Widget>[
            Expanded(child: tile),
            if (tile != tiles.last) const SizedBox(width: Gap.lg),
          ],
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.label,
    required this.value,
    required this.background,
    required this.foreground,
    required this.numberStyle,
    this.inline = false,
  });

  final String label;
  final String value;
  final Color background;
  final Color foreground;
  final TextStyle numberStyle;

  /// Nhãn và số nằm **cùng một dòng**, nhãn trái số phải.
  ///
  /// Chỉ ở bản hẹp, và vì chiều cao: ba ô xếp dọc theo kiểu hai dòng chiếm gần
  /// trọn màn hình đầu tiên của điện thoại, nên người dùng phải cuộn qua ba con
  /// số mới tới được hai biểu đồ. Một dòng cắt đôi chiều cao đó, và ở bề ngang
  /// đầy đủ của màn hẹp thì nhãn với số vẫn không tranh chỗ nhau.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label.toUpperCase(),
      style: LedgerText.microCap.copyWith(color: foreground),
    );
    final valueText = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: inline ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        style: numberStyle.copyWith(color: foreground),
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: Gap.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: Corner.radiusLg,
      ),
      child: inline
          ? Row(
              children: <Widget>[
                labelText,
                const SizedBox(width: Gap.md),
                Expanded(child: valueText),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                labelText,
                const SizedBox(height: Gap.xs),
                valueText,
              ],
            ),
    );
  }
}

class _Charts extends StatelessWidget {
  const _Charts({
    required this.state,
    required this.compact,
    required this.sideBySide,
    required this.onDrillDown,
    required this.onExport,
    required this.onPeriodChanged,
  });

  final StatisticsState state;
  final bool compact;

  /// Hai card đứng cạnh nhau — chỉ ở Expanded. Ở Medium (600–1023) mỗi card
  /// chỉ còn chừng 300px: thanh chọn kỳ và dòng số tiền của biểu đồ theo tài
  /// khoản tràn ngang, nên ở đó hai card xếp chồng như bản hẹp.
  final bool sideBySide;
  final ValueChanged<CashFlowBarViewModel> onDrillDown;

  /// Xuất **đúng biểu đồ** vừa bấm: hai biểu đồ là hai cách gom nhóm khác nhau
  /// của cùng một tập dữ liệu, nên một nút xuất chung sẽ luôn xuất sai một
  /// trong hai.
  final ValueChanged<CashFlowGrouping> onExport;
  final ValueChanged<CashFlowPeriod> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    final byPeriod = state.byPeriod;
    final byAccount = state.byAccount;
    // Đứng cạnh nhau thì hai card phải cao bằng nhau; xếp chồng thì mỗi card
    // giữ chiều cao tự nhiên của nó.
    final fill = sideBySide;

    final periodCard = SectionCard(
      fill: fill,
      title: 'By period',
      subtitle: 'Select a column to see its transactions.',
      trailing: IconButton(
        tooltip: 'Export these figures',
        icon: const Icon(Icons.file_download_outlined, size: 18),
        onPressed: () => onExport(CashFlowGrouping.byPeriod),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PeriodSelector(
            period: state.period,
            expand: compact,
            onSelected: onPeriodChanged,
          ),
          const SizedBox(height: Gap.xl),
          if (byPeriod != null)
            if (fill)
              Expanded(
                child: CashFlowChart(
                  chart: byPeriod,
                  onBarTapped: onDrillDown,
                  fill: true,
                ),
              )
            else
              CashFlowChart(chart: byPeriod, onBarTapped: onDrillDown),
        ],
      ),
    );

    final accountCard = SectionCard(
      fill: fill,
      title: 'By account',
      subtitle: 'Accounts holding ${state.currency?.code} transactions.',
      trailing: IconButton(
        tooltip: 'Export these figures',
        icon: const Icon(Icons.file_download_outlined, size: 18),
        onPressed: () => onExport(CashFlowGrouping.byAccount),
      ),
      child: byAccount == null
          ? const SizedBox.shrink()
          : CashFlowChart(
              chart: byAccount,
              onBarTapped: onDrillDown,
              fill: fill,
            ),
    );

    if (!sideBySide) {
      return Column(
        children: <Widget>[
          periodCard,
          const SizedBox(height: Gap.lg),
          accountCard,
        ],
      );
    }
    // `IntrinsicHeight` kéo hai card về chiều cao của card cao hơn. Card theo
    // kỳ có thêm thanh chọn kỳ và vùng cột 200px, còn card theo tài khoản
    // thường chỉ vài thanh ngang — không kéo thì card phải hụt hẳn một khúc và
    // hai chú thích nằm lệch nhau.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: periodCard),
          const SizedBox(width: Gap.lg),
          Expanded(child: accountCard),
        ],
      ),
    );
  }
}
