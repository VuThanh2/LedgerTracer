/// Nền tảng bên dưới thực sự cho phép làm gì với một workload nặng.
///
/// Là dữ liệu thuần, không tự dò tìm: giá trị do chính platform binding dựng
/// runner tạo ra (xem `isolate_runner.dart`), nhờ vậy file này không cần
/// conditional import và test hay màn hình benchmark có thể dựng tay.
final class PlatformCapabilities {
  const PlatformCapabilities({
    required this.supportsIsolates,
    required this.processorCount,
  }) : assert(processorCount >= 1, 'there is always at least one processor');

  /// Native: có isolate thật, và có bao nhiêu nhân thì biết bấy nhiêu.
  const PlatformCapabilities.native({required int processorCount})
    : this(supportsIsolates: true, processorCount: processorCount);

  /// Web: không có `dart:isolate`, mọi thứ chạy trên đúng luồng đang vẽ giao
  /// diện (UC-14).
  const PlatformCapabilities.web()
    : this(supportsIsolates: false, processorCount: 1);

  final bool supportsIsolates;

  final int processorCount;

  /// Nên chạy bao nhiêu workload cùng lúc.
  ///
  /// Cố ý chặn thấp hơn số nhân: các isolate phân tích đều đổ về **một** luồng
  /// ghi tuần tự, nên thêm worker nữa không mua được thêm thông lượng mà chỉ tốn
  /// bộ nhớ (UC-02). Con số cụ thể là một trong những thứ màn hình benchmark
  /// đem ra đo.
  int get recommendedParallelism {
    if (!supportsIsolates) return 1;
    return processorCount < maxUsefulParallelism
        ? processorCount
        : maxUsefulParallelism;
  }

  static const int maxUsefulParallelism = 4;

  @override
  bool operator ==(Object other) =>
      other is PlatformCapabilities &&
      other.supportsIsolates == supportsIsolates &&
      other.processorCount == processorCount;

  @override
  int get hashCode => Object.hash(supportsIsolates, processorCount);

  @override
  String toString() =>
      'PlatformCapabilities(isolates: $supportsIsolates, '
      'cores: $processorCount)';
}
