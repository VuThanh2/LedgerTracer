import '../../../core/result/failure.dart';
import '../../../core/result/result.dart';
import '../../shared/domain_failures.dart';
import 'backup_restore_dto.dart';

/// Sao lưu và khôi phục toàn bộ dữ liệu (UC-13).
///
/// Sao lưu: chụp toàn bộ dữ liệu → mã hoá bằng khoá dẫn xuất từ mật khẩu người
/// dùng đặt → ghi ra file. Khôi phục: **giải mã trước** (sai mật khẩu hay file
/// hỏng thì báo lỗi và **không đụng tới dữ liệu hiện có**), rồi ghi đè toàn bộ.
///
/// Thứ tự "giải mã trước, ghi đè sau" chính là thứ giữ đúng cam kết của UC-13: một
/// file sai không bao giờ làm hỏng dữ liệu đang có.
final class BackupRestoreUseCase {
  BackupRestoreUseCase({
    required this._store,
    required this._codec,
    required this._writer,
    required this._now,
  });

  final BackupStore _store;
  final BackupCodec _codec;
  final BackupWriter _writer;
  final DateTime Function() _now;

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

  /// Khôi phục bằng ghi đè toàn bộ. Sai mật khẩu hoặc file hỏng trả về
  /// [SecurityFailure] và không thay đổi gì.
  Future<Result<void>> restore(RestoreRequest request) =>
      Result.guardAsync(() async {
        final plain = await _codec.decrypt(request.bytes, request.password);
        // Chỉ khi giải mã và kiểm toàn vẹn xong mới đụng tới dữ liệu hiện có.
        await _store.replaceAll(plain);
      }, onError: _restoreFailure);

  /// Sai mật khẩu/hỏng file là chuyện bảo mật, không phải một lỗi bất ngờ; phần
  /// còn lại đi theo phép ánh xạ chung.
  Failure _restoreFailure(Object error, StackTrace stackTrace) =>
      error is BackupPasswordException
      ? SecurityFailure(error.message, cause: error, stackTrace: stackTrace)
      : failureFromError(error, stackTrace);

  String _suggestedName() {
    final timestamp = _now()
        .toIso8601String()
        .split('.')
        .first
        .replaceAll(':', '-');
    return 'ledgertracer-backup-$timestamp.ltb';
  }
}
