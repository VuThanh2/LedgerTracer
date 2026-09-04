import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/core/concurrency/cancellation_signal.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/concurrency/progress_report.dart';
import 'package:ledger_tracer/core/concurrency/strategy_selector.dart';

void main() {
  group('CancellationSignal', () {
    test('bắt đầu ở trạng thái chưa huỷ', () {
      expect(CancellationSignal().isCancelled, isFalse);
    });

    test('huỷ là một chiều và không bao giờ quay lại', () {
      final signal = CancellationSignal()..cancel();
      expect(signal.isCancelled, isTrue);
    });

    test('gọi cancel nhiều lần cũng như gọi một lần', () {
      // Nút Huỷ bấm hai lần không được làm nổ chương trình.
      final signal = CancellationSignal();
      expect(() => signal..cancel()..cancel()..cancel(), returnsNormally);
      expect(signal.isCancelled, isTrue);
    });

    test('whenCancelled hoàn tất khi có yêu cầu huỷ', () async {
      final signal = CancellationSignal();
      var notified = false;
      unawaited(signal.whenCancelled.then((_) => notified = true));
      expect(notified, isFalse);
      signal.cancel();
      await signal.whenCancelled;
      expect(notified, isTrue);
    });

    test('whenCancelled của tín hiệu đã huỷ hoàn tất ngay', () async {
      await CancellationSignal.cancelled().whenCancelled;
    });

    test('throwIfCancelled im lặng khi chưa huỷ và ném khi đã huỷ', () {
      expect(() => CancellationSignal().throwIfCancelled(), returnsNormally);
      expect(
        () => CancellationSignal.cancelled().throwIfCancelled(),
        throwsA(isA<CancellationException>()),
      );
    });

    test('mỗi tín hiệu độc lập với nhau', () {
      final a = CancellationSignal();
      final b = CancellationSignal()..cancel();
      expect(a.isCancelled, isFalse);
      expect(b.isCancelled, isTrue);
    });
  });

  group('ConcurrencyStrategy', () {
    test('từ chối tham số vô nghĩa', () {
      expect(
        () => ConcurrencyStrategy(
          mode: ExecutionMode.isolate,
          parallelism: 0,
          batchSize: 10,
          maxPendingBatches: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConcurrencyStrategy(
          mode: ExecutionMode.isolate,
          parallelism: 1,
          batchSize: 0,
          maxPendingBatches: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => ConcurrencyStrategy(
          mode: ExecutionMode.isolate,
          parallelism: 1,
          batchSize: 10,
          maxPendingBatches: 0,
        ),
        throwsArgumentError,
      );
    });

    test('luồng chính luôn là một worker và một lô chờ', () {
      // Không có chỗ nào để chạy song song, và không có hàng đợi nào để giữ.
      final strategy = ConcurrencyStrategy.mainThread();
      expect(strategy.mode, ExecutionMode.mainThread);
      expect(strategy.parallelism, 1);
      expect(strategy.maxPendingBatches, 1);
      expect(strategy.mode.isBackground, isFalse);
    });

    test('một isolate là chế độ nền với đúng một worker', () {
      final strategy = ConcurrencyStrategy.singleIsolate();
      expect(strategy.mode, ExecutionMode.isolate);
      expect(strategy.parallelism, 1);
      expect(strategy.mode.isBackground, isTrue);
    });

    test('lô quét lớn hơn lô nhập vì mỗi dòng rẻ hơn nhiều', () {
      expect(
        ConcurrencyStrategy.defaultScanBatchSize,
        greaterThan(ConcurrencyStrategy.defaultImportBatchSize),
      );
    });

    test('copyWith đổi đúng phần được nêu', () {
      final base = ConcurrencyStrategy.parallelIsolates(parallelism: 4);
      final adapted = base.copyWith(mode: ExecutionMode.mainThread);
      expect(adapted.mode, ExecutionMode.mainThread);
      expect(adapted.parallelism, 4);
      expect(adapted.batchSize, base.batchSize);
    });

    test('copyWith vẫn kiểm tra tính hợp lệ', () {
      expect(
        () => ConcurrencyStrategy.mainThread().copyWith(parallelism: 0),
        throwsArgumentError,
      );
    });

    test('đẳng thức theo toàn bộ bốn tham số', () {
      expect(
        ConcurrencyStrategy.parallelIsolates(parallelism: 2),
        ConcurrencyStrategy.parallelIsolates(parallelism: 2),
      );
      expect(
        ConcurrencyStrategy.parallelIsolates(parallelism: 2).hashCode,
        ConcurrencyStrategy.parallelIsolates(parallelism: 2).hashCode,
      );
      expect(
        ConcurrencyStrategy.parallelIsolates(parallelism: 2),
        isNot(ConcurrencyStrategy.parallelIsolates(parallelism: 3)),
      );
    });
  });

  group('PlatformCapabilities', () {
    test('Web không có isolate và chỉ một luồng', () {
      const web = PlatformCapabilities.web();
      expect(web.supportsIsolates, isFalse);
      expect(web.processorCount, 1);
      expect(web.recommendedParallelism, 1);
    });

    test('native dùng số nhân nhưng chặn trên ở ngưỡng hữu ích', () {
      // Thêm worker quá ngưỡng chỉ tốn bộ nhớ mà không nhanh thêm, vì khâu ghi
      // vốn đã tuần tự.
      expect(
        const PlatformCapabilities.native(processorCount: 2).recommendedParallelism,
        2,
      );
      expect(
        const PlatformCapabilities.native(processorCount: 16).recommendedParallelism,
        PlatformCapabilities.maxUsefulParallelism,
      );
    });

    test('luôn có ít nhất một nhân', () {
      expect(
        () => PlatformCapabilities(supportsIsolates: true, processorCount: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('StrategySelector', () {
    const native = PlatformCapabilities.native(processorCount: 8);
    const web = PlatformCapabilities.web();

    group('trên native', () {
      const selector = StrategySelector(native);

      test('nhập một file thì chỉ cần một worker', () {
        // Không có gì để song song hoá khi chỉ có một file.
        final strategy = selector.forStatementImport(fileCount: 1);
        expect(strategy.mode, ExecutionMode.isolate);
        expect(strategy.parallelism, 1);
      });

      test('nhập nhiều file thì mở thêm worker, tối đa theo ngưỡng nền tảng', () {
        expect(selector.forStatementImport(fileCount: 3).parallelism, 3);
        expect(
          selector.forStatementImport(fileCount: 50).parallelism,
          native.recommendedParallelism,
        );
      });

      test('không có file nào vẫn cho ra chiến lược hợp lệ', () {
        expect(selector.forStatementImport(fileCount: 0).parallelism, 1);
      });

      test('quét đối soát là một isolate — một lần duyệt trên toàn bảng', () {
        final strategy = selector.forReconciliationScan();
        expect(strategy.mode, ExecutionMode.isolate);
        expect(strategy.parallelism, 1);
      });

      test('mã hoá file cũng là một isolate chạy một lần', () {
        expect(selector.forFileEncoding().mode, ExecutionMode.isolate);
      });

      test('adapt giữ nguyên chiến lược dùng isolate', () {
        final requested = ConcurrencyStrategy.parallelIsolates(parallelism: 4);
        expect(selector.adapt(requested), requested);
      });
    });

    group('trên Web', () {
      const selector = StrategySelector(web);

      test('mọi chính sách đều suy biến về luồng chính', () {
        expect(
          selector.forStatementImport(fileCount: 5).mode,
          ExecutionMode.mainThread,
        );
        expect(selector.forReconciliationScan().mode, ExecutionMode.mainThread);
        expect(selector.forFileEncoding().mode, ExecutionMode.mainThread);
      });

      test('nhập nhiều file cũng chỉ có một worker — các file chạy nối tiếp', () {
        // Đây là chiều suy biến thứ hai của UC-14: mất song song làm tổng thời
        // gian dài hơn, khác với việc mất isolate làm giao diện kém mượt.
        expect(selector.forStatementImport(fileCount: 5).parallelism, 1);
      });

      test('adapt hạ chiến lược isolate được truyền vào về luồng chính', () {
        final adapted = selector.adapt(
          ConcurrencyStrategy.parallelIsolates(parallelism: 4),
        );
        expect(adapted.mode, ExecutionMode.mainThread);
        expect(adapted.parallelism, 1);
        expect(adapted.maxPendingBatches, 1);
      });

      test('adapt giữ nguyên kích thước lô đã yêu cầu', () {
        // Kích thước lô là tham số đo đạc; suy biến nền tảng không được đổi nó,
        // nếu không phép so sánh trong báo cáo mất ý nghĩa.
        final adapted = selector.adapt(
          ConcurrencyStrategy.parallelIsolates(parallelism: 4, batchSize: 137),
        );
        expect(adapted.batchSize, 137);
      });

      test('adapt không đụng tới chiến lược vốn đã là luồng chính', () {
        final requested = ConcurrencyStrategy.mainThread(batchSize: 50);
        expect(selector.adapt(requested), requested);
      });
    });
  });

  group('ProgressReport', () {
    test('không có tổng thì không có tỷ lệ', () {
      const report = ProgressReport(processed: 10);
      expect(report.isDeterminate, isFalse);
      expect(report.fraction, isNull);
    });

    test('tổng bằng 0 cũng không cho tỷ lệ, không chia cho 0', () {
      const report = ProgressReport(processed: 0, total: 0);
      expect(report.isDeterminate, isFalse);
      expect(report.fraction, isNull);
    });

    test('tính tỷ lệ khi biết tổng', () {
      expect(const ProgressReport(processed: 25, total: 100).fraction, 0.25);
    });

    test('chặn trên ở 1 khi ước lượng tổng bị hụt', () {
      // Tổng chỉ là ước lượng; thanh tiến trình không được vượt quá 100%.
      expect(const ProgressReport(processed: 150, total: 100).fraction, 1);
    });

    test('từ chối số dòng đã xử lý âm', () {
      expect(
        () => ProgressReport(processed: -1),
        throwsA(isA<AssertionError>()),
      );
    });

    test('đẳng thức theo nội dung', () {
      expect(
        const ProgressReport(processed: 1, total: 2, workloadId: 'a'),
        const ProgressReport(processed: 1, total: 2, workloadId: 'a'),
      );
    });
  });
}
