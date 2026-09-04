import 'package:flutter/scheduler.dart';

/// Thống kê thời gian dựng khung hình trong một quãng đo.
final class FrameTimingStats {
  const FrameTimingStats({
    required this.frameCount,
    required this.averageMillis,
    required this.p95Millis,
    required this.worstMillis,
    required this.jankyFrameCount,
  });

  static const FrameTimingStats empty = FrameTimingStats(
    frameCount: 0,
    averageMillis: 0,
    p95Millis: 0,
    worstMillis: 0,
    jankyFrameCount: 0,
  );

  final int frameCount;
  final double averageMillis;

  /// Phân vị 95 — con số nói đúng cảm giác giật hơn giá trị trung bình, vì giật
  /// là chuyện của **những khung hình tệ nhất**, không phải của khung trung bình.
  final double p95Millis;

  final double worstMillis;

  /// Số khung hình vượt ngân sách 16.7ms của màn hình 60Hz.
  final int jankyFrameCount;

  double get jankyRatio => frameCount == 0 ? 0 : jankyFrameCount / frameCount;
}

/// Đo thời gian dựng khung hình trong lúc một workload chạy.
///
/// ## Vì sao phép đo này nằm ở tầng Presentation
///
/// `RunBenchmarkUseCase` đo được **tổng thời gian** của một lượt chạy, và đó là
/// một trong hai hệ quả của việc mất isolate trên Web. Hệ quả còn lại — giao
/// diện giật — không đo được ở đó, vì nó không phải tính chất của workload mà là
/// tính chất của **luồng đang vẽ**. Chỉ tầng có Flutter binding mới quan sát
/// được nó.
///
/// Đây chính là điểm phân tích mà phần thực nghiệm xoay quanh: hai chế độ chạy
/// không khác nhau ở "nhanh" và "chậm" mà khác nhau ở **cái giá phải trả**. Chạy
/// trên luồng chính có khi cho tổng thời gian tương đương, nhưng khung hình thì
/// tắc — và chỉ có bảng số dưới đây nói ra được điều đó.
final class FrameTimingRecorder {
  /// [binding] chỉ để test truyền vào một binding dựng tay; ứng dụng thật để
  /// trống và dùng binding đang chạy.
  FrameTimingRecorder({this.binding});

  final SchedulerBinding? binding;

  final List<double> _buildMillis = <double>[];

  bool _isRecording = false;

  /// Ngân sách một khung hình ở 60Hz.
  static const double frameBudgetMillis = 1000 / 60;

  SchedulerBinding? get _scheduler => binding ?? SchedulerBinding.instance;

  void start() {
    if (_isRecording) return;
    _buildMillis.clear();
    _isRecording = true;
    _scheduler?.addTimingsCallback(_onTimings);
  }

  FrameTimingStats stop() {
    if (!_isRecording) return FrameTimingStats.empty;
    _isRecording = false;
    _scheduler?.removeTimingsCallback(_onTimings);
    return _statsOf(_buildMillis);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (final timing in timings) {
      // `totalSpan` là quãng từ lúc khung hình được yêu cầu tới lúc nó lên màn
      // hình — nó bao gồm cả phần **chờ** vì luồng chính đang bận, và phần chờ
      // ấy mới đúng là thứ cần đo ở đây. Chỉ đo `buildDuration` sẽ bỏ sót đúng
      // hiện tượng đang khảo sát.
      _buildMillis.add(timing.totalSpan.inMicroseconds / 1000);
    }
  }

  static FrameTimingStats _statsOf(List<double> samples) {
    if (samples.isEmpty) return FrameTimingStats.empty;
    final sorted = <double>[...samples]..sort();

    var sum = 0.0;
    var janky = 0;
    for (final value in sorted) {
      sum += value;
      if (value > frameBudgetMillis) janky++;
    }

    final p95Index = ((sorted.length - 1) * 0.95).round();
    return FrameTimingStats(
      frameCount: sorted.length,
      averageMillis: sum / sorted.length,
      p95Millis: sorted[p95Index],
      worstMillis: sorted.last,
      jankyFrameCount: janky,
    );
  }
}
