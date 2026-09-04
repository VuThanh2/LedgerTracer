import '../../../application/transactions/query_transactions/query_transactions_dto.dart';
import '../../../domain/repositories/transaction_repository.dart';

/// Ngữ cảnh điều hướng mà một màn hình khác mang theo khi mở danh sách giao dịch
/// (UC-03 → UC-04, UC-10 → UC-04).
///
/// Đây là thứ đứng sau **Context Chip**: chip sinh ra từ màn hình nguồn, nằm
/// ngoài Filter Panel, xoá được như chip thường, và bắt buộc được ghi vào đầu
/// file xuất. Mọi đường điều hướng phải mang theo đủ ngữ cảnh để tập dữ liệu ở
/// đích trùng đúng thứ người dùng vừa bấm vào.
///
/// ## Ngữ cảnh này được áp dụng ở đâu — và vì sao ở đây
///
/// `TransactionFilter` của Domain có năm tiêu chí: từ khoá, tài khoản, khoảng
/// ngày, khoảng số tiền, loại tiền. **Không** có tiêu chí "thuộc lượt nhập nào"
/// và **không** có tiêu chí "bỏ giao dịch nội bộ đã đối soát" — hai thứ mà hai
/// Context Chip cần. Tầng Presentation không được sửa hợp đồng của tầng dưới,
/// nên nó thu hẹp bằng đúng những gì đã có trong tay:
///
/// * **Loại trừ chuyển khoản nội bộ** lọc được *chính xác* ngay tại đây:
///   `TransactionListItem.isReconciled` đã nói dòng đó có thuộc một cặp **đã xác
///   nhận** hay không, và đó đúng là định nghĩa của "giao dịch nội bộ đã đối
///   soát" mà UC-10 dùng. Không mất mát gì về tính đúng.
/// * **Lọc theo lượt nhập** cũng chính xác — `Transaction.importFileRecordId`
///   nằm sẵn trên mỗi dòng — nhưng phép so sánh diễn ra *sau khi* đã đọc lên,
///   nên nó chỉ rẻ khi tập phải đọc đủ nhỏ. Vì vậy [importAccountId] tồn tại:
///   một bản ghi file thuộc **đúng một** tài khoản, nên ngữ cảnh thu hẹp trước
///   bằng `accountId` — một tiêu chí thật, có chỉ mục — rồi mới so định danh bản
///   ghi trên phần còn lại.
///
/// Cái giá của cách này là [TransactionsState.totalCount] trở thành **cận
/// trên** chứ không còn là con số đúng, vì phép đếm chạy ở cơ sở dữ liệu, trước
/// khi ngữ cảnh được áp. Trạng thái nói rõ điều đó thay vì hiển thị một con số
/// sai (xem `isCountExact`).
///
/// Chỗ sửa gọn nhất về sau nằm ở tầng dưới, không phải ở đây: thêm hai trường
/// `importFileRecordId` và `excludeInternalTransfers` vào `TransactionFilter`
/// rồi cho `TransactionRepository` dịch chúng thành mệnh đề SQL. Khi đó lớp lọc
/// trong bộ nhớ dưới đây bỏ đi được, và phép đếm đúng trở lại.
final class TransactionContext {
  const TransactionContext({
    this.importFileRecordId,
    this.importFileName,
    this.importAccountId,
    this.excludeInternalTransfers = false,
  });

  /// Vào từ lịch sử nhập: chỉ xem giao dịch của một file.
  const TransactionContext.fromImport({
    required int recordId,
    required String fileName,
    required int accountId,
  }) : this(
         importFileRecordId: recordId,
         importFileName: fileName,
         importAccountId: accountId,
       );

  /// Vào từ thống kê: mang theo trạng thái công tắc loại trừ đang bật (UC-10).
  const TransactionContext.fromStatistics({
    required bool excludeInternalTransfers,
  }) : this(excludeInternalTransfers: excludeInternalTransfers);

  static const TransactionContext none = TransactionContext();

  /// Chỉ giữ giao dịch do bản ghi file này ghi ra.
  final int? importFileRecordId;

  /// Tên file, để dựng nhãn chip. Chỉ dùng để hiển thị.
  final String? importFileName;

  /// Tài khoản đích của bản ghi file đó — dùng để thu hẹp trước ở cơ sở dữ liệu.
  final int? importAccountId;

  /// Bỏ các giao dịch thuộc một cặp **đã xác nhận**.
  final bool excludeInternalTransfers;

  bool get filtersByImport => importFileRecordId != null;

  bool get isEmpty => !filtersByImport && !excludeInternalTransfers;

  bool get isNotEmpty => !isEmpty;

  /// Ngữ cảnh có làm cho phép đếm ở cơ sở dữ liệu lệch khỏi số dòng thật sự hiển
  /// thị hay không.
  bool get narrowsInMemory => isNotEmpty;

  TransactionContext withoutImport() => TransactionContext(
    excludeInternalTransfers: excludeInternalTransfers,
  );

  TransactionContext withoutInternalExclusion() => TransactionContext(
    importFileRecordId: importFileRecordId,
    importFileName: importFileName,
    importAccountId: importAccountId,
  );

  /// Thu hẹp trước ở cơ sở dữ liệu bằng những tiêu chí thật sự có: tài khoản của
  /// bản ghi file, khi ngữ cảnh là một lượt nhập.
  ///
  /// Bộ lọc do người dùng đặt được ưu tiên: họ đang nhìn thấy chip tài khoản của
  /// chính mình, nên ghi đè nó bằng tài khoản suy ra từ ngữ cảnh sẽ làm chip đó
  /// nói dối. Khi hai bên chỏi nhau thì kết quả rỗng — và đó là câu trả lời
  /// đúng: không có giao dịch nào vừa thuộc file kia vừa thuộc tài khoản này.
  TransactionFilter narrow(TransactionFilter filter) {
    final accountId = importAccountId;
    if (accountId == null || filter.accountId != null) return filter;
    return TransactionFilter(
      keyword: filter.keyword,
      accountId: accountId,
      dateRange: filter.dateRange,
      amountRange: filter.amountRange,
      currency: filter.currency,
    );
  }

  /// Dòng này có qua được ngữ cảnh không.
  bool keeps(TransactionListItem item) {
    if (excludeInternalTransfers && item.isReconciled) return false;
    final recordId = importFileRecordId;
    if (recordId != null &&
        item.transaction.importFileRecordId != recordId) {
      return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionContext &&
      other.importFileRecordId == importFileRecordId &&
      other.importFileName == importFileName &&
      other.importAccountId == importAccountId &&
      other.excludeInternalTransfers == excludeInternalTransfers;

  @override
  int get hashCode => Object.hash(
    importFileRecordId,
    importFileName,
    importAccountId,
    excludeInternalTransfers,
  );
}
