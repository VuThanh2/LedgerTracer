import '../../../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';

/// Có bao nhiêu tài khoản **thật sự có giao dịch**.
///
/// Hai màn hình cần đúng con số này và cần nó vì cùng một lý do: đối soát nội bộ
/// tìm cặp chuyển tiền giữa **hai tài khoản khác nhau**, nên dưới hai tài khoản
/// có giao dịch thì nó không có gì để làm. Màn hình đối soát thay nút Chạy bằng
/// một lời giải thích (UC-08, tiền điều kiện), còn màn hình thống kê dùng nó để
/// chọn xem Zero-effect Notice nên dẫn người dùng sang Nhập hay sang Đối soát
/// (UC-10).
///
/// Lớp này còn lại vì hai lý do, không phải vì phép đếm: nó giữ [minimumAccountsForReconciliation]
/// ở đúng một chỗ cho cả hai màn hình, và nó biến một `Result` thành con số mà
/// một trạng thái trống dựng được.
abstract final class AccountActivity {
  /// Cần ít nhất từng này tài khoản có giao dịch thì đối soát mới chạy được.
  static const int minimumAccountsForReconciliation = 2;

  static Future<int> countAccountsWithTransactions(
    ViewCashFlowUseCase viewCashFlow,
  ) async {
    final result = await viewCashFlow.accountsWithTransactions();
    // Không đọc được thì trả 0 — màn hình gọi đang dựng một trạng thái trống,
    // không phải đang thực hiện một thao tác, nên nó cần một con số chứ không
    // cần một lỗi để hiển thị.
    return result.valueOrNull ?? 0;
  }
}
