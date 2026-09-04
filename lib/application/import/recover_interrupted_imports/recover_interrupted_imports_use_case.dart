import '../../../core/persistence/unit_of_work.dart';
import '../../../core/result/result.dart';
import '../../../domain/repositories/import_repository.dart';
import '../../shared/domain_failures.dart';
import 'recover_interrupted_imports_dto.dart';

/// Dọn các lượt nhập mà tiến trình đã chết giữa chừng, chạy đúng một lần khi ứng
/// dụng khởi động và **trước** khi lịch sử nhập được đọc lần đầu (UC-03).
///
/// Huỷ chủ động ở UC-02 bước 7 là luồng sạch: người dùng bấm Huỷ, có mã lệnh
/// chạy tại thời điểm dừng, trạng thái cuối được ghi xuống. Gián đoạn bị động
/// thì không có gì chạy cả — tiến trình bị hệ điều hành kết liễu vì chiếm nhiều
/// bộ nhớ trong lúc ở nền, hoặc tab trình duyệt bị đóng. `AppLifecycleState`
/// không được đảm bảo gọi tới, và `beforeunload` trên Web không cho làm việc bất
/// đồng bộ, nên **không có chỗ nào** để ghi trạng thái lúc chết. Cách duy nhất
/// còn lại là nhận ra chuyện đó ở lần sống dậy kế tiếp.
///
/// Suy luận này không cần heartbeat, không cần timestamp và không phải phỏng
/// đoán: chỉ có một tiến trình, một cơ sở dữ liệu, một người dùng
/// (Rule – Single Context Is an Architectural Consequence). Tại thời điểm ứng
/// dụng vừa khởi động, tiến trình duy nhất có thể ghi vào cơ sở dữ liệu là tiến
/// trình vừa sinh ra, và nó chưa mở lượt nhập nào. Vậy mọi lượt còn `InProgress`
/// đều là mồ côi — đúng, không phải nhiều khả năng là đúng.
///
/// **Không** có chức năng chạy tiếp phần dở dang. Muốn thế phải bền hoá vị trí
/// đọc trong file, offset của parser và trạng thái hàng đợi — một tính năng riêng
/// đúng nghĩa. Trong khi đó chống trùng ở UC-02 là phép **đếm**, nên nhập lại
/// nguyên file chỉ bổ sung phần còn thiếu và cho ra đúng kết quả ấy với chi phí
/// gần như bằng không. Đây là giới hạn có chủ đích, ghi vào Limitations.
final class RecoverInterruptedImportsUseCase {
  RecoverInterruptedImportsUseCase({
    required this._imports,
    required this._unitOfWork,
  });

  final ImportRepository _imports;
  final UnitOfWork _unitOfWork;

  Future<Result<ImportRecoveryReport>> execute() => Result.guardAsync(
    () => _unitOfWork.transaction(() async {
      // Xoá trước rồi mới đánh dấu, không phải ngược lại: một lượt chết trước
      // khi kịp mở bản ghi file nào thì không có gì để kể — báo với người dùng
      // "một lượt nhập bị gián đoạn, đã ghi được 0 giao dịch" là tiếng ồn, không
      // phải thông tin. `deleteEmptySessions` đã sẵn có cho luồng xoá tài khoản
      // ở UC-01 và mang đúng nghĩa cần ở đây: lượt nhập biến mất khi không còn
      // bản ghi con nào.
      final discarded = await _imports.deleteEmptySessions();
      final orphans = await _imports.findUnfinishedSessions();
      for (final session in orphans) {
        // Các bản ghi file con không phải sửa gì. Chúng mở ra ở
        // `ImportFileStatus.cancelled` ngay từ đầu và bộ đếm của chúng lớn lên
        // theo từng lô đã commit, nên chúng đã nói đúng sự thật sẵn rồi — phần
        // đã ghi được giữ lại và hoàn tác được bình thường (UC-03).
        await _imports.updateSession(session.interrupt());
      }
      return ImportRecoveryReport(
        interruptedSessionCount: orphans.length,
        discardedEmptySessionCount: discarded,
      );
    }),
    onError: failureFromError,
  );
}
