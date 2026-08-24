import '../../core/concurrency/cancellation_signal.dart';
import '../../core/result/failure.dart';
import '../../domain/errors/account_errors.dart';
import '../../domain/errors/domain_error.dart';
import '../../domain/errors/import_errors.dart';
import '../../domain/errors/reconciliation_errors.dart';
import '../../domain/errors/settings_errors.dart';
import '../../domain/errors/transaction_errors.dart';

/// Nơi **duy nhất** đổi một `DomainError` (Domain ném ra) thành một [Failure]
/// (thứ Presentation xử lý được).
///
/// Domain báo vi phạm bằng cách ném và cố ý không biết gì về truyền tải; `core`
/// cố ý không biết gì về tài khoản hay giao dịch. Tầng Application là chỗ hai thế
/// giới đó gặp nhau, nên phép dịch nằm gọn ở đây thay vì rải trong từng use case
/// rồi lệch nhau. Mọi use case truyền hàm này vào [Result.guardAsync] qua
/// `onError`, và những gì không phải vi phạm đã lường trước sẽ rơi về
/// [UnexpectedFailure] do chính `Result` lo.
///
/// Phép ánh xạ phân loại theo **cách Presentation phải phản ứng**, không theo
/// aggregate sinh ra lỗi: dữ liệu vào sai thì sửa ô nhập ([ValidationFailure]),
/// bản ghi biến mất thì làm mới màn hình ([NotFoundFailure]), sai PIN thì báo
/// bảo mật ([SecurityFailure]).
Failure failureFromError(Object error, StackTrace stackTrace) => switch (error) {
  // Người dùng chủ động dừng — một kết cục, không phải một lỗi (UC-02, UC-08).
  CancellationException() => const CancelledFailure(),

  // Bản ghi mà thao tác nhắm tới không còn tồn tại.
  TransactionNotFoundError() ||
  AccountNotFoundError() ||
  ImportSessionNotFoundError() ||
  ImportFileRecordNotFoundError() ||
  PairNotFoundError() ||
  RejectedMatchNotFoundError() => NotFoundFailure(_messageOf(error), cause: error, stackTrace: stackTrace),

  // Sai PIN hiện tại: chạm tới lớp bảo vệ, nên tách khỏi validation thường
  // (UC-12).
  IncorrectPinError() => SecurityFailure(_messageOf(error), cause: error, stackTrace: stackTrace),

  // Sinh trắc học chỉ có trên native; giao diện đáng lẽ đã ẩn tuỳ chọn, đây là
  // lưới an toàn (UC-12).
  BiometricUnavailableError() => UnsupportedOnPlatformFailure(_messageOf(error), cause: error, stackTrace: stackTrace),

  // Còn lại đều là dữ liệu vào phạm luật trước khi có gì bị đụng tới: value
  // object từ chối được dựng, hoặc một chuyển trạng thái không hợp lệ.
  DomainError() => ValidationFailure(_messageOf(error), cause: error, stackTrace: stackTrace),

  // Không phải vi phạm nghiệp vụ nào đã lường trước.
  _ => UnexpectedFailure(error.toString(), cause: error, stackTrace: stackTrace),
};

String _messageOf(Object error) =>
    error is DomainError ? error.message : error.toString();
