import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/dependencies.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import '../shared/widgets/section_card.dart';
import 'bloc/settings_bloc.dart';
import 'bloc/settings_event.dart';
import 'bloc/settings_state.dart';
import 'widgets/security_section.dart';

/// Màn Cài đặt: ba nhóm — Tài khoản ngân hàng, Bảo mật, Dữ liệu (UC-12).
///
/// Màn Developer Diagnostics nằm sau một mục ẩn ở cuối trang, mở ra sau nhiều
/// lần chạm. Nó là công cụ đo cho phần thực nghiệm chứ không phải tính năng của
/// sản phẩm; để nó lộ ra như một mục bình thường là mời người dùng chạy một
/// workload nặng mà họ không có lý do gì để chạy.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const SettingsPage());

  @override
  Widget build(BuildContext context) {
    final dependencies = DependencyScope.of(context);
    return BlocProvider<SettingsBloc>(
      create: (_) =>
          SettingsBloc(appLock: dependencies.appLock)
            ..add(const SettingsStarted()),
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listenWhen: (previous, current) => previous.notice != current.notice,
        listener: (context, state) {
          if (state.notice case final notice?) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(notice.message.text)));
          }
        },
        builder: (context, state) {
          if (state.status.isInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(Gap.screen),
            children: <Widget>[
              if (state.loadError case final FeedbackMessage error) ...<Widget>[
                BannerMessage(error),
                const SizedBox(height: Gap.lg),
              ],

              const SectionLabel('Bank accounts'),
              Container(
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: Corner.radiusMd,
                  border: Border.all(color: colors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: SettingRow(
                  title: 'Manage accounts',
                  subtitle:
                      'Account numbers are learned from imported files; fix '
                      'them here when one was learned wrong.',
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuteNav),
                  onTap: () =>
                      Navigator.of(context).pushNamed(LedgerRoutes.accounts),
                ),
              ),
              const SizedBox(height: Gap.xl),

              const SectionLabel('Security'),
              SecuritySection(state: state),
              const SizedBox(height: Gap.xl),

              const SectionLabel('Data'),
              Container(
                decoration: BoxDecoration(
                  color: colors.canvas,
                  borderRadius: Corner.radiusMd,
                  border: Border.all(color: colors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: SettingRow(
                  title: 'Backup & restore',
                  subtitle:
                      'Everything stays on this device. A backup file carries '
                      'its own password.',
                  trailing: Icon(Icons.chevron_right, color: colors.inkMuteNav),
                  onTap: () =>
                      Navigator.of(context).pushNamed(LedgerRoutes.backup),
                ),
              ),
              const SizedBox(height: Gap.xxl),

              _HiddenDiagnosticsEntry(state: state),
              const SizedBox(height: Gap.xxl),
            ],
          );
        },
      ),
    );
  }
}

/// Mục ẩn dẫn tới màn Developer Diagnostics.
///
/// Trước khi mở khoá, nó chỉ là dòng chữ phiên bản — chạm nhiều lần mới hiện
/// liên kết. Một khi đã mở, nó ở lại: bắt người dùng chạm lại bảy lần mỗi lần
/// muốn đo là trò đùa với chính mình.
class _HiddenDiagnosticsEntry extends StatelessWidget {
  const _HiddenDiagnosticsEntry({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    if (state.diagnosticsUnlocked) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () =>
              Navigator.of(context).pushNamed(LedgerRoutes.diagnostics),
          child: const Text('Developer diagnostics →'),
        ),
      );
    }

    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            context.read<SettingsBloc>().add(const SettingsHiddenEntryTapped()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gap.md),
          child: Text(
            'LedgerTracer · offline · data never leaves this device',
            style: LedgerText.micro.copyWith(color: colors.inkMute),
          ),
        ),
      ),
    );
  }
}
