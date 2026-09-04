import '../../../domain/repositories/transaction_repository.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/money_formatter.dart';
import 'transaction_context.dart';

/// Tiêu chí nào đang thu hẹp danh sách — mỗi chip là một cái.
///
/// Kiểu này là thứ nối chip với hành động xoá nó: giao diện không đọc nhãn để
/// đoán mình vừa bấm vào cái gì, nó gửi lại đúng [FilterChipKind] và BLoC biết
/// phải gỡ tiêu chí nào.
enum FilterChipKind {
  keyword,
  account,
  dateRange,
  amountRange,
  currency,

  /// Context Chip: `Lượt nhập: <tên file>` (UC-03 → UC-04).
  importFile,

  /// Context Chip: "Không gồm chuyển khoản nội bộ" (UC-10 → UC-04).
  internalTransfers;

  /// Chip ngữ cảnh sinh ra từ màn hình nguồn, không từ Filter Panel.
  ///
  /// Nó vẫn xoá được như chip thường và vẫn phải được ghi vào đầu file xuất —
  /// khác biệt duy nhất là nơi nó ra đời, và vì thế là nơi giao diện đặt nó:
  /// ngoài Filter Panel.
  bool get isContext =>
      this == FilterChipKind.importFile ||
      this == FilterChipKind.internalTransfers;
}

/// Một chip đang hiển thị.
final class FilterChipViewModel {
  const FilterChipViewModel({required this.kind, required this.label});

  final FilterChipKind kind;

  final String label;

  bool get isContext => kind.isContext;

  @override
  bool operator ==(Object other) =>
      other is FilterChipViewModel &&
      other.kind == kind &&
      other.label == label;

  @override
  int get hashCode => Object.hash(kind, label);

  @override
  String toString() => label;
}

/// Dựng danh sách chip từ bộ lọc đang áp dụng và ngữ cảnh điều hướng.
///
/// Một chỗ duy nhất, dùng chung cho thanh chip trên màn hình **và** cho phần đầu
/// file xuất (UC-11): hai bản mô tả chép tay của cùng một tập tiêu chí là hai
/// bản sẽ lệch nhau, và khi lệch thì file xuất nói dối về dữ liệu bên trong nó.
abstract final class FilterChips {
  static List<FilterChipViewModel> of({
    required TransactionFilter filter,
    required TransactionContext context,
    required Map<int, String> accountNames,
  }) => <FilterChipViewModel>[
    if (filter.keyword != null)
      FilterChipViewModel(
        kind: FilterChipKind.keyword,
        label: 'Từ khoá: ${filter.keyword}',
      ),
    if (filter.accountId != null)
      FilterChipViewModel(
        kind: FilterChipKind.account,
        label: 'Tài khoản: '
            '${accountNames[filter.accountId] ?? filter.accountId}',
      ),
    if (filter.dateRange != null)
      FilterChipViewModel(
        kind: FilterChipKind.dateRange,
        label: 'Ngày: ${DateFormatter.range(filter.dateRange!)}',
      ),
    if (filter.amountRange != null)
      FilterChipViewModel(
        kind: FilterChipKind.amountRange,
        label: 'Số tiền: '
            '${MoneyFormatter.signed(filter.amountRange!.min)} – '
            '${MoneyFormatter.signedWithCurrency(filter.amountRange!.max)}',
      ),
    // Loại tiền chỉ thành chip riêng khi nó **không** đi kèm khoảng số tiền: khi
    // có khoảng, mã tiền đã nằm trong chính nhãn của chip ấy, và tách ra thành
    // hai chip xoá được riêng sẽ cho phép người dùng gỡ loại tiền mà vẫn giữ
    // khoảng — đúng thứ UC-07 cấm.
    if (filter.currency != null && filter.amountRange == null)
      FilterChipViewModel(
        kind: FilterChipKind.currency,
        label: 'Loại tiền: ${filter.currency!.code}',
      ),
    if (context.filtersByImport)
      FilterChipViewModel(
        kind: FilterChipKind.importFile,
        label: 'Lượt nhập: ${context.importFileName ?? ''}',
      ),
    if (context.excludeInternalTransfers)
      const FilterChipViewModel(
        kind: FilterChipKind.internalTransfers,
        label: 'Không gồm chuyển khoản nội bộ',
      ),
  ];
}
