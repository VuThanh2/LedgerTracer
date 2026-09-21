@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/application/diagnostics/probe_runtime/probe_runtime_dto.dart';
import 'package:ledger_tracer/application/diagnostics/probe_runtime/probe_runtime_use_case.dart';
import 'package:ledger_tracer/core/concurrency/concurrency_strategy.dart';
import 'package:ledger_tracer/core/concurrency/execution_mode.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner.dart';
import 'package:ledger_tracer/core/concurrency/isolate_runner_io.dart';
import 'package:ledger_tracer/core/concurrency/platform_capabilities.dart';
import 'package:ledger_tracer/core/result/result.dart';

void main() {
  const sampleSize = 40000;

  final native = ProbeRuntimeUseCase(
    runner: IsolateWorkloadRunner(
      const PlatformCapabilities.native(processorCount: 4),
    ),
  );
  final web = ProbeRuntimeUseCase(
    runner: const MainThreadRunner(PlatformCapabilities.web()),
  );

  T valueOf<T>(Result<T> result) => switch (result) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw TestFailure('probe failed: $failure'),
  };

  group('độ trễ huỷ', () {
    for (final (label, useCase, strategy)
        in <(String, ProbeRuntimeUseCase, ConcurrencyStrategy)>[
          (
            'isolate',
            native,
            ConcurrencyStrategy.singleIsolate(batchSize: 500),
          ),
          ('luồng chính', web, ConcurrencyStrategy.mainThread(batchSize: 500)),
        ]) {
      test('$label: dừng sớm, và chỉ lọt qua trong giới hạn vài lô', () async {
        final run = valueOf(
          await useCase.measureCancellation(
            sampleSize: sampleSize,
            strategy: strategy,
          ),
        );

        // Huỷ ở mốc một phần tư: không được chạy tới hết.
        expect(run.itemsAtCancel, greaterThanOrEqualTo(sampleSize ~/ 4));
        expect(run.itemsAtCancel + run.itemsAfterCancel, lessThan(sampleSize));
        // Phần lọt qua sau lệnh huỷ bị chặn bởi số lô được phép bay trên
        // đường, cộng lô đang tính dở — không phải phần còn lại của workload.
        expect(
          run.itemsAfterCancel,
          lessThanOrEqualTo(
            (strategy.maxPendingBatches + 1) * strategy.batchSize,
          ),
        );
        expect(run.latency, greaterThan(Duration.zero));
      });
    }
  });

  group('hàng đợi chờ ghi', () {
    final isolate = ConcurrencyStrategy.singleIsolate(batchSize: 500);

    test('có giới hạn: không vượt giới hạn + lô đang cầm trên tay', () async {
      final run = valueOf(
        await native.measureBackpressure(
          sampleSize: sampleSize,
          strategy: isolate,
          capped: true,
        ),
      );
      expect(run.isCapped, isTrue);
      expect(run.effectiveMode, ExecutionMode.isolate);
      expect(
        run.peakPendingBatches,
        lessThanOrEqualTo(isolate.maxPendingBatches + 1),
      );
    });

    test('bỏ giới hạn: các lô dồn lại vượt xa giới hạn', () async {
      final run = valueOf(
        await native.measureBackpressure(
          sampleSize: sampleSize,
          strategy: isolate,
          capped: false,
        ),
      );
      expect(run.isCapped, isFalse);
      // 80 lô, mỗi lần ghi 4ms, còn phân tích một lô chỉ tốn một phần nhỏ
      // của thời gian đó: bên phân tích bỏ xa bên ghi.
      expect(
        run.peakPendingBatches,
        greaterThan(isolate.maxPendingBatches + 1),
      );
      expect(run.producerFinishedAfter, lessThan(run.consumerFinishedAfter));
    });

    test('luồng chính: không bao giờ có hơn một lô nằm chờ (UC-14)', () async {
      final run = valueOf(
        await web.measureBackpressure(
          sampleSize: sampleSize,
          strategy: ConcurrencyStrategy.mainThread(batchSize: 500),
          capped: false,
        ),
      );
      expect(run.effectiveMode, ExecutionMode.mainThread);
      expect(run.peakPendingBatches, 1);
    });
  });

  group('peakPending', () {
    test('hai lô gửi liền trước khi lô đầu ghi xong là hai lô nằm chờ', () {
      expect(ProbeRuntimeUseCase.peakPending(<int>[0, 1], <int>[5, 9]), 2);
    });

    test('gửi – ghi xong – gửi thì không bao giờ quá một', () {
      expect(
        ProbeRuntimeUseCase.peakPending(<int>[0, 10, 20], <int>[5, 15, 25]),
        1,
      );
    });

    test('ghi xong đúng lúc lô sau được gửi không tính là hai lô', () {
      expect(ProbeRuntimeUseCase.peakPending(<int>[0, 5], <int>[5, 9]), 1);
    });

    test('không có lô nào thì không có gì nằm chờ', () {
      expect(ProbeRuntimeUseCase.peakPending(<int>[], <int>[]), 0);
    });
  });

  test('DTO quy đổi đúng ra số lô và số phần tử', () {
    final strategy = ConcurrencyStrategy.singleIsolate(batchSize: 500);
    final cancel = CancelProbeRun(
      strategy: strategy,
      effectiveMode: ExecutionMode.isolate,
      latency: const Duration(milliseconds: 3),
      itemsAtCancel: 10000,
      itemsAfterCancel: 750,
    );
    expect(cancel.batchesAfterCancel, 1.5);
    final backlog = BackpressureProbeRun(
      strategy: strategy,
      effectiveMode: ExecutionMode.isolate,
      isCapped: true,
      peakPendingBatches: 3,
      producerFinishedAfter: Duration.zero,
      consumerFinishedAfter: Duration.zero,
    );
    expect(backlog.peakPendingItems, 1500);
  });
}
