import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../shared/domain_failures.dart';
import '../contracts/app_data_store.dart';
import 'backup_restore_dto.dart';

/// Sao lưu toàn bộ dữ liệu ra một file đã mã hoá, và khôi phục lại từ file đó
/// (UC-13).
///
/// File sao lưu **phải** được mã hoá, khác hẳn file xuất báo cáo ở UC-11: nó
/// mang toàn bộ dữ liệu ra khỏi ứng dụng và chỉ để chính ứng dụng đọc lại. Mật
/// khẩu của nó độc lập hoàn toàn với mã PIN khoá ứng dụng và không được giữ lại
/// bản sao nào — lối thoát khi quên PIN là reset rồi khôi phục từ đây, nên nếu
/// file sao lưu mã hoá bằng chính PIN đã quên thì hai use case triệt tiêu nhau
/// (UC-12).
///
/// Khôi phục đi **hai bước**: [prepareRestore] giải mã và kiểm tra mà không đụng
/// tới dữ liệu hiện có, [commitRestore] mới ghi đè. Đó chính là trình tự UC-13
/// mô tả — kiểm tra xong rồi mới cảnh báo và chờ xác nhận.
final class BackupRestoreUseCase {
  BackupRestoreUseCase({
    required this._store,
    required this._codec,
    required this._writer,
    required this._now,
  });

  final AppDataStore _store;
  final BackupCodec _codec;
  final BackupWriter _writer;
  final DateTime Function() _now;

  /// Chụp toàn bộ dữ liệu, mã hoá bằng khoá dẫn xuất từ mật khẩu người dùng đặt,
  /// rồi để người dùng tự lưu file ở nơi họ chọn (UC-13 bước 1).
  ///
  /// Mất mật khẩu là mất luôn file đó, không có đường khôi phục — cảnh báo ấy
  /// phải hiện ngay tại màn hình đặt mật khẩu, trước khi gọi tới đây.
  Future<Result<BackupResult>> backup(BackupRequest request) =>
      Result.guardAsync(() async {
        final plain = await _store.snapshot();
        final cipher = await _codec.encrypt(plain, request.password);
        final location = await _writer.write(
          cipher,
          suggestedName: _suggestedName(),
        );
        return BackupResult(location: location);
      }, onError: failureFromError);

  /// Giải mã và kiểm tra một file sao lưu, **không** ghi gì (UC-13 bước 3).
  ///
  /// Sai mật khẩu hay file hỏng đều dừng lại ở đây, khi dữ liệu hiện có còn
  /// nguyên vẹn. Kết quả là một [RestorePlan] để giao diện dựng hộp thoại cảnh
  /// báo rồi mới gọi [commitRestore].
  Future<Result<RestorePlan>> prepareRestore(RestoreRequest request) =>
      Result.guardAsync(() async {
        final plain = await _codec.decrypt(request.bytes, request.password);
        final manifest = await _store.inspect(plain);
        return RestorePlan(manifest: manifest, plain: plain);
      }, onError: _prepareFailure);

  /// Ghi đè toàn bộ dữ liệu hiện có bằng bản sao lưu đã kiểm (UC-13 bước 4).
  ///
  /// Chỉ nhận [RestorePlan] chứ không nhận [RestoreRequest]: kiểu của tham số là
  /// thứ đảm bảo không có đường nào ghi đè dữ liệu mà chưa đi qua bước kiểm.
  Future<Result<void>> commitRestore(RestorePlan plan) => Result.guardAsync(
    () => _store.replaceAll(plan.plain),
    onError: failureFromError,
  );

  /// Sai mật khẩu là chuyện bảo mật, file hỏng là chuyện dữ liệu không hợp lệ —
  /// hai kết cục khác nhau vì người dùng phải làm hai việc khác nhau: gõ lại mật
  /// khẩu, hay đi tìm bản sao lưu khác.
  ///
  /// Mọi lỗi **lạ** ở bước này cũng được quy về "file hỏng", và đó là chủ đích:
  /// việc duy nhất đang diễn ra là đọc một khối bytes do người dùng đưa vào, nên
  /// bất kỳ thứ gì nổ ra ở đây — `FormatException` của bộ phân tích, chỉ số vượt
  /// biên, thiếu trường — đều nói cùng một điều. Để nó rơi vào nhánh "lỗi không
  /// mong đợi" thì UC-13 mất đúng thứ nó đòi: một thông báo rõ ràng rằng file
  /// sao lưu không dùng được.
  Failure _prepareFailure(Object error, StackTrace stackTrace) =>
      switch (error) {
        BackupPasswordException() => SecurityFailure(
          error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
        Failure() => error,
        _ => ValidationFailure(
          error is CorruptBackupException
              ? error.message
              : const CorruptBackupException().message,
          cause: error,
          stackTrace: stackTrace,
        ),
      };

  String _suggestedName() {
    final timestamp = _now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    return 'ledgertracer-backup-$timestamp.ltb';
  }
}
