import '../view_models/filter_chip_view_model.dart';
import '../view_models/transaction_context.dart';
import '../view_models/transaction_filter_draft.dart';

/// Những gì có thể xảy ra trên màn hình danh sách giao dịch (UC-04, UC-06,
/// UC-07).
///
/// Là một tập đóng để `switch` trong BLoC vét cạn, và để mọi đường vào màn hình
/// này đi qua đúng một cửa: ba điểm vào của UC-04 (thanh điều hướng, khoan xuống
/// từ Thống kê, xem giao dịch của một lượt nhập) chỉ khác nhau ở ngữ cảnh mang
/// theo trong [TransactionsStarted], không khác nhau ở luồng xử lý.
sealed class TransactionsEvent {
  const TransactionsEvent();
}

/// Mở màn hình. Ngữ cảnh và bộ lọc đặt sẵn đến từ màn hình nguồn.
final class TransactionsStarted extends TransactionsEvent {
  const TransactionsStarted({
    this.context = TransactionContext.none,
    this.draft = TransactionFilterDraft.empty,
  });

  final TransactionContext context;

  /// Khoan xuống từ Thống kê mang sẵn khoảng ngày và loại tiền (UC-10).
  final TransactionFilterDraft draft;
}

/// Đọc lại từ đầu với đúng tiêu chí đang có — sau khi sửa/xoá, hoặc khi người
/// dùng kéo để làm mới.
final class TransactionsRefreshed extends TransactionsEvent {
  const TransactionsRefreshed();
}

/// Cuộn tới cuối danh sách (UC-04).
final class TransactionsNextPageRequested extends TransactionsEvent {
  const TransactionsNextPageRequested();
}

/// Người dùng gõ vào ô tìm kiếm. Sự kiện này đi qua debounce (UC-06).
final class TransactionsKeywordChanged extends TransactionsEvent {
  const TransactionsKeywordChanged(this.keyword);

  final String keyword;
}

/// Sửa một ô trong Filter Panel. **Không** chạy truy vấn: bộ lọc chỉ có hiệu lực
/// khi bấm áp dụng, nên bản nháp thay đổi một mình.
final class TransactionsFilterDraftChanged extends TransactionsEvent {
  const TransactionsFilterDraftChanged(this.draft);

  final TransactionFilterDraft draft;
}

/// Áp dụng bản nháp. Bản nháp sai thì lỗi về theo từng ô và danh sách giữ nguyên
/// tiêu chí cũ (UC-07).
final class TransactionsFilterApplied extends TransactionsEvent {
  const TransactionsFilterApplied();
}

/// Xoá toàn bộ tiêu chí trong Filter Panel. Chip ngữ cảnh **không** bị xoá theo:
/// chúng đến từ màn hình nguồn và có đường xoá riêng.
final class TransactionsFilterCleared extends TransactionsEvent {
  const TransactionsFilterCleared();
}

/// Bấm dấu × trên một chip — kể cả chip ngữ cảnh.
final class TransactionsChipRemoved extends TransactionsEvent {
  const TransactionsChipRemoved(this.kind);

  final FilterChipKind kind;
}

/// Chọn một dòng. Trên bố cục hai pane, đây là thứ đổ dữ liệu vào pane phải;
/// trên bố cục hẹp, giao diện đẩy sang một route riêng với cùng dữ liệu.
final class TransactionSelected extends TransactionsEvent {
  const TransactionSelected(this.transactionId);

  /// `null` để bỏ chọn — đóng pane chi tiết.
  final int? transactionId;
}

/// Mở chi tiết một giao dịch **chưa có trong danh sách đang tải**: vào thẳng từ
/// một liên kết ở màn hình đối soát, hoặc khôi phục lại route sau khi ứng dụng
/// bị dựng lại.
final class TransactionDetailRequested extends TransactionsEvent {
  const TransactionDetailRequested(this.transactionId);

  final int transactionId;
}

/// Bấm nút xoá: hỏi trước xem giao dịch có đang thuộc một cặp đối soát không, để
/// hộp thoại xác nhận nói rõ cặp đó sẽ bị huỷ (UC-05).
final class TransactionDeleteRequested extends TransactionsEvent {
  const TransactionDeleteRequested(this.transactionId);

  final int transactionId;
}

/// Đóng hộp thoại xác nhận xoá mà không xoá.
final class TransactionDeleteDismissed extends TransactionsEvent {
  const TransactionDeleteDismissed();
}

/// Đồng ý xoá trong hộp thoại xác nhận (UC-05).
final class TransactionDeleteConfirmed extends TransactionsEvent {
  const TransactionDeleteConfirmed();
}

/// Một giao dịch vừa được sửa ở nơi khác (biểu mẫu sửa có BLoC riêng), nên dòng
/// tương ứng và các con số phải được đọc lại.
final class TransactionsInvalidated extends TransactionsEvent {
  const TransactionsInvalidated({this.changedTransactionId});

  final int? changedTransactionId;
}
