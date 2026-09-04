import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import 'pin_form_dialog.dart';

/// Nhóm Bảo mật của màn Cài đặt (UC-12).
///
/// Công tắc sinh trắc học chỉ hiện khi nền tảng có nó **và** chỉ bật được khi đã
/// có mã PIN. Sinh trắc học ở đây là lối vào nhanh, không phải lớp bảo vệ độc
/// lập: thiếu mã PIN thì không còn đường nào vào ứng dụng khi cảm biến từ chối,
/// và người dùng sẽ bị khoá khỏi chính dữ liệu của mình.
class SecuritySection extends StatelessWidget {
  const SecuritySection({required this.state, super.key});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    final bloc = context.read<SettingsBloc>();

    return Container(
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: Corner.radiusMd,
        border: Border.all(color: colors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          SettingRow(
            title: 'App lock',
            subtitle: 'Ask for a PIN before the app opens',
            trailing: Switch(
              value: state.appLockEnabled,
              onChanged: state.isSubmitting
                  ? null
                  : (value) => PinFormDialog.show(
                      context,
                      value ? PinFormMode.enable : PinFormMode.disable,
                    ),
            ),
          ),
          if (state.biometricAvailable)
            SettingRow(
              title: 'Unlock with biometrics',
              subtitle: state.appLockEnabled
                  ? 'Use a fingerprint or your face instead of typing the PIN'
                  : 'Requires a PIN first',
              trailing: Switch(
                value: state.biometricEnabled,
                onChanged: state.appLockEnabled && !state.isSubmitting
                    ? (value) => bloc.add(SettingsBiometricToggled(value))
                    : null,
              ),
            ),
          SettingRow(
            title: 'Change PIN',
            subtitle: 'The current PIN is required first',
            onTap: state.appLockEnabled
                ? () => PinFormDialog.show(context, PinFormMode.change)
                : null,
            trailing: Icon(
              Icons.chevron_right,
              color: state.appLockEnabled
                  ? colors.inkMuteNav
                  : colors.hairlineStructure,
            ),
          ),
          if (!state.biometricAvailable)
            const Padding(
              padding: EdgeInsets.all(Gap.lg),
              child: BannerMessage(
                FeedbackMessage.info(
                  'This platform has no biometric unlock, so the app uses a PIN '
                  'only.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Một dòng cài đặt: tiêu đề, dòng giải thích, và một điều khiển ở mép phải.
///
/// Công khai vì màn Cài đặt dùng lại nó cho nhóm Tài khoản và nhóm Dữ liệu —
/// ba nhóm phải trông như nhau, và cách chắc chắn nhất là chúng dùng chung một
/// widget.
class SettingRow extends StatelessWidget {
  const SettingRow({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.md,
        ),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.hairline)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: LedgerText.bodyMd.copyWith(color: colors.ink),
                  ),
                  if (subtitle case final String text) ...<Widget>[
                    const SizedBox(height: Gap.xxs),
                    Text(
                      text,
                      style: LedgerText.caption.copyWith(color: colors.inkMute),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Gap.md),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
