import '../view_models/benchmark_view_model.dart';
import '../view_models/probe_view_models.dart';

/// Những gì xảy ra trên màn hình chẩn đoán — màn hình phục vụ phần thực nghiệm,
/// nằm ngoài Domain.
sealed class DiagnosticsEvent {
  const DiagnosticsEvent();
}

final class DiagnosticsStarted extends DiagnosticsEvent {
  const DiagnosticsStarted();
}

/// Đổi hình dạng workload đem ra đo.
final class DiagnosticsWorkloadSelected extends DiagnosticsEvent {
  const DiagnosticsWorkloadSelected(this.workload);

  final BenchmarkWorkload workload;
}

/// Đổi số phần tử của workload tổng hợp. Càng lớn chênh lệch giữa các chiến lược
/// càng rõ.
final class DiagnosticsSampleSizeChanged extends DiagnosticsEvent {
  const DiagnosticsSampleSizeChanged(this.sampleSize);

  final int sampleSize;
}

/// Đổi kích thước lô — núm vặn đánh đổi độ mịn của tiến trình và độ trễ của nút
/// Huỷ với chi phí đi qua ranh giới isolate.
final class DiagnosticsBatchSizeChanged extends DiagnosticsEvent {
  const DiagnosticsBatchSizeChanged(this.batchSize);

  final int batchSize;
}

final class DiagnosticsRunRequested extends DiagnosticsEvent {
  const DiagnosticsRunRequested();
}

final class DiagnosticsCleared extends DiagnosticsEvent {
  const DiagnosticsCleared();
}

/// Đổi phép đo: hiệu năng, độ trễ huỷ, hay hàng đợi chờ ghi.
final class DiagnosticsTestSelected extends DiagnosticsEvent {
  const DiagnosticsTestSelected(this.test);

  final DiagnosticsTest test;
}

/// Đổi số lần đo lặp cho mỗi cấu hình của bảng hiệu năng.
final class DiagnosticsRepeatsChanged extends DiagnosticsEvent {
  const DiagnosticsRepeatsChanged(this.repeats);

  final int repeats;
}
