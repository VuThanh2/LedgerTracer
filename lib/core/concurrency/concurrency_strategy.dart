import 'execution_mode.dart';

/// Các núm vặn quyết định một workload nặng được chạy như thế nào.
///
/// Mọi thứ ở đây đều là đánh đổi mà báo cáo phải **đo** chứ không phải khẳng
/// định suông, nên chúng nằm trong một object để màn hình benchmark thay đổi
/// được còn phần còn lại của ứng dụng chỉ việc nhận:
///
/// * [batchSize] đánh đổi độ mịn của tiến trình và độ trễ của nút Huỷ với chi
///   phí đi qua ranh giới isolate — mỗi thông điệp là một lần sao chép, gửi
///   từng dòng còn tốn hơn cả việc phân tích;
/// * [maxPendingBatches] đánh đổi bộ nhớ với thông lượng — phân tích nhanh hơn
///   ghi, không có trần thì nhập vài file lớn cùng lúc sẽ phình bộ nhớ tới khi
///   hệ điều hành kết liễu ứng dụng;
/// * [parallelism] đánh đổi việc tận dụng CPU với việc tranh chấp ở luồng ghi
///   duy nhất.
final class ConcurrencyStrategy {
  ConcurrencyStrategy({
    required this.mode,
    required this.parallelism,
    required this.batchSize,
    required this.maxPendingBatches,
  }) {
    if (parallelism < 1) {
      throw ArgumentError.value(parallelism, 'parallelism', 'must be >= 1');
    }
    if (batchSize < 1) {
      throw ArgumentError.value(batchSize, 'batchSize', 'must be >= 1');
    }
    if (maxPendingBatches < 1) {
      throw ArgumentError.value(
        maxPendingBatches,
        'maxPendingBatches',
        'must be >= 1',
      );
    }
  }

  /// Nhiều file phân tích cùng lúc, mỗi file một isolate (UC-02).
  ConcurrencyStrategy.parallelIsolates({
    required int parallelism,
    int batchSize = defaultImportBatchSize,
    int maxPendingBatches = defaultMaxPendingBatches,
  }) : this(
         mode: ExecutionMode.isolate,
         parallelism: parallelism,
         batchSize: batchSize,
         maxPendingBatches: maxPendingBatches,
       );

  /// Mỗi lúc một isolate nền — hình dạng của lần quét đối soát, vốn là một lượt
  /// duyệt CPU-bound trên toàn bảng (UC-08).
  ConcurrencyStrategy.singleIsolate({
    int batchSize = defaultScanBatchSize,
    int maxPendingBatches = defaultMaxPendingBatches,
  }) : this(
         mode: ExecutionMode.isolate,
         parallelism: 1,
         batchSize: batchSize,
         maxPendingBatches: maxPendingBatches,
       );

  /// Tất cả trên luồng đang gọi, hết workload này tới workload khác.
  ///
  /// Đây là lựa chọn duy nhất của Web, và là mốc so sánh của benchmark trên
  /// native. [maxPendingBatches] bị ghim bằng 1: phân tích và ghi cùng một luồng
  /// nên không bên nào chạy nhanh hơn bên kia, backpressure không còn gì để điều
  /// tiết — một kỹ thuật cần thiết trên nền tảng này và vô nghĩa trên nền tảng
  /// kia (UC-14).
  ConcurrencyStrategy.mainThread({int batchSize = defaultImportBatchSize})
    : this(
        mode: ExecutionMode.mainThread,
        parallelism: 1,
        batchSize: batchSize,
        maxPendingBatches: 1,
      );

  final ExecutionMode mode;

  /// Tối đa bao nhiêu workload chạy cùng lúc.
  final int parallelism;

  /// Số dòng xử lý giữa hai lần báo tiến trình và hai lần kiểm yêu cầu huỷ.
  final int batchSize;

  /// Bao nhiêu lô đã sinh ra được phép chờ ghi trước khi bên sản xuất bị chặn.
  final int maxPendingBatches;

  /// Số dòng mỗi lô khi nhập. Đủ lớn để chi phí sao chép thông điệp thành số lẻ,
  /// đủ nhỏ để nút Huỷ vẫn nhạy.
  static const int defaultImportBatchSize = 500;

  /// Lần quét là CPU thuần và kết quả gửi về rất nhỏ, nên lô thưa hơn lúc phân
  /// tích file.
  static const int defaultScanBatchSize = 2000;

  /// Hai lô đang bay đủ để luồng ghi không rảnh mà bộ nhớ vẫn nhẹ.
  static const int defaultMaxPendingBatches = 2;

  ConcurrencyStrategy copyWith({
    ExecutionMode? mode,
    int? parallelism,
    int? batchSize,
    int? maxPendingBatches,
  }) => ConcurrencyStrategy(
    mode: mode ?? this.mode,
    parallelism: parallelism ?? this.parallelism,
    batchSize: batchSize ?? this.batchSize,
    maxPendingBatches: maxPendingBatches ?? this.maxPendingBatches,
  );

  @override
  bool operator ==(Object other) =>
      other is ConcurrencyStrategy &&
      other.mode == mode &&
      other.parallelism == parallelism &&
      other.batchSize == batchSize &&
      other.maxPendingBatches == maxPendingBatches;

  @override
  int get hashCode =>
      Object.hash(mode, parallelism, batchSize, maxPendingBatches);

  @override
  String toString() =>
      'ConcurrencyStrategy(${mode.name}, parallelism: $parallelism, '
      'batch: $batchSize, pending: $maxPendingBatches)';
}
