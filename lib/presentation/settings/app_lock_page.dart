import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app/theme.dart';
import '../shared/failures/feedback_message.dart';
import '../shared/widgets/banner_message.dart';
import 'bloc/app_lock_bloc.dart';
import 'bloc/app_lock_event.dart';
import 'bloc/app_lock_state.dart';
import 'widgets/forgot_pin_dialog.dart';

/// Màn khoá, chặn toàn bộ ứng dụng khi App Lock đang bật (UC-12).
///
/// Đứng **trước** App Shell chứ không phải là một route bên trong nó: nếu nó chỉ
/// là một màn hình được đẩy lên trên, thì cây widget bên dưới đã dựng xong và dữ
/// liệu đã được đọc lên trước khi ai đó chứng minh được mình có quyền.
///
/// Nút sinh trắc học chỉ hiện khi nền tảng có và người dùng đã bật. Ô PIN luôn
/// có mặt, kể cả khi sinh trắc học khả dụng — cảm biến từ chối là chuyện thường,
/// và khi đó phải còn một đường vào.
class AppLockPage extends StatefulWidget {
  const AppLockPage({super.key});

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> {
  final TextEditingController _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_pin.text.isEmpty) return;
    context.read<AppLockBloc>().add(AppLockPinSubmitted(_pin.text));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: BlocConsumer<AppLockBloc, AppLockState>(
        listenWhen: (previous, current) =>
            previous.pinError != current.pinError,
        listener: (context, state) {
          if (state.pinError != null) _pin.clear();
        },
        builder: (context, state) {
          final bloc = context.read<AppLockBloc>();
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gap.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'LedgerTracer',
                      style: LedgerText.displayLg.copyWith(color: colors.ink),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Enter your PIN to open the app',
                      style: LedgerText.bodyLg.copyWith(
                        color: colors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),

                    TextField(
                      controller: _pin,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      enabled: !state.isVerifying,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: LedgerText.bodyMd.copyWith(
                        color: colors.ink,
                        letterSpacing: 6,
                      ),
                      decoration: const InputDecoration(
                        hintText: '••••••',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submit(context),
                    ),
                    const SizedBox(height: Gap.md),

                    if (state.pinError case final String error) ...<Widget>[
                      BannerMessage(FeedbackMessage.danger(error)),
                      const SizedBox(height: Gap.md),
                    ],
                    if (state.error case final FeedbackMessage error) ...[
                      BannerMessage(error),
                      const SizedBox(height: Gap.md),
                    ],

                    FilledButton(
                      onPressed: state.isVerifying
                          ? null
                          : () => _submit(context),
                      child: Text(state.isVerifying ? 'Checking…' : 'Unlock'),
                    ),
                    if (state.canUseBiometric) ...<Widget>[
                      const SizedBox(height: Gap.md),
                      OutlinedButton.icon(
                        onPressed: state.isVerifying
                            ? null
                            : () => bloc.add(const AppLockBiometricRequested()),
                        icon: const Icon(Icons.fingerprint, size: 18),
                        label: const Text('Unlock with biometrics'),
                      ),
                    ],
                    const SizedBox(height: Gap.lg),

                    TextButton(
                      onPressed: () => ForgotPinDialog.show(context),
                      child: const Text('Forgot PIN?'),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      state.biometricAvailable
                          ? 'Biometrics is only a shortcut; the PIN stays the '
                                'main way in.'
                          : 'This build offers PIN only. Biometric unlock is '
                                'available on Android.',
                      textAlign: TextAlign.center,
                      style: LedgerText.caption.copyWith(color: colors.inkMute),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
