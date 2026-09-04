import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/bloc/load_status.dart';
import '../../shared/bloc/transient_notice.dart';
import '../../shared/failures/feedback_message.dart';
import '../view_models/filter_chip_view_model.dart';
import '../view_models/transaction_context.dart';
import '../view_models/transaction_filter_draft.dart';
import '../view_models/transaction_row_view_model.dart';

/// Giao dịch nào sắp bị xoá, và việc đó kéo theo gì (UC-05).
///
/// Tồn tại như một trạng thái riêng chứ không phải một cờ `isDeleting`, vì giữa
/// lúc bấm nút xoá và lúc thật sự xoá có một phép hỏi cơ sở dữ liệu: giao dịch
/// này có đang thuộc một cặp đối soát không. Hộp thoại xác nhận phải nói ra con
/// số đó **trước khi** người dùng đồng ý, nên nó là một bước có trạng thái chứ
/// không phải một lời gọi hàm.
final class DeleteConfirmation {
  const DeleteConfirmation({
    required this.transactionId,
    required this.cancelsReconciliation,
    this.isDeleting = false,
  });

  final int transactionId;

  /// Xoá sẽ huỷ một cặp đối soát. Không có ngoại lệ nào cho phép giữ cặp lại —
  /// hộp thoại chỉ nói ra hệ quả, không đưa thêm lựa chọn (UC-05, UC-09).
  final bool cancelsReconciliation;

  final bool isDeleting;

  DeleteConfirmation deleting() => DeleteConfirmation(
    transactionId: transactionId,
    cancelsReconciliation: cancelsReconciliation,
    isDeleting: true,
  );
}

/// Toàn bộ trạng thái màn hình danh sách giao dịch.
///
/// **Cố ý không có `==` theo giá trị.** Đây là màn hình chính của một công cụ
/// dày dữ liệu: [rows] có thể dài hàng trăm nghìn phần tử, và so sánh sâu ở mỗi
/// lần `emit` sẽ tốn hơn hẳn việc vẽ lại — trong khi mọi `emit` ở BLoC này đều
/// thật sự mang theo thay đổi, nên phép so sánh ấy sẽ không bao giờ chặn được
/// lần nào. Giao diện thu hẹp phạm vi vẽ lại bằng `buildWhen`/`BlocSelector`,
/// nơi phép so sánh chạy trên đúng vài trường mà widget đó đọc.
final class TransactionsState {
  const TransactionsState({
    this.status = LoadStatus.initial,
    this.rows = const <TransactionRowViewModel>[],
    this.keyword = '',
    this.filter = TransactionFilter.none,
    this.draft = TransactionFilterDraft.empty,
    this.validation,
    this.context = TransactionContext.none,
    this.chips = const <FilterChipViewModel>[],
    this.accountNames = const <int, String>{},
    this.currencies = const <CurrencyUsage>[],
    this.scannedCount = 0,
    this.totalCount = 0,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.selectedId,
    this.detail,
    this.detailStatus = LoadStatus.initial,
    this.pendingDelete,
    this.notice,
    this.loadError,
  });

  final LoadStatus status;

  /// Các dòng **đã qua ngữ cảnh**, cộng dồn qua các trang đã tải.
  final List<TransactionRowViewModel> rows;

  /// Chữ trong ô tìm kiếm, đúng như đang gõ. Nó chỉ trở thành tiêu chí sau
  /// debounce, nên nó không nằm trong [filter] cho tới lúc đó (UC-06).
  final String keyword;

  /// Bộ tiêu chí **đang áp dụng**.
  final TransactionFilter filter;

  /// Bộ tiêu chí đang được sửa trong Filter Panel.
  final TransactionFilterDraft draft;

  /// Lỗi theo từng ô của lần bấm áp dụng gần nhất; `null` khi chưa bấm hoặc bản
  /// nháp hợp lệ.
  final TransactionFilterValidation? validation;

  final TransactionContext context;

  /// Chip của cả bộ lọc lẫn ngữ cảnh, đã dựng sẵn — dùng chung cho thanh chip và
  /// cho phần đầu file xuất (UC-11).
  final List<FilterChipViewModel> chips;

  final Map<int, String> accountNames;

  /// Các loại tiền đang có, nhiều giao dịch nhất trước (UC-07).
  final List<CurrencyUsage> currencies;

  /// Số dòng đã **đọc lên từ cơ sở dữ liệu**, kể cả dòng bị ngữ cảnh loại ra.
  /// Đây là offset của trang kế tiếp.
  final int scannedCount;

  /// Số dòng khớp [filter] ở cơ sở dữ liệu.
  ///
  /// Khi ngữ cảnh còn thu hẹp thêm trong bộ nhớ thì đây là **cận trên** chứ
  /// không phải con số thật — xem [isCountExact].
  final int totalCount;

  final bool hasMore;

  final bool isLoadingMore;

  final int? selectedId;

  final TransactionDetailViewModel? detail;

  final LoadStatus detailStatus;

  final DeleteConfirmation? pendingDelete;

  /// Thông báo dùng một lần (snackbar).
  final TransientNotice? notice;

  /// Lỗi của lần đọc danh sách gần nhất. Dữ liệu cũ vẫn còn trong [rows] để màn
  /// hình không trắng xoá.
  final FeedbackMessage? loadError;

  /// [totalCount] có phải con số đúng của thứ đang hiển thị hay không.
  ///
  /// Sai khi Context Chip còn phải lọc trong bộ nhớ, vì phép đếm chạy ở cơ sở dữ
  /// liệu và không biết tới ngữ cảnh. Vì phép lọc trong bộ nhớ chỉ **bớt** đi, đây
  /// là cận trên: giao diện đọc cờ này để hiển thị "tối đa N" thay vì một con
  /// số nói dối.
  bool get isCountExact => !context.narrowsInMemory;

  /// Số dòng thật sự đang hiển thị.
  int get visibleCount => rows.length;

  bool get isEmpty => status.isReady && rows.isEmpty;

  /// Có tiêu chí nào đang thu hẹp danh sách không — để phân biệt "chưa có dữ
  /// liệu nào" với "không có kết quả nào khớp", hai trạng thái trống cần hai câu
  /// chữ khác hẳn nhau.
  bool get isNarrowed => !filter.isEmpty || context.isNotEmpty;

  TransactionsState copyWith({
    LoadStatus? status,
    List<TransactionRowViewModel>? rows,
    String? keyword,
    TransactionFilter? filter,
    TransactionFilterDraft? draft,
    TransactionFilterValidation? validation,
    bool clearValidation = false,
    TransactionContext? context,
    List<FilterChipViewModel>? chips,
    Map<int, String>? accountNames,
    List<CurrencyUsage>? currencies,
    int? scannedCount,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
    int? selectedId,
    bool clearSelection = false,
    TransactionDetailViewModel? detail,
    bool clearDetail = false,
    LoadStatus? detailStatus,
    DeleteConfirmation? pendingDelete,
    bool clearPendingDelete = false,
    TransientNotice? notice,
    FeedbackMessage? loadError,
    bool clearLoadError = false,
  }) => TransactionsState(
    status: status ?? this.status,
    rows: rows ?? this.rows,
    keyword: keyword ?? this.keyword,
    filter: filter ?? this.filter,
    draft: draft ?? this.draft,
    validation: clearValidation ? null : (validation ?? this.validation),
    context: context ?? this.context,
    chips: chips ?? this.chips,
    accountNames: accountNames ?? this.accountNames,
    currencies: currencies ?? this.currencies,
    scannedCount: scannedCount ?? this.scannedCount,
    totalCount: totalCount ?? this.totalCount,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    selectedId: clearSelection ? null : (selectedId ?? this.selectedId),
    detail: clearDetail ? null : (detail ?? this.detail),
    detailStatus: detailStatus ?? this.detailStatus,
    pendingDelete: clearPendingDelete
        ? null
        : (pendingDelete ?? this.pendingDelete),
    notice: notice ?? this.notice,
    loadError: clearLoadError ? null : (loadError ?? this.loadError),
  );
}
