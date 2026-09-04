import 'concurrency_strategy.dart';
import 'execution_mode.dart';
import 'platform_capabilities.dart';

/// Biến "nền tảng này làm được gì" thành "chúng ta sẽ làm thế nào".
///
/// Là nơi **duy nhất** capabilities trở thành strategy. Mọi chỗ khác chỉ nhận
/// một [ConcurrencyStrategy], nhờ vậy màn hình benchmark có thể phát ra strategy
/// của riêng nó mà không code nào khác phải biết.
final class StrategySelector {
  const StrategySelector(this.capabilities);

  final PlatformCapabilities capabilities;

  /// Nhập sao kê: nhiều file, mỗi file phân tích riêng, tất cả do một luồng
  /// chính ghi xuống (UC-02).
  ///
  /// Số worker không bao giờ vượt số file — một worker không có file để đọc chỉ
  /// tốn một lần spawn mà chẳng đem lại gì.
  ConcurrencyStrategy forStatementImport({required int fileCount}) {
    if (!capabilities.supportsIsolates) {
      return ConcurrencyStrategy.mainThread();
    }
    final workers = fileCount < 1 ? 1 : fileCount;
    return ConcurrencyStrategy.parallelIsolates(
      parallelism: workers < capabilities.recommendedParallelism
          ? workers
          : capabilities.recommendedParallelism,
    );
  }

  /// Đối soát: một lượt duyệt trên các giao dịch chưa ghép (UC-08).
  ///
  /// Cố ý một worker — đây là một lần quét không chia được trên một bảng, không
  /// phải N file độc lập, nên workload thứ hai của báo cáo khác workload thứ
  /// nhất về **bản chất** (CPU thuần) chứ không phải về kích thước.
  ConcurrencyStrategy forReconciliationScan() => capabilities.supportsIsolates
      ? ConcurrencyStrategy.singleIsolate()
      : ConcurrencyStrategy.mainThread(
          batchSize: ConcurrencyStrategy.defaultScanBatchSize,
        );

  /// Hạ một strategy chọn tay — của màn hình benchmark — xuống mức nền tảng đáp
  /// ứng được, mà không đụng tới những núm vặn vẫn còn hợp lệ.
  ///
  /// Cố ý **không** chặn [ConcurrencyStrategy.parallelism] hay kích thước lô: đo
  /// một cấu hình cố tình tệ chính là mục đích của phần thực nghiệm.
  /// Chính sách cho khâu mã hoá một file xuất hoặc file sao lưu (UC-11, UC-13).
  ///
  /// Một tác vụ CPU chạy đúng một lần trên dữ liệu đã nạp sẵn, không có tiến
  /// trình theo lô — nên một isolate là đủ và [ConcurrencyStrategy.batchSize]
  /// ở đây không mang ý nghĩa gì ngoài giá trị mặc định.
  ConcurrencyStrategy forFileEncoding() => capabilities.supportsIsolates
      ? ConcurrencyStrategy.singleIsolate()
      : ConcurrencyStrategy.mainThread();

  ConcurrencyStrategy adapt(ConcurrencyStrategy requested) {
    if (requested.mode == ExecutionMode.isolate &&
        !capabilities.supportsIsolates) {
      return requested.copyWith(
        mode: ExecutionMode.mainThread,
        parallelism: 1,
        maxPendingBatches: 1,
      );
    }
    return requested;
  }
}
