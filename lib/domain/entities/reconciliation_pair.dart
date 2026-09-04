import '../errors/reconciliation_errors.dart';
import '../value_objects/pair_status.dart';

/// Hai giao dịch được nhận ra là hai vế của cùng một lần chuyển tiền nội bộ: vế
/// chuyển ra ở một tài khoản, vế nhận vào ở tài khoản khác (UC-08, UC-09).
///
/// Việc hai giao dịch *có được phép* ghép hay không do đúng một nơi quyết định
/// là `MatchPredicate` — cũng chính nó dựng ra entity này, để lần quét theo lô
/// và danh sách ứng viên hiển thị trên màn hình không bao giờ lệch nhau
/// (Rule – Suggested Is Not Confirmed).
final class ReconciliationPair {
  const ReconciliationPair({
    this.pairId,
    required this.outgoingTransactionId,
    required this.incomingTransactionId,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  /// Một đề xuất của máy, chưa ảnh hưởng tới bất kỳ con số nào cho tới khi người
  /// dùng xác nhận. Ném [SelfPairError] nếu hai vế là cùng một giao dịch.
  factory ReconciliationPair.suggested({
    required int outgoingTransactionId,
    required int incomingTransactionId,
    required DateTime createdAt,
  }) {
    if (outgoingTransactionId == incomingTransactionId) {
      throw SelfPairError(outgoingTransactionId);
    }
    return ReconciliationPair(
      outgoingTransactionId: outgoingTransactionId,
      incomingTransactionId: incomingTransactionId,
      status: PairStatus.suggested,
      createdAt: createdAt,
    );
  }

  final int? pairId;

  /// Vế có số tiền âm.
  final int outgoingTransactionId;

  /// Vế có số tiền dương.
  final int incomingTransactionId;

  final PairStatus status;

  final DateTime createdAt;

  final DateTime? confirmedAt;

  bool get isPersisted => pairId != null;

  bool get isConfirmed => status == PairStatus.confirmed;

  bool involves(int transactionId) =>
      transactionId == outgoingTransactionId ||
      transactionId == incomingTransactionId;

  /// Hai định danh giao dịch, dùng khi xoá dây chuyền (UC-01, UC-03, UC-05).
  List<int> get transactionIds => <int>[
    outgoingTransactionId,
    incomingTransactionId,
  ];

  ReconciliationPair withIdentity(int id) => ReconciliationPair(
    pairId: id,
    outgoingTransactionId: outgoingTransactionId,
    incomingTransactionId: incomingTransactionId,
    status: status,
    createdAt: createdAt,
    confirmedAt: confirmedAt,
  );

  /// Người dùng chấp nhận cặp; từ đây nó bị loại khỏi dòng tiền với bên ngoài
  /// (UC-10) và sống sót qua các lần chạy lại đối soát (UC-08).
  ///
  /// Không có thao tác "bỏ xác nhận": đường lùi là **từ chối**, vốn xoá cặp và
  /// ghi lại một phán quyết riêng (UC-09).
  ///
  /// Ném [PairAlreadyConfirmedError] nếu cặp đã được xác nhận.
  ReconciliationPair confirm(DateTime at) {
    assert(isPersisted, 'Only a persisted pair can be confirmed.');
    if (isConfirmed) throw PairAlreadyConfirmedError(pairId!);
    return ReconciliationPair(
      pairId: pairId,
      outgoingTransactionId: outgoingTransactionId,
      incomingTransactionId: incomingTransactionId,
      status: PairStatus.confirmed,
      createdAt: createdAt,
      confirmedAt: at,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReconciliationPair &&
          other.pairId != null &&
          other.pairId == pairId);

  @override
  int get hashCode => pairId?.hashCode ?? identityHashCode(this);

  @override
  String toString() =>
      'ReconciliationPair($pairId, '
      '$outgoingTransactionId → $incomingTransactionId, $status)';
}
