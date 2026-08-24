import '../../../core/concurrency/isolate_runner.dart';
import '../../../core/result/result.dart';
import '../../../domain/entities/reconciliation_pair.dart';
import '../../../domain/entities/rejected_match.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/repositories/reconciliation_repository.dart';
import '../../../domain/value_objects/match_window.dart';
import '../../shared/domain_failures.dart';
import '../workloads/match_scan_workload.dart';
import 'run_reconciliation_dto.dart';

/// Chạy đối soát nội bộ: quét toàn bộ giao dịch chưa ghép để tìm các cặp chuyển
/// tiền giữa hai tài khoản của cùng tổ chức (UC-08).
///
/// Trình tự tôn trọng hai luật: chạy lại **xoá sạch gợi ý chưa xác nhận** rồi
/// tính lại từ đầu nhưng **giữ nguyên cặp đã xác nhận** (nếu không, chạy nhiều
/// lần sẽ tích luỹ gợi ý trùng); và cặp đã bị **từ chối** bị loại khỏi ứng viên,
/// không được gợi ý lại. Việc quét là CPU thuần nên chạy trong một isolate; kết
/// quả về theo lô và được ghi dần, huỷ giữa chừng thì phần đã ghi vẫn giữ.
final class RunReconciliationUseCase {
  RunReconciliationUseCase({
    required this._reconciliation,
    required this._settings,
    required this._runner,
    required this._now,
  });

  final ReconciliationRepository _reconciliation;
  final AppSettingsRepository _settings;
  final IsolateRunner _runner;
  final DateTime Function() _now;

  static const int _loadPageSize = 1000;

  Future<Result<RunReconciliationResult>> execute(
    RunReconciliationRequest request,
  ) => Result.guardAsync(() async {
    final settings = await _settings.load();
    final window = settings.matchWindow;

    // Xoá gợi ý cũ (giữ cặp đã xác nhận), rồi nạp tập ứng viên và các phán quyết
    // từ chối dính tới nó.
    final cleared = await _reconciliation.deleteSuggestedPairs();
    final unpaired = await _loadUnpaired();
    final rejections = await _loadRejections(unpaired);

    final mode = _runner.effectiveMode(request.strategy);
    var found = 0;
    await _runner.runWorkload<MatchScanInput, List<ReconciliationPair>>(
      entryPoint: matchScanWorkload,
      input: MatchScanInput(
        transactions: unpaired,
        window: window,
        rejections: rejections,
        createdAt: _now(),
        batchSize: request.strategy.batchSize,
      ),
      strategy: request.strategy,
      onOutput: (pairs) async {
        await _reconciliation.addPairs(pairs);
        found += pairs.length;
      },
      cancellation: request.cancellation,
    );

    return RunReconciliationResult(
      suggestedPairsFound: found,
      clearedSuggestions: cleared,
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
  /// dùng (UC-08). Ném [InvalidMatchWindowError] nếu [days] nhỏ hơn 1.
  Future<Result<MatchWindow>> setMatchWindow(int days) =>
      Result.guardAsync(() async {
        final window = MatchWindow(days);
        final settings = await _settings.load();
        await _settings.save(settings.withMatchWindow(window));
        return window;
      }, onError: failureFromError);

  Future<List<Transaction>> _loadUnpaired() async {
    final all = <Transaction>[];
    var offset = 0;
    while (true) {
      final page = await _reconciliation.findUnpairedTransactions(
        limit: _loadPageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      all.addAll(page);
      if (page.length < _loadPageSize) break;
      offset += page.length;
    }
    return all;
  }

  Future<List<RejectedMatch>> _loadRejections(
    List<Transaction> transactions,
  ) async {
    final ids = <int>[
      for (final tx in transactions)
        if (tx.transactionId != null) tx.transactionId!,
    ];
    if (ids.isEmpty) return const <RejectedMatch>[];
    return _reconciliation.findRejectionsInvolving(ids);
  }
}
