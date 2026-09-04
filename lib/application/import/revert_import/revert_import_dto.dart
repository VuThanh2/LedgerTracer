import '../../../domain/entities/import_session.dart';

/// Những gì một lần hoàn tác sẽ động tới, để hộp thoại xác nhận nói được con số
/// cụ thể trước khi người dùng đồng ý (UC-03 bước 4).
final class RevertImpact {
  const RevertImpact({
    required this.deletedTransactionCount,
    required this.cancelledPairCount,
    required this.hasManualEdits,
  });

  static const RevertImpact none = RevertImpact(
    deletedTransactionCount: 0,
    cancelledPairCount: 0,
    hasManualEdits: false,
  );

  final int deletedTransactionCount;

  /// Số cặp đối soát sẽ bị huỷ vì một trong hai vế bị xoá (bất biến ở UC-09).
  final int cancelledPairCount;

  /// Lượt nhập có giao dịch đã bị sửa tay — hoàn tác sẽ xoá luôn phần đã sửa, nên
  /// phải cảnh báo trước (UC-03).
  final bool hasManualEdits;

  RevertImpact mergedWith(RevertImpact other) => RevertImpact(
    deletedTransactionCount:
        deletedTransactionCount + other.deletedTransactionCount,
    cancelledPairCount: cancelledPairCount + other.cancelledPairCount,
    hasManualEdits: hasManualEdits || other.hasManualEdits,
  );
}

/// Một trang lịch sử nhập, lượt gần nhất trước (UC-03 bước 2).
final class ImportHistoryPage {
  const ImportHistoryPage({
    required this.sessions,
    required this.totalCount,
    required this.offset,
  });

  /// Mỗi lượt đã kèm sẵn các bản ghi file của nó; dòng lỗi nạp riêng khi xuất.
  final List<ImportSession> sessions;

  final int totalCount;

  final int offset;
}
