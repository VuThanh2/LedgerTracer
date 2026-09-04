import '../../../application/settings/contracts/app_data_store.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/number_formatter.dart';

/// Bản sao lưu sắp ghi đè chứa gì — nội dung cho hộp thoại cảnh báo (UC-13
/// bước 3–4).
final class BackupManifestViewModel {
  const BackupManifestViewModel({
    required this.createdAtText,
    required this.accountText,
    required this.transactionText,
  });

  factory BackupManifestViewModel.of(BackupManifest manifest) =>
      BackupManifestViewModel(
        createdAtText: DateFormatter.dayTime(manifest.createdAt),
        accountText: NumberFormatter.count(manifest.accountCount),
        transactionText: NumberFormatter.count(manifest.transactionCount),
      );

  final String createdAtText;
  final String accountText;
  final String transactionText;
}
