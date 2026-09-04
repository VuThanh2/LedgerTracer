import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../accounts/widgets/account_form_dialog.dart';
import '../shared/export/view_models/export_source.dart';
import '../shared/export/widgets/export_dialog.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/responsive/breakpoints.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/confirm_dialog.dart';
import '../shell/bloc/app_shell_bloc.dart';
import '../shell/bloc/app_shell_event.dart';
import '../shell/view_models/navigation_intent.dart';
import 'bloc/import_bloc.dart';
import 'bloc/import_event.dart';
import 'bloc/import_history_bloc.dart';
import 'bloc/import_history_event.dart';
import 'bloc/import_state.dart';
import 'view_models/import_file_entry.dart';
import 'widgets/import_history_tab.dart';
import 'widgets/import_stepper.dart';
import 'widgets/step_assign_accounts.dart';
import 'widgets/step_pick_files.dart';
import 'widgets/step_progress.dart';
import 'widgets/step_summary.dart';

/// Màn Nhập: một route, hai tab (UC-02, UC-03, UC-14).
///
/// Bốn bước của tab *Nhập mới* là trạng thái của `ImportBloc`, không phải bốn
/// route — nhờ vậy người dùng chuyển sang tab Lịch sử hay sang màn khác giữa
/// chừng mà lượt nhập vẫn chạy tiếp, đúng như thiết kế yêu cầu.
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(_onTabChanged);

  bool _historyLoaded = false;

  void _onTabChanged() {
    if (_tabs.index != 1 || _historyLoaded) return;
    _historyLoaded = true;
    context.read<ImportHistoryBloc>().add(const ImportHistoryStarted());
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  /// Tạo tài khoản ngay trong luồng nhập bằng **đúng** form của màn Quản lý tài
  /// khoản (UC-01).
  ///
  /// Một component, hai điểm vào — Screen Map yêu cầu như vậy, và lý do là thực
  /// tế: hai form riêng sẽ lệch nhau ở lần đầu ai đó thêm một trường, và người
  /// dùng sẽ thấy hai hộp thoại "tạo tài khoản" khác nhau tuỳ nơi họ đứng.
  ///
  /// Khác biệt duy nhất là đích đến của kết quả: ở đây nó đi qua `ImportBloc` để
  /// tài khoản vừa tạo được gán thẳng cho file đang gặp vấn đề, thay vì bắt
  /// người dùng quay ra chọn lại — đúng bước mà họ đang cố tránh.
  Future<void> _createAccountFor(BuildContext context, String fileName) async {
    final bloc = context.read<ImportBloc>();
    final result = await AccountFormDialog.show(context);
    if (result == null) return;
    bloc.add(
      ImportAccountCreated(
        displayName: result.displayName,
        assignToFileName: fileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: colors.canvas,
            border: Border(bottom: BorderSide(color: colors.hairline)),
          ),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: colors.primary,
            indicatorWeight: 2,
            dividerColor: Colors.transparent,
            labelColor: colors.ink,
            unselectedLabelColor: colors.inkMuteNav,
            labelStyle: LedgerText.bodyMd,
            unselectedLabelStyle: LedgerText.bodyMd,
            tabs: const <Widget>[
              Tab(text: 'New import'),
              Tab(text: 'History'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            // Không cho vuốt ngang giữa hai tab: bước 2 có ô chọn tài khoản và
            // bước 4 có bảng cuộn ngang, nên cử chỉ ngang ở đây luôn mơ hồ.
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              _NewImportTab(onCreateAccount: _createAccountFor),
              const ImportHistoryTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewImportTab extends StatelessWidget {
  const _NewImportTab({required this.onCreateAccount});

  final Future<void> Function(BuildContext context, String fileName)
  onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(MediaQuery.sizeOf(context).width);

    return BlocConsumer<ImportBloc, ImportState>(
      listenWhen: (previous, current) => previous.notice != current.notice,
      listener: (context, state) {
        if (state.notice case final notice?) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(notice.message.text)));
        }
      },
      builder: (context, state) {
        final bloc = context.read<ImportBloc>();
        return Column(
          children: <Widget>[
            ImportStepper(
              step: state.step,
              showLabels: !sizeClass.usesBottomNavigation,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Gap.screen),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 840),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            'Step ${state.step.index + 1} of 4',
                            style: LedgerText.microCap.copyWith(
                              color: context.ledger.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            ImportStepper.titleOf(state.step),
                            style: LedgerText.displayMd.copyWith(
                              color: context.ledger.ink,
                            ),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            ImportStepper.subtitleOf(state.step),
                            style: LedgerText.caption.copyWith(
                              color: context.ledger.inkMute,
                            ),
                          ),
                          const SizedBox(height: Gap.xl),

                          if (state.error case final FeedbackMessage error) ...[
                            BannerMessage(error),
                            const SizedBox(height: Gap.lg),
                          ],

                          switch (state.step) {
                            ImportStep.pickFiles => StepPickFiles(
                              state: state,
                              onPick: () =>
                                  bloc.add(const ImportFilesPickRequested()),
                              onRemove: (fileName) =>
                                  bloc.add(ImportFileRemoved(fileName)),
                            ),
                            ImportStep.assignAccounts => StepAssignAccounts(
                              state: state,
                              onAssign: (fileName, accountId) => bloc.add(
                                ImportFileAccountAssigned(
                                  fileName: fileName,
                                  accountId: accountId,
                                ),
                              ),
                              onImportAnyway: (fileName) => bloc.add(
                                ImportMismatchResolved(
                                  fileName: fileName,
                                  decision: MismatchDecision.importAnyway,
                                ),
                              ),
                              onSkipFile: (fileName) => bloc.add(
                                ImportMismatchResolved(
                                  fileName: fileName,
                                  decision: MismatchDecision.skipFile,
                                ),
                              ),
                              onCreateAccount: (fileName) =>
                                  onCreateAccount(context, fileName),
                            ),
                            ImportStep.running => StepProgress(state: state),
                            ImportStep.summary => StepSummary(
                              state: state,
                              onExportErrors: (recordId, fileName) =>
                                  ExportDialog.open(
                                    context,
                                    ExportErrorRowsSource(
                                      importFileRecordId: recordId,
                                      fileName: fileName,
                                    ),
                                  ),
                              onGoToReconciliation: () =>
                                  context.read<AppShellBloc>().add(
                                    const AppShellNavigationRequested(
                                      OpenReconciliation(),
                                    ),
                                  ),
                            ),
                          },
                          const SizedBox(height: Gap.xl),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _StepperFooter(state: state),
          ],
        );
      },
    );
  }
}

/// Chân stepper: đúng **một** nút chính bên phải, một nút phụ bên trái.
///
/// Lý do khoá nút chính luôn hiện thành chữ ngay cạnh nó. Một nút xám không giải
/// thích được vì sao nó xám, và ở bước 2 lý do luôn cụ thể — còn n file chưa có
/// tài khoản, hoặc còn n cảnh báo lệch số chưa xử lý.
class _StepperFooter extends StatelessWidget {
  const _StepperFooter({required this.state});

  final ImportState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final bloc = context.read<ImportBloc>();
    final blockedReason = _blockedReasonOf(state);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.screen,
        vertical: Gap.md,
      ),
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          if (state.step.canGoBack)
            OutlinedButton(
              onPressed: () => bloc.add(const ImportStepReverted()),
              child: const Text('Back'),
            ),
          if (state.isRunning)
            DestructiveButton(
              label: state.isCancelling ? 'Cancelling…' : 'Cancel',
              onPressed: state.isCancelling
                  ? null
                  : () => bloc.add(const ImportRunCancelled()),
            ),
          const Spacer(),
          if (blockedReason != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: Gap.md),
                child: Text(
                  blockedReason,
                  textAlign: TextAlign.right,
                  style: LedgerText.caption.copyWith(color: colors.lemonInk),
                ),
              ),
            ),
          switch (state.step) {
            ImportStep.pickFiles => FilledButton(
              onPressed: state.canAssignAccounts
                  ? () => bloc.add(const ImportStepAdvanced())
                  : null,
              child: const Text('Assign accounts'),
            ),
            ImportStep.assignAccounts => FilledButton(
              onPressed: state.canRun
                  ? () => bloc.add(const ImportRunRequested())
                  : null,
              child: const Text('Start import'),
            ),
            ImportStep.running => const SizedBox.shrink(),
            ImportStep.summary => FilledButton(
              onPressed: () => bloc.add(const ImportReset()),
              child: const Text('Import more files'),
            ),
          },
        ],
      ),
    );
  }

  static String? _blockedReasonOf(ImportState state) => switch (state.step) {
    ImportStep.pickFiles when !state.canAssignAccounts =>
      'No readable file yet.',
    ImportStep.assignAccounts when state.unassignedCount > 0 =>
      '${state.unassignedCount} files still need a destination account.',
    ImportStep.assignAccounts when state.unresolvedMismatchCount > 0 =>
      '${state.unresolvedMismatchCount} account-number warnings are still '
          'unresolved.',
    _ => null,
  };
}
