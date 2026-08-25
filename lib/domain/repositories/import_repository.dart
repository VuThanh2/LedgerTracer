import '../entities/import_error_row.dart';
import '../entities/import_file_record.dart';
import '../entities/import_session.dart';

/// Cổng lưu trữ của aggregate ImportSession (UC-02, UC-03).
///
/// Việc xoá các giao dịch mà một lượt nhập đã ghi là của TransactionRepository;
/// cổng này chỉ sở hữu phần lịch sử của chính lượt nhập.
///
/// **Hợp đồng về `fileRecords`:** mọi phương thức trả về [ImportSession] đều
/// phải trả kèm **đầy đủ** các bản ghi file con của nó, sắp theo `orderIndex`.
/// Đây là ràng buộc bắt buộc chứ không phải tối ưu: hoàn tác cả một lượt được
/// định nghĩa là lần lượt hoàn tác từng bản ghi con (UC-03), nên một cài đặt trả
/// về danh sách rỗng sẽ khiến thao tác hoàn tác im lặng không làm gì cả.
abstract interface class ImportRepository {
  /// Mở một lượt nhập và trả về kèm định danh — các bản ghi file cần nó trước
  /// khi dòng đầu tiên được ghi.
  Future<ImportSession> addSession(ImportSession session);

  /// Lưu trạng thái cuối của một lượt (hoàn tất hoặc bị huỷ).
  Future<void> updateSession(ImportSession session);

  /// Các lượt nhập từ gần nhất, mỗi lượt kèm bản ghi file của nó — chính là
  /// lịch sử gom nhóm ở UC-03. Dòng lỗi không đi kèm ở đây; chúng được nạp theo
  /// từng bản ghi khi cần xuất file.
  Future<List<ImportSession>> findSessions({
    required int limit,
    required int offset,
  });

  Future<int> countSessions();

  /// Một lượt nhập kèm đầy đủ bản ghi file con — xem hợp đồng ở đầu lớp.
  Future<ImportSession?> findSessionById(int sessionId);

  /// Xoá các lượt nhập không còn bản ghi con nào — lượt nhập chỉ biến mất khi đó
  /// (UC-01).
  Future<int> deleteEmptySessions();

  /// Mở bản ghi của một file và trả về kèm định danh, thứ mà mọi giao dịch của
  /// file đó sẽ trỏ về (Rule – Provenance Is What Makes Undo Possible).
  Future<ImportFileRecord> addFileRecord(ImportFileRecord record);

  /// Lưu bộ đếm, trạng thái cuối, hoặc dấu đã hoàn tác của một file.
  ///
  /// Ném `ImportFileRecordNotFoundError` nếu bản ghi không còn tồn tại.
  Future<void> updateFileRecord(ImportFileRecord record);

  Future<ImportFileRecord?> findFileRecordById(int recordId);

  /// Các bản ghi nhập có tài khoản đích là tài khoản này — chúng bị xoá cùng
  /// tài khoản (UC-01).
  Future<List<ImportFileRecord>> findFileRecordsByAccountId(int accountId);

  Future<void> deleteFileRecordById(int recordId);

  /// Lưu các dòng không đọc được (UC-02); chúng cũng được ghi theo lô như giao
  /// dịch.
  Future<void> addErrorRows(List<ImportErrorRow> rows);

  /// Dòng lỗi của một file, theo thứ tự dòng gốc, để xuất lại được cả khi màn
  /// hình tổng kết đã đóng từ lâu (UC-03, UC-11).
  Future<List<ImportErrorRow>> findErrorRows(int recordId);
}
