import '../../../application/reconciliation/list_match_alternatives/list_match_alternatives_dto.dart';
import '../../../domain/entities/transaction.dart';
import '../../../domain/value_objects/pair_status.dart';
import '../../shared/formatting/date_formatter.dart';
import '../../shared/formatting/money_formatter.dart';

/// Một vế của cặp, đã thành chữ.
final class PairSideViewModel {
  const PairSideViewModel({
    required this.transactionId,
    required this.accountName,
    required this.dateText,
    required this.amountText,
    required this.counterpartyText,
    required this.descriptionText,
    required this.sourceLineText,
  });

  factory PairSideViewModel.of(Transaction tx, String accountName) =>
      PairSideViewModel(
        transactionId: tx.transactionId!,
        accountName: accountName,
        dateText: DateFormatter.day(tx.bookingDate),
        amountText: MoneyFormatter.signedWithCurrency(tx.amount),
        counterpartyText: tx.counterpartyName ?? '',
        descriptionText: tx.description,
        // Số dòng trong file gốc là thứ cho phép người dùng mở sao kê ra tự đối
        // chiếu trước khi xác nhận — nó có mặt ở Pair Detail vì đúng lúc đó họ
        // mới cần (UC-09 bước 2).
        sourceLineText: tx.sourceLineNumber?.toString() ?? '—',
      );

  final int transactionId;
  final String accountName;
  final String dateText;
  final String amountText;
  final String counterpartyText;
  final String descriptionText;
  final String sourceLineText;
}

/// Một dòng trong danh sách cặp đối soát (UC-09 bước 1).
final class PairRowViewModel {
  const PairRowViewModel({
    required this.pairId,
    required this.status,
    required this.amountText,
    required this.driftText,
    required this.outgoing,
    required this.incoming,
  });

  factory PairRowViewModel.of(PairView view) => PairRowViewModel(
    pairId: view.pair.pairId!,
    status: view.pair.status,
    // Số tiền của một cặp in **không dấu**: hai vế luôn đối dấu nhau, nên một
    // dấu ở đây chỉ đặt ra câu hỏi "dấu của vế nào".
    amountText: MoneyFormatter.absoluteWithCurrency(view.incoming.amount),
    driftText: _driftTextOf(view.driftInDays),
    outgoing: PairSideViewModel.of(view.outgoing, view.outgoingAccountName),
    incoming: PairSideViewModel.of(view.incoming, view.incomingAccountName),
  );

  final int pairId;

  final PairStatus status;

  final String amountText;

  /// Độ lệch thời gian giữa hai vế — con số quyết định khi người dùng phải chọn
  /// giữa nhiều ứng viên (UC-09 bước 2).
  final String driftText;

  /// Vế chuyển ra (số tiền âm).
  final PairSideViewModel outgoing;

  /// Vế nhận vào (số tiền dương).
  final PairSideViewModel incoming;

  static String _driftTextOf(int days) =>
      days == 0 ? 'Cùng ngày' : 'Lệch $days ngày';
}

/// Một cặp đang mở, kèm các ứng viên ghép thay thế của từng vế (UC-09 bước 2).
///
/// Ứng viên thay thế được **tính lại lúc hiển thị** bằng chính điều kiện ghép
/// cặp mà lần quét dùng, nên một ứng viên không bao giờ hiện ở đây mà vắng ở lần
/// chạy sau.
final class PairDetailViewModel {
  const PairDetailViewModel({
    required this.pair,
    required this.alternativesForOutgoing,
    required this.alternativesForIncoming,
  });

  factory PairDetailViewModel.of(
    MatchAlternativesView view, {
    required Map<int, String> accountNames,
  }) => PairDetailViewModel(
    pair: PairRowViewModel.of(view.pair),
    alternativesForOutgoing: <PairSideViewModel>[
      for (final tx in view.alternativesForOutgoing)
        PairSideViewModel.of(tx, accountNames[tx.accountId] ?? ''),
    ],
    alternativesForIncoming: <PairSideViewModel>[
      for (final tx in view.alternativesForIncoming)
        PairSideViewModel.of(tx, accountNames[tx.accountId] ?? ''),
    ],
  );

  final PairRowViewModel pair;

  /// Ứng viên nhận vào khác cho vế chuyển ra.
  final List<PairSideViewModel> alternativesForOutgoing;

  /// Ứng viên chuyển ra khác cho vế nhận vào.
  final List<PairSideViewModel> alternativesForIncoming;

  bool get hasAlternatives =>
      alternativesForOutgoing.isNotEmpty || alternativesForIncoming.isNotEmpty;
}

/// Một dòng trong nhóm "Đã từ chối" (UC-09 bước 5).
final class RejectedRowViewModel {
  const RejectedRowViewModel({
    required this.rejectedMatchId,
    required this.rejectedAtText,
    required this.summaryText,
    this.sideA,
    this.sideB,
  });

  factory RejectedRowViewModel.of(
    RejectedView view, {
    required Map<int, String> accountNames,
  }) {
    final a = view.transactionA;
    final b = view.transactionB;
    return RejectedRowViewModel(
      rejectedMatchId: view.rejection.rejectedMatchId!,
      rejectedAtText: DateFormatter.dayTime(view.rejection.rejectedAt),
      summaryText: a == null || b == null
          // Một vế đã bị xoá ở đường khác. Phán quyết vẫn còn và vẫn gỡ được,
          // nên nó vẫn hiện — chỉ là không còn hai vế để đối chiếu.
          ? 'Một trong hai giao dịch không còn tồn tại.'
          : '${MoneyFormatter.absoluteWithCurrency(b.amount)} · '
                '${DateFormatter.day(a.bookingDate)}',
      sideA: a == null
          ? null
          : PairSideViewModel.of(a, accountNames[a.accountId] ?? ''),
      sideB: b == null
          ? null
          : PairSideViewModel.of(b, accountNames[b.accountId] ?? ''),
    );
  }

  final int rejectedMatchId;
  final String rejectedAtText;

  /// Một dòng tóm tắt để nhận ra phán quyết mình vừa bấm nhầm.
  final String summaryText;

  final PairSideViewModel? sideA;
  final PairSideViewModel? sideB;

  bool get isComplete => sideA != null && sideB != null;
}
