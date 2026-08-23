import '../value_objects/import_session_status.dart';
import 'import_file_record.dart';

/// Một lượt nhập: nhóm file người dùng chọn cùng lúc (UC-02) và cũng là cách
/// chúng được gom nhóm trong lịch sử (UC-03).
///
/// Là aggregate root của các [fileRecords]. Dòng lỗi về khái niệm cũng thuộc
/// aggregate này, nhưng được nạp bằng truy vấn riêng: một file có thể sinh ra
/// hàng nghìn dòng lỗi và chúng chỉ cần tới lúc xuất file (UC-11).
final class ImportSession {
  const ImportSession({
    this.sessionId,
    required this.startedAt,
    this.completedAt,
    required this.status,
    this.fileRecords = const <ImportFileRecord>[],
  });

  factory ImportSession.started(DateTime startedAt) => ImportSession(
    startedAt: startedAt,
    status: ImportSessionStatus.inProgress,
  );

  final int? sessionId;

  final DateTime startedAt;

  /// Được đặt khi lượt nhập tới trạng thái cuối, dù hoàn tất hay bị huỷ.
  final DateTime? completedAt;

  final ImportSessionStatus status;

  /// Mỗi file một bản ghi, theo đúng thứ tự người dùng chọn — cũng là thứ tự mà
  /// giai đoạn ghi phải tuân theo (Rule – Write Order Is Deterministic).
  final List<ImportFileRecord> fileRecords;

  bool get isPersisted => sessionId != null;

  bool get isFinished => status != ImportSessionStatus.inProgress;

  int get importedCount =>
      fileRecords.fold(0, (total, record) => total + record.importedCount);

  int get duplicateSkippedCount => fileRecords.fold(
    0,
    (total, record) => total + record.duplicateSkippedCount,
  );

  int get errorRowCount =>
      fileRecords.fold(0, (total, record) => total + record.errorRowCount);

  /// Lượt nhập chỉ biến mất khỏi lịch sử khi không còn bản ghi con nào (UC-01);
  /// trước đó nó vẫn hiện, đã hoàn tác hay chưa (UC-03).
  bool get isFullyReverted =>
      fileRecords.isNotEmpty &&
      fileRecords.every((record) => record.isReverted);

  ImportSession withIdentity(int id) => _copyWith(sessionId: id);

  ImportSession withFileRecords(List<ImportFileRecord> records) =>
      _copyWith(fileRecords: List<ImportFileRecord>.unmodifiable(records));

  ImportSession complete(DateTime at) =>
      _copyWith(status: ImportSessionStatus.completed, completedAt: at);

  /// Người dùng huỷ giữa chừng; phần đã ghi vẫn giữ nguyên (UC-02 bước 7).
  ImportSession cancel(DateTime at) =>
      _copyWith(status: ImportSessionStatus.cancelled, completedAt: at);

  ImportSession _copyWith({
    int? sessionId,
    DateTime? completedAt,
    ImportSessionStatus? status,
    List<ImportFileRecord>? fileRecords,
  }) => ImportSession(
    sessionId: sessionId ?? this.sessionId,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    fileRecords: fileRecords ?? this.fileRecords,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportSession &&
          other.sessionId != null &&
          other.sessionId == sessionId);

  @override
  int get hashCode => sessionId?.hashCode ?? identityHashCode(this);

  @override
  String toString() =>
      'ImportSession($sessionId, $status, '
      '${fileRecords.length} file(s))';
}
