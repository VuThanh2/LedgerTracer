import '../../../domain/repositories/transaction_repository.dart';

/// Ngữ cảnh điều hướng mà một màn hình khác mang theo khi mở danh sách giao dịch
/// (UC-03 → UC-04, UC-10 → UC-04).
///
/// Đây là thứ đứng sau **Context Chip**: chip sinh ra từ màn hình nguồn, nằm
/// ngoài Filter Panel, xoá được như chip thường, và bắt buộc được ghi vào đầu
/// file xuất. Mọi đường điều hướng phải mang theo đủ ngữ cảnh để tập dữ liệu ở
/// đích trùng đúng thứ người dùng vừa bấm vào.
///
/// ## Vì sao ngữ cảnh vẫn là một kiểu riêng, không nhập luôn vào bộ lọc
///
/// Cả hai tiêu chí ở đây đều là trường thật của `TransactionFilter`, nên [narrow]
/// chỉ là một phép dịch: danh sách, phép đếm và file xuất chạy **cùng một** điều
/// kiện ở cơ sở dữ liệu, và con số tổng là con số đúng.
///
/// Nhưng chúng khác bộ lọc ở chỗ **người dùng không tự đặt** chúng trong Filter
/// Panel — chúng đến từ màn hình nguồn, và giao diện phải phân biệt được hai
/// nhóm chip ấy để nút "Xoá bộ lọc" không âm thầm nuốt luôn ngữ cảnh mà người
/// dùng vừa mang sang. Giữ chúng tách ra chính là thứ giữ được phân biệt đó.
final class TransactionContext {
  const TransactionContext({
    this.importFileRecordId,
    this.importFileName,
    this.excludeInternalTransfers = false,
  });

  /// Vào từ lịch sử nhập: chỉ xem giao dịch của một file.
  const TransactionContext.fromImport({
    required int recordId,
    required String fileName,
  }) : this(importFileRecordId: recordId, importFileName: fileName);

  /// Vào từ thống kê: mang theo trạng thái công tắc loại trừ đang bật (UC-10).
  const TransactionContext.fromStatistics({
    required bool excludeInternalTransfers,
  }) : this(excludeInternalTransfers: excludeInternalTransfers);

  static const TransactionContext none = TransactionContext();

  /// Chỉ giữ giao dịch do bản ghi file này ghi ra.
  final int? importFileRecordId;

  /// Tên file, để dựng nhãn chip. Chỉ dùng để hiển thị.
  final String? importFileName;

  /// Bỏ các giao dịch thuộc một cặp **đã xác nhận**.
  final bool excludeInternalTransfers;

  bool get filtersByImport => importFileRecordId != null;

  bool get isEmpty => !filtersByImport && !excludeInternalTransfers;

  bool get isNotEmpty => !isEmpty;

  TransactionContext withoutImport() =>
      TransactionContext(excludeInternalTransfers: excludeInternalTransfers);

  TransactionContext withoutInternalExclusion() => TransactionContext(
    importFileRecordId: importFileRecordId,
    importFileName: importFileName,
  );

  /// Ghép ngữ cảnh vào bộ lọc người dùng đặt, thành đúng một bộ tiêu chí gửi
  /// xuống tầng dưới.
  ///
  /// Hai bên không bao giờ chỏi nhau: bộ lọc mang tài khoản/từ khoá/ngày/số
  /// tiền, ngữ cảnh mang lượt nhập và công tắc loại trừ — không tiêu chí nào bị
  /// ghi đè, nên chip trên màn hình luôn nói đúng thứ đang được áp.
  TransactionFilter narrow(TransactionFilter filter) {
    if (isEmpty) return filter;
    return TransactionFilter(
      keyword: filter.keyword,
      accountId: filter.accountId,
      dateRange: filter.dateRange,
      amountRange: filter.amountRange,
      currency: filter.currency,
      importFileRecordId: importFileRecordId ?? filter.importFileRecordId,
      excludeInternalTransfers:
          excludeInternalTransfers || filter.excludeInternalTransfers,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionContext &&
      other.importFileRecordId == importFileRecordId &&
      other.importFileName == importFileName &&
      other.excludeInternalTransfers == excludeInternalTransfers;

  @override
  int get hashCode =>
      Object.hash(importFileRecordId, importFileName, excludeInternalTransfers);
}
