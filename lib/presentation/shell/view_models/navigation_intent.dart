import '../../../domain/value_objects/pair_status.dart';
import '../../transactions/view_models/transaction_context.dart';
import '../../transactions/view_models/transaction_filter_draft.dart';

/// Bốn ô của thanh điều hướng chính.
///
/// Chọn theo **tần suất dùng**, không theo phân loại chức năng: đây là bốn việc
/// lặp lại hằng ngày. Quản lý tài khoản, Thiết lập và Sao lưu nằm dưới Thiết
/// lập; Lịch sử nhập là một tab bên trong Nhập.
enum NavDestination {
  transactions,
  import,
  reconciliation,
  statistics;

  String get label => switch (this) {
    NavDestination.transactions => 'Giao dịch',
    NavDestination.import => 'Nhập',
    NavDestination.reconciliation => 'Đối soát',
    NavDestination.statistics => 'Thống kê',
  };
}

/// Một yêu cầu điều hướng **có mang ngữ cảnh**, phát ra từ một màn hình và tiêu
/// thụ ở một màn hình khác.
///
/// Tồn tại vì Screen Map đặt ra một ràng buộc mà một `Navigator.push` trần không
/// giữ được: *mọi đường điều hướng phải mang theo đủ ngữ cảnh để tập dữ liệu ở
/// đích trùng với thứ người dùng vừa bấm vào*. Gói ngữ cảnh ấy vào một kiểu tổng
/// đóng nghĩa là không thêm được một đường đi mới mà quên mang theo nó — trình
/// biên dịch sẽ hỏi.
sealed class NavigationIntent {
  const NavigationIntent();

  /// Ô điều hướng mà yêu cầu này dẫn tới.
  NavDestination get destination;
}

/// Mở danh sách giao dịch kèm ngữ cảnh (UC-03 → UC-04, UC-10 → UC-04).
final class OpenTransactions extends NavigationIntent {
  const OpenTransactions({
    this.context = TransactionContext.none,
    this.draft = TransactionFilterDraft.empty,
  });

  /// Sinh ra Context Chip ở màn hình đích.
  final TransactionContext context;

  /// Bộ lọc đặt sẵn — khoan xuống từ Thống kê mang theo khoảng ngày và loại
  /// tiền của đúng cột vừa bấm.
  final TransactionFilterDraft draft;

  @override
  NavDestination get destination => NavDestination.transactions;
}

/// Mở màn hình đối soát (UC-04 → UC-09, UC-02 bước 8 → UC-08).
final class OpenReconciliation extends NavigationIntent {
  const OpenReconciliation({this.focusPairId, this.status});

  /// Mở thẳng tới một cặp cụ thể.
  ///
  /// Vào từ chỉ báo "đã đối soát" ở màn hình chi tiết giao dịch thì giá trị này
  /// **hiện chưa có**: tầng Application không có đường đọc nào trả về cặp chứa
  /// một giao dịch cho trước — `ReconciliationRepository.findPairInvolving` tồn
  /// tại nhưng không use case nào phơi nó ra. Đường đi đó vì thế mở màn hình ở
  /// nhóm *Đã xác nhận* thay vì bung sẵn đúng cặp; người dùng vẫn tới đúng chỗ,
  /// chỉ mất một cú bấm.
  ///
  /// Một `ListMatchAlternativesUseCase.findPairForTransaction(id)` bọc phương
  /// thức repository đã có sẽ lấp chỗ này bằng vài dòng.
  final int? focusPairId;

  /// Nhóm phán quyết mở sẵn.
  final PairStatus? status;

  @override
  NavDestination get destination => NavDestination.reconciliation;
}

/// Mở tab Nhập mới (từ nút gợi ý ở các trạng thái trống).
final class OpenImport extends NavigationIntent {
  const OpenImport();

  @override
  NavDestination get destination => NavDestination.import;
}

/// Một yêu cầu điều hướng kèm số thứ tự, để bên nghe biết đâu là yêu cầu mới.
///
/// Cùng cơ chế với `TransientNotice`, và cùng lý do: state được vẽ lại vì bất kỳ
/// điều gì, nên một yêu cầu nằm trong state mà không có số thứ tự sẽ hoặc bị
/// thực hiện lại, hoặc bị nuốt mất khi hai yêu cầu giống hệt nhau nối tiếp.
final class PendingNavigation {
  const PendingNavigation(this.intent, this.sequence);

  final NavigationIntent intent;
  final int sequence;

  @override
  bool operator ==(Object other) =>
      other is PendingNavigation &&
      other.intent == intent &&
      other.sequence == sequence;

  @override
  int get hashCode => Object.hash(intent, sequence);
}
