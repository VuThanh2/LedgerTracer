import '../../../core/result/result.dart';
import '../../shared/domain_failures.dart';
import '../contracts/app_data_store.dart';

/// Xoá sạch dữ liệu cục bộ và đưa ứng dụng về trạng thái vừa cài (UC-12).
///
/// Tồn tại vì một lý do duy nhất và không thể thay thế: **quên mã PIN**. Không
/// có cơ chế bỏ qua PIN nào, vì một cơ chế như thế vô hiệu hoá chính lớp bảo vệ
/// mà PIN dựng lên. Lối thoát duy nhất còn lại là xoá hết rồi lấy dữ liệu về từ
/// bản sao lưu đã mã hoá (UC-13) — và điều đó chỉ đi được vì mật khẩu sao lưu
/// độc lập hoàn toàn với mã PIN.
///
/// Vì vậy thao tác này **phải xoá cả thiết lập**, không chỉ dữ liệu nghiệp vụ:
/// chừa lại thiết lập là chừa lại đúng mã PIN đã quên, và use case tự triệt tiêu.
///
/// Đây là thao tác phá huỷ không quay lui được. Giao diện có nghĩa vụ xác nhận
/// tường minh và nhắc người dùng rằng chỉ bản sao lưu mới lấy lại được dữ liệu —
/// nhưng nghĩa vụ đó là của giao diện, không phải của use case: một use case
/// dừng lại hỏi là một use case không test được.
final class ResetAppUseCase {
  ResetAppUseCase({required this._store});

  final AppDataStore _store;

  Future<Result<void>> execute() =>
      Result.guardAsync(_store.wipe, onError: failureFromError);
}
