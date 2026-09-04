import 'domain_error.dart';

/// Vi phạm của aggregate ImportSession (UC-02, UC-03).
sealed class ImportError extends DomainError {
  const ImportError(super.message);
}

final class ImportSessionNotFoundError extends ImportError {
  const ImportSessionNotFoundError(this.sessionId)
    : super('No import session with id $sessionId.');

  final int sessionId;
}

final class ImportFileRecordNotFoundError extends ImportError {
  const ImportFileRecordNotFoundError(this.recordId)
    : super('No import file record with id $recordId.');

  final int recordId;
}

/// Hoàn tác lần thứ hai sẽ xoá nhầm giao dịch của một lượt nhập **sau** đó trên
/// cùng tài khoản (UC-03).
final class ImportAlreadyRevertedError extends ImportError {
  const ImportAlreadyRevertedError(this.recordId)
    : super('Import file record $recordId has already been reverted.');

  final int recordId;
}

/// File bị người dùng bỏ qua ở cảnh báo số tài khoản (UC-02 bước 4) không ghi gì
/// cả nên không có gì để hoàn tác.
final class NothingToRevertError extends ImportError {
  const NothingToRevertError(this.recordId)
    : super('Import file record $recordId wrote no transaction.');

  final int recordId;
}

/// File được chọn không thuộc bốn định dạng hỗ trợ (PDF nằm ngoài phạm vi theo
/// thiết kế).
final class UnsupportedStatementFormatError extends ImportError {
  const UnsupportedStatementFormatError(this.fileName)
    : super('Cannot detect a supported statement format in "$fileName".');

  final String fileName;
}
