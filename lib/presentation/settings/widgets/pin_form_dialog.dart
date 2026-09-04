import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/theme.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';

/// Ba việc mà cùng một form phục vụ.
enum PinFormMode {
  /// Bật khoá ứng dụng: đặt mã PIN lần đầu.
  enable,

  /// Tắt khoá ứng dụng — vẫn phải nhập mã hiện tại.
  disable,

  /// Đổi mã PIN.
  change,
}

/// Form nhập mã PIN (UC-12).
///
/// Tắt khoá cũng đòi mã hiện tại, y như đổi mã. Nếu không, bất kỳ ai cầm được
/// máy trong lúc màn hình đang mở đều tắt được lớp bảo vệ mà không cần biết gì —
/// và lớp bảo vệ ấy là thứ duy nhất đứng giữa họ với toàn bộ dữ liệu, vì ứng
/// dụng này không có tài khoản người dùng và không có máy chủ.
///
/// Dialog ở lại cho tới khi BLoC báo xong: sai mã là đường đi thường gặp, và nó
/// phải hiện ngay trong form chứ không phải sau khi form đã đóng.
class PinFormDialog extends StatefulWidget {
  const PinFormDialog({required this.mode, super.key});

  final PinFormMode mode;

  static Future<void> show(BuildContext context, PinFormMode mode) {
    final bloc = context.read<SettingsBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: PinFormDialog(mode: mode),
      ),
    );
  }

  static const int minLength = 4;
  static const int maxLength = 6;

  @override
  State<PinFormDialog> createState() => _PinFormDialogState();
}

class _PinFormDialogState extends State<PinFormDialog> {
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  /// Đã gửi đi một lần: dùng để nhận ra lúc BLoC xử lý xong.
  bool _submitted = false;

  bool get _needsCurrent => widget.mode != PinFormMode.enable;
  bool get _needsNew => widget.mode != PinFormMode.disable;

  bool get _isValid {
    final currentOk =
        !_needsCurrent || _current.text.length >= PinFormDialog.minLength;
    if (!_needsNew) return currentOk;
    return currentOk &&
        _next.text.length >= PinFormDialog.minLength &&
        _next.text == _confirm.text;
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (!_isValid) return;
    setState(() => _submitted = true);
    final bloc = context.read<SettingsBloc>();
    switch (widget.mode) {
      case PinFormMode.enable:
        bloc.add(
          SettingsLockEnabled(pin: _next.text, confirmPin: _confirm.text),
        );
      case PinFormMode.disable:
        bloc.add(SettingsLockDisabled(_current.text));
      case PinFormMode.change:
        bloc.add(
          SettingsPinChanged(
            currentPin: _current.text,
            newPin: _next.text,
            confirmPin: _confirm.text,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return BlocConsumer<SettingsBloc, SettingsState>(
      listenWhen: (previous, current) =>
          previous.isSubmitting && !current.isSubmitting,
      listener: (context, state) {
        if (state.pinError == null) {
          Navigator.of(context).maybePop();
        } else {
          setState(() => _submitted = false);
        }
      },
      builder: (context, state) => AlertDialog(
        title: Text(switch (widget.mode) {
          PinFormMode.enable => 'Set a PIN',
          PinFormMode.disable => 'Turn off app lock',
          PinFormMode.change => 'Change PIN',
        }),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (_needsCurrent) ...<Widget>[
                _PinField(
                  label: 'Current PIN',
                  controller: _current,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: Gap.md),
              ],
              if (_needsNew) ...<Widget>[
                _PinField(
                  label: 'New PIN',
                  controller: _next,
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: Gap.md),
                _PinField(
                  label: 'Repeat new PIN',
                  controller: _confirm,
                  onChanged: () => setState(() {}),
                  errorText:
                      _confirm.text.isNotEmpty && _confirm.text != _next.text
                      ? 'The two new PINs do not match.'
                      : null,
                ),
                const SizedBox(height: Gap.md),
              ],
              if (state.pinError case final String error)
                BannerMessage(FeedbackMessage.danger(error))
              else
                const BannerMessage(
                  FeedbackMessage.info(
                    'A PIN is 4 to 6 digits. There is no server, so a forgotten '
                    'PIN can only be cleared by deleting all local data.',
                  ),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          OutlinedButton(
            onPressed: state.isSubmitting
                ? null
                : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isValid && !state.isSubmitting && !_submitted
                ? () => _submit(context)
                : null,
            child: Text(
              state.isSubmitting ? 'Saving…' : 'Save',
              style: LedgerText.buttonMd.copyWith(color: colors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final colors = context.ledger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: LedgerText.microCap.copyWith(color: colors.inkSecondary),
        ),
        const SizedBox(height: Gap.xs),
        TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: PinFormDialog.maxLength,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: LedgerText.bodyMd.copyWith(
            color: colors.ink,
            letterSpacing: 4,
          ),
          decoration: InputDecoration(
            hintText: '••••••',
            counterText: '',
            errorText: errorText,
          ),
          onChanged: (_) => onChanged(),
        ),
      ],
    );
  }
}
