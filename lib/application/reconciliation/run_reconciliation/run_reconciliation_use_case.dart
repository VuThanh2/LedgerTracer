import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/concurrency/strategy_selector.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/value_objects/match_window.dart';
import '../../shared/domain_failures.dart';
import '../contracts/match_row.dart';
import '../contracts/pair_candidate.dart';
import '../mappers/match_row_mapper.dart';
import '../workloads/match_scan_workload.dart';
import 'run_reconciliation_dto.dart';

/// Chạy đối soát nội bộ: quét toàn bộ giao dịch chưa ghép để tìm các cặp chuyển
/// tiền giữa hai tài khoản của cùng tổ chức (UC-08).
///
/// Trình tự tôn trọng hai luật: chạy lại **xoá sạch gợi ý chưa xác nhận** rồi
/// tính lại từ đầu nhưng **giữ nguyên cặp đã xác nhận** (nếu không, chạy nhiều
/// lần sẽ tích luỹ gợi ý trùng); và cặp đã bị **từ chối** bị loại khỏi ứng viên,
/// không được gợi ý lại.
///
/// Việc quét là CPU thuần nên chạy trong một isolate. Cơ sở dữ liệu chỉ được
/// đọc/ghi từ luồng chính, nên tầng này làm ba việc quanh workload: nạp tập ứng
/// viên và **rút gọn ngay từng trang** thành [MatchRow] (giữ Entity lại chỉ để
/// copy sang isolate là trả giá bộ nhớ hai lần cho dữ liệu phép ghép không đọc
/// tới), dựng tập khoá từ chối, rồi ghi dần từng lô cặp trả về — huỷ giữa chừng
/// thì phần đã ghi vẫn giữ.
final class RunReconciliationUseCase {
  RunReconciliationUseCase({
    required this._reconciliation,
    required this._settings,
    required this._runner,
    required this._strategies,
    required this._now,
  });

  final ReconciliationRepository _reconciliation;
  final AppSettingsRepository _settings;
  final IsolateRunner _runner;
  final StrategySelector _strategies;
  final DateTime Function() _now;

  static const int _loadPageSize = 1000;

  Future<Result<RunReconciliationResult>> execute(
    RunReconciliationRequest request, {
    void Function(ReconciliationProgress progress)? onProgress,
  }) => Result.guardAsync(() async {
    final settings = await _settings.load();
    final window = settings.matchWindow;
    final strategy = _strategies.adapt(
      request.strategy ?? _strategies.forReconciliationScan(),
    );
    final mode = _runner.effectiveMode(strategy);

    // Xoá gợi ý cũ (giữ cặp đã xác nhận) trước khi nạp, để tập ứng viên phản ánh
    // đúng trạng thái vừa dọn chứ không kèm theo những dòng sắp được thả ra.
    final cleared = await _reconciliation.deleteSuggestedPairs();

    final expected = await _reconciliation.countUnpairedTransactions();
    var found = 0;
    onProgress?.call(
      ReconciliationProgress(
        processed: 0,
        total: expected,
        pairsFound: 0,
        mode: mode,
      ),
    );

    final rows = await _loadRows();
    final rejectedKeys = await _loadRejectedKeys();
    final createdAt = _now();

    await _runner.runWorkload<MatchScanInput, List<PairCandidate>>(
      entryPoint: matchScanWorkload,
      input: MatchScanInput(
        rows: rows,
        window: window,
        rejectedKeys: rejectedKeys,
        batchSize: strategy.batchSize,
      ),
      strategy: strategy,
      onOutput: (candidates) async {
        await _reconciliation.addPairs(<ReconciliationPair>[
          for (final candidate in candidates)
            MatchRowMapper.toPair(candidate, createdAt: createdAt),
        ]);
        found += candidates.length;
      },
      onProgress: onProgress == null
          ? null
          : (progress) => onProgress(
              ReconciliationProgress(
                processed: progress.processed,
                total: progress.total ?? rows.length,
                pairsFound: found,
                mode: mode,
              ),
            ),
      cancellation: request.cancellation,
    );

    return RunReconciliationResult(
      suggestedPairsFound: found,
      clearedSuggestions: cleared,
      scannedTransactionCount: rows.length,
      wasCancelled: request.cancellation?.isCancelled ?? false,
      mode: mode,
    );
  }, onError: failureFromError);

  /// Ngưỡng lệch thời gian hiện tại, để màn hình đối soát hiển thị và cho chỉnh
  /// (UC-08).
  Future<Result<MatchWindow>> currentMatchWindow() => Result.guardAsync(
    () async => (await _settings.load()).matchWindow,
    onError: failureFromError,
  );

  /// Đổi ngưỡng lệch. Chỉ ảnh hưởng lần chạy sau và **không** đụng tới cặp đã xác
  /// nhận — cửa sổ là tham số dò tìm, cặp đã xác nhận là phán quyết của người
  /// dùng (UC-08). Ném `InvalidMatchWindowError` nếu [days] nhỏ hơn 1.
  Future<Result<MatchWindow>> setMatchWindow(int days) =>
      Result.guardAsync(() async {
        final window = MatchWindow(days);
        final settings = await _settings.load();
        await _settings.save(settings.withMatchWindow(window));
        return window;
      }, onError: failureFromError);

  /// Nạp theo trang và rút gọn **ngay tại chỗ**: chỉ một trang Entity tồn tại
  /// cùng lúc, phần tích luỹ là các [MatchRow] gọn hơn nhiều lần.
  Future<List<MatchRow>> _loadRows() async {
    final rows = <MatchRow>[];
    var offset = 0;
    while (true) {
      final page = await _reconciliation.findUnpairedTransactions(
        limit: _loadPageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      rows.addAll(page.map(MatchRowMapper.toRow));
      if (page.length < _loadPageSize) break;
      offset += page.length;
    }
    return rows;
  }

  /// Nạp **toàn bộ** phán quyết từ chối, theo trang.
  ///
  /// Lấy hết thay vì lọc theo tập giao dịch đang quét là có chủ đích: bảng này
  /// nhỏ (mỗi dòng là một lần người dùng bấm từ chối), trong khi cách kia đòi
  /// dựng một danh sách định danh dài bằng cả tập ứng viên rồi nhét vào mệnh đề
  /// `IN` — vừa không lọt trần tham số của SQLite, vừa đắt hơn chính thứ nó
  /// định tiết kiệm. Khoá thừa trong tập chỉ là khoá không bao giờ được tra tới.
  Future<Set<String>> _loadRejectedKeys() async {
    final keys = <String>{};
    var offset = 0;
    while (true) {
      final page = await _reconciliation.findRejections(
        limit: _loadPageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      keys.addAll(page.map((rejection) => rejection.key));
      if (page.length < _loadPageSize) break;
      offset += page.length;
    }
    return keys;
  }
}
