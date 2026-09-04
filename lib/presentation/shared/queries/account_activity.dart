import '../../../application/statistics/view_cash_flow/view_cash_flow_dto.dart';
import '../../../application/statistics/view_cash_flow/view_cash_flow_use_case.dart';
import '../../../domain/repositories/transaction_repository.dart';

/// Có bao nhiêu tài khoản **thật sự có giao dịch**.
///
/// Hai màn hình cần đúng con số này và cần nó vì cùng một lý do: đối soát nội bộ
/// tìm cặp chuyển tiền giữa **hai tài khoản khác nhau**, nên dưới hai tài khoản
/// có giao dịch thì nó không có gì để làm. Màn hình đối soát thay nút Chạy bằng
/// một lời giải thích (UC-08, tiền điều kiện), còn màn hình thống kê dùng nó để
/// chọn xem Zero-effect Notice nên dẫn người dùng sang Nhập hay sang Đối soát
/// (UC-10).
///
/// ## Vì sao phải đi vòng
///
/// Tầng Application không có đường đọc nào trả thẳng con số này. Những gì có:
/// `ManageAccountsUseCase.list()` trả tài khoản **đã khai báo** — kể cả tài
/// khoản vừa tạo chưa nhập file nào, nên đếm nó là đếm sai; và
/// `previewDeletion(id)` trả đúng số giao dịch của một tài khoản, nhưng nó là
/// phần chuẩn bị cho một hộp thoại xoá, gọi nó ở đây là dùng một hàm cho việc
/// không phải của nó, và vẫn tốn một lượt truy vấn cho **mỗi** tài khoản.
///
/// Đường đi ở đây tốn `1 + số loại tiền` lượt truy vấn, không phụ thuộc số tài
/// khoản: gom dòng tiền theo tài khoản chỉ trả về cột cho những tài khoản có
/// giao dịch, nên hợp của các cột qua mọi loại tiền **chính là** tập cần đếm.
/// Số loại tiền trong dữ liệu thực tế là một tới ba.
///
/// [ViewCashFlowRequest.excludeInternalTransfers] bị tắt ở đây, và đó là điểm
/// mấu chốt: bật nó lên thì một tài khoản mà **mọi** giao dịch đều đã đối soát
/// sẽ biến mất khỏi kết quả, và màn hình đối soát sẽ báo "chưa đủ tài khoản"
/// ngay sau một lần đối soát thành công.
///
/// Chỗ sửa gọn nhất vẫn nằm ở tầng dưới: một
/// `TransactionRepository.countAccountsWithTransactions()` thay cả hàm này bằng
/// một truy vấn `COUNT(DISTINCT account_id)`.
abstract final class AccountActivity {
  /// Cần ít nhất từng này tài khoản có giao dịch thì đối soát mới chạy được.
  static const int minimumAccountsForReconciliation = 2;

  static Future<int> countAccountsWithTransactions(
    ViewCashFlowUseCase viewCashFlow,
  ) async {
    final currencies = await viewCashFlow.availableCurrencies();
    final usage = currencies.valueOrNull;
    // Không đọc được thì trả 0 — màn hình gọi đang dựng một trạng thái trống,
    // không phải đang thực hiện một thao tác, nên nó cần một con số chứ không
    // cần một lỗi để hiển thị.
    if (usage == null || usage.isEmpty) return 0;

    final accountIds = <int>{};
    for (final CurrencyUsage(:currency) in usage) {
      final series = await viewCashFlow.execute(
        ViewCashFlowRequest(
          currency: currency,
          grouping: CashFlowGrouping.byAccount,
          excludeInternalTransfers: false,
        ),
      );
      for (final bucket in series.valueOrNull?.buckets ?? const []) {
        if (bucket case AccountCashFlow(:final accountId)) {
          accountIds.add(accountId);
        }
      }
    }
    return accountIds.length;
  }
}
