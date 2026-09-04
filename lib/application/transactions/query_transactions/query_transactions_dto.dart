import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/transaction_repository.dart';

/// Tiêu chí một trang danh sách giao dịch (UC-04, UC-06, UC-07).
///
/// [filter] gom mọi tiêu chí thu hẹp vào một object, để danh sách, phép đếm và
/// file xuất chạy **cùng một** điều kiện thay vì ba bản chép tay lệch nhau.
final class QueryTransactionsRequest {
  const QueryTransactionsRequest({
    this.filter = TransactionFilter.none,
    required this.limit,
    required this.offset,
  });

  final TransactionFilter filter;

  /// Số dòng mỗi trang — danh sách cuộn lười, không nạp cả tập vào bộ nhớ (UC-04).
  final int limit;

  final int offset;
}

/// Một dòng trong danh sách: giao dịch kèm những gì màn hình cần hiển thị mà bản
/// thân giao dịch không mang sẵn.
final class TransactionListItem {
  const TransactionListItem({
    required this.transaction,
    required this.accountDisplayName,
    required this.isReconciled,
  });

  final Transaction transaction;

  /// Tên tài khoản, vì danh sách gộp chung mọi tài khoản — thiếu nó người dùng
  /// không đọc hiểu được dữ liệu (UC-04).
  final String accountDisplayName;

  /// Thuộc một cặp đã **xác nhận** — chỉ báo "đã đối soát" (UC-04, UC-09).
  final bool isReconciled;
}

/// Một trang kết quả kèm tổng số dòng khớp, cho trạng thái trống và phân trang.
final class TransactionsPage {
  const TransactionsPage({
    required this.items,
    required this.totalCount,
    required this.offset,
  });

  final List<TransactionListItem> items;

  final int totalCount;

  final int offset;

  bool get isEmpty => totalCount == 0;
}
