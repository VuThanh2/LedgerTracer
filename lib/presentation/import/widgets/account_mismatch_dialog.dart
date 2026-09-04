import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../application/import/prepare_import/prepare_import_dto.dart';
import '../../shared/failures/feedback_message.dart';
import '../../shared/widgets/banner_message.dart';
import '../../shared/widgets/confirm_dialog.dart';
import '../view_models/import_file_entry.dart';

/// Cảnh báo lệch số tài khoản, chèn **ngay dưới dòng file** đang có vấn đề.
///
/// Không đặt ở đầu màn hình: khi có ba file thì một banner ở đầu không nói được
/// file nào lệch, và người dùng phải tự dò. Vị trí ở đây chính là một nửa thông
/// tin.
///
/// Ba lựa chọn phản ánh đúng ba việc người dùng có thể làm, không hơn: gán lại
/// tài khoản (bằng ô chọn ngay trên dòng), vẫn nhập, hoặc bỏ file này.
class AccountMismatchNotice extends StatelessWidget {
  const AccountMismatchNotice({
    required this.check,
    required this.onImportAnyway,
    required this.onSkipFile,
    required this.onCreateAccount,
    super.key,
  });

  final AccountAssignmentCheck check;
  final VoidCallback onImportAnyway;
  final VoidCallback onSkipFile;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) => BannerMessage(
    FeedbackMessage.warning(
      'The number in this file does not match the number recorded for the '
      'selected account.',
      detail:
          'Trong file: ${check.embeddedAccountNumber ?? '—'} · '
          'Recorded: ${check.recordedAccountNumber ?? '—'}',
    ),
    action: Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: <Widget>[
        OutlinedButton(
          onPressed: onImportAnyway,
          child: const Text('Import anyway'),
        ),
        OutlinedButton(
          onPressed: onCreateAccount,
          child: const Text('Create new account'),
        ),
        DestructiveButton(label: 'Skip this file', onPressed: onSkipFile),
      ],
    ),
  );
}

/// Tiện ích đọc trạng thái lệch của một dòng file.
extension MismatchOf on ImportFileEntry {
  AccountAssignmentCheck? get mismatch => hasUnresolvedMismatch ? check : null;
}
