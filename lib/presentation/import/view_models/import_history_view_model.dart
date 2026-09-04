import '../../../domain/entities/import_file_record.dart';
import '../../../domain/entities/import_session.dart';
import '../../../domain/value_objects/import_file_status.dart';
import '../../../domain/value_objects/import_session_status.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/number_formatter.dart';
import '../../shell/view_models/navigation_intent.dart';
import '../../transactions/view_models/transaction_context.dart';

/// Một bản ghi file trong lịch sử nhập (UC-03).
///
/// Đơn vị của lịch sử — và của việc hoàn tác — là **file**, không phải cả lượt:
/// một lượt nhiều file có thể gán nhiều tài khoản khác nhau, nên hoàn tác cả
/// lượt chỉ là hoàn tác lần lượt từng file theo cùng một quy tắc.
final class ImportFileRecordViewModel {
  const ImportFileRecordViewModel({
    required this.recordId,
    required this.accountId,
    required this.fileName,
    required this.accountName,
    required this.statusLabel,
    required this.importedText,
    required this.duplicateSkippedText,
    required this.errorRowText,
    required this.errorRowCount,
    required this.canRevert,
    required this.isReverted,
    required this.revertedAtText,
  });

  factory ImportFileRecordViewModel.of(
    ImportFileRecord record, {
    required String accountName,
  }) => ImportFileRecordViewModel(
    recordId: record.recordId!,
    accountId: record.accountId,
    fileName: record.fileName,
    accountName: accountName,
    statusLabel: _labelOf(record.status),
    importedText: NumberFormatter.count(record.importedCount),
    duplicateSkippedText: NumberFormatter.count(record.duplicateSkippedCount),
    errorRowText: NumberFormatter.count(record.errorRowCount),
    errorRowCount: record.errorRowCount,
    canRevert: record.canRevert,
    isReverted: record.isReverted,
    revertedAtText: record.revertedAt == null
        ? ''
        : DateFormatter.dayTime(record.revertedAt!),
  );

  final int recordId;

  /// Tài khoản đích — đi kèm khi mở danh sách giao dịch của file này, để lọc
  /// theo lượt nhập thu hẹp được trước ở cơ sở dữ liệu (UC-03 → UC-04).
  final int accountId;

  final String fileName;
  final String accountName;
  final String statusLabel;
  final String importedText;
  final String duplicateSkippedText;
  final String errorRowText;
  final int errorRowCount;

  /// Hoàn tác được: chưa hoàn tác và đã từng ghi được dòng nào.
  final bool canRevert;

  /// Đã hoàn tác. Bản ghi **vẫn ở lại** lịch sử — dấu hoàn tác không phải
  /// tombstone, và danh sách dòng lỗi của nó vẫn xuất lại được (UC-03, UC-11).
  final bool isReverted;

  final String revertedAtText;

  bool get hasErrorRows => errorRowCount > 0;

  /// Yêu cầu điều hướng cho hành động "xem giao dịch của file này"
  /// (UC-03 → UC-04).
  ///
  /// Phép dựng nằm ở đây chứ không ở giao diện, cùng lý do với khoan xuống ở màn
  /// hình thống kê: ngữ cảnh có ba mảnh — định danh bản ghi, tên file để dựng
  /// chip, và tài khoản để thu hẹp trước ở cơ sở dữ liệu — và chỗ nào ghép tay
  /// cũng có thể quên mảnh thứ ba, thứ không làm sai kết quả nhưng biến một truy
  /// vấn có chỉ mục thành một lượt quét cả bảng.
  OpenTransactions toNavigationIntent() => OpenTransactions(
    context: TransactionContext.fromImport(
      recordId: recordId,
      fileName: fileName,
      accountId: accountId,
    ),
  );

  static String _labelOf(ImportFileStatus status) => switch (status) {
    ImportFileStatus.completed => 'Hoàn tất',
    ImportFileStatus.partiallyFailed => 'Có dòng lỗi',
    ImportFileStatus.cancelled => 'Đã dừng',
    ImportFileStatus.skipped => 'Đã bỏ qua',
  };
}

/// Một lượt nhập trong lịch sử (UC-03 bước 2).
final class ImportSessionViewModel {
  const ImportSessionViewModel({
    required this.sessionId,
    required this.startedAtText,
    required this.statusLabel,
    required this.statusNote,
    required this.importedText,
    required this.duplicateSkippedText,
    required this.errorRowText,
    required this.files,
    required this.canRevert,
    required this.isFullyReverted,
  });

  factory ImportSessionViewModel.of(
    ImportSession session, {
    required Map<int, String> accountNames,
  }) => ImportSessionViewModel(
    sessionId: session.sessionId!,
    startedAtText: DateFormatter.dayTime(session.startedAt),
    statusLabel: _labelOf(session.status),
    statusNote: _noteOf(session.status),
    importedText: NumberFormatter.count(session.importedCount),
    duplicateSkippedText: NumberFormatter.count(session.duplicateSkippedCount),
    errorRowText: NumberFormatter.count(session.errorRowCount),
    files: <ImportFileRecordViewModel>[
      for (final record in session.fileRecords)
        ImportFileRecordViewModel.of(
          record,
          accountName: accountNames[record.accountId] ?? '',
        ),
    ],
    canRevert: session.fileRecords.any((record) => record.canRevert),
    isFullyReverted: session.isFullyReverted,
  );

  final int sessionId;
  final String startedAtText;
  final String statusLabel;

  /// Câu giải thích đi kèm trạng thái, rỗng với lượt bình thường.
  ///
  /// Có mặt vì *đã huỷ* và *bị gián đoạn* cần nói với người dùng hai điều khác
  /// nhau: huỷ là phán quyết của chính họ và họ biết mình dừng ở đâu, còn gián
  /// đoạn thì họ không biết gì cả — lần trước ứng dụng biến mất mà không kịp nói
  /// gì, nên màn hình phải nói thay.
  final String statusNote;

  final String importedText;
  final String duplicateSkippedText;
  final String errorRowText;
  final List<ImportFileRecordViewModel> files;
  final bool canRevert;
  final bool isFullyReverted;

  static String _labelOf(ImportSessionStatus status) => switch (status) {
    ImportSessionStatus.inProgress => 'Đang chạy',
    ImportSessionStatus.completed => 'Hoàn tất',
    ImportSessionStatus.cancelled => 'Đã dừng',
    ImportSessionStatus.interrupted => 'Bị gián đoạn',
  };

  static String _noteOf(ImportSessionStatus status) => switch (status) {
    ImportSessionStatus.cancelled =>
      'Bạn đã dừng lượt này. Phần đã ghi được giữ lại; nhập lại đúng những file '
          'đó sẽ chỉ bổ sung phần còn thiếu.',
    ImportSessionStatus.interrupted =>
      'Ứng dụng bị đóng giữa chừng nên lượt này không kịp hoàn tất. Phần đã ghi '
          'được giữ lại; nhập lại đúng những file đó sẽ chỉ bổ sung phần còn '
          'thiếu.',
    ImportSessionStatus.inProgress || ImportSessionStatus.completed => '',
  };
}

/// Những gì một lần hoàn tác sẽ động tới, đã thành chữ (UC-03 bước 4).
final class RevertImpactViewModel {
  const RevertImpactViewModel({
    required this.deletedTransactionText,
    required this.cancelledPairText,
    required this.cancelledPairCount,
    required this.hasManualEdits,
  });

  final String deletedTransactionText;
  final String cancelledPairText;
  final int cancelledPairCount;

  /// Lượt này có giao dịch đã bị sửa tay. Hoàn tác xoá luôn phần đã sửa, và đó
  /// là thứ duy nhất trong luồng này **không** lấy lại được bằng cách nhập lại
  /// file gốc — nên nó phải được cảnh báo riêng (UC-03).
  final bool hasManualEdits;

  bool get cancelsPairs => cancelledPairCount > 0;
}
