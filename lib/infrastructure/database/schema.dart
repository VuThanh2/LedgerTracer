/// Hình dạng vật lý của cơ sở dữ liệu SQLite cục bộ — nơi **duy nhất** giữ
/// source of truth của ứng dụng (Rule – Single Context Is an Architectural
/// Consequence).
///
/// Toàn bộ DDL nằm gọn ở đây thay vì rải trong từng repository, vì tên cột và
/// chỉ mục là thứ mọi repository phải đồng ý với nhau: một cột đổi tên ở một chỗ
/// mà không đổi ở chỗ kia chỉ đổ vỡ lúc chạy, và chỉ với đúng dữ liệu chạm vào
/// truy vấn đó.
///
/// ## Quy ước kiểu dữ liệu
///
/// * **Ngày ghi nhận** (`booking_date`) lưu dạng chuỗi `YYYY-MM-DD`. Nó vốn chỉ
///   mang ngày và đã được `DateRange.dateOnly` ghim về UTC, nên chuỗi ISO vừa so
///   sánh đúng thứ tự theo từ điển (dùng được chỉ mục cho cả `ORDER BY` lẫn
///   `BETWEEN`), vừa gom nhóm theo tháng/năm bằng `substr` mà không phải mượn
///   múi giờ của thiết bị (Rule – File Time and Device Time Are Different
///   Things).
/// * **Mốc thời gian thiết bị** (`imported_at`, `created_at`, `started_at`…) lưu
///   dạng số nguyên epoch milliseconds UTC: chúng là thời điểm thật, cần cả giờ.
/// * **Số tiền** lưu thành cặp `amount_minor` (số nguyên có dấu, đơn vị nhỏ
///   nhất) và `currency` (mã ISO 4217). Không có cột `REAL` nào trong lược đồ —
///   đó là điều kiện để chống trùng và đối soát so sánh bằng nhau tuyệt đối
///   (Rule – Money Is a Signed Integer, Never a Floating-Point Number).
/// * **Cờ boolean** lưu bằng `INTEGER` 0/1, kiểu duy nhất SQLite có.
///
/// ## Điều lược đồ **cố ý không** làm
///
/// Không khoá ngoại nào khai báo `ON DELETE CASCADE`. Chuỗi xoá dây chuyền
/// (UC-01, UC-03) trải trên nhiều aggregate và được tầng Application thi hành
/// tường minh trong một `UnitOfWork`; để cơ sở dữ liệu âm thầm xoá theo là dựng
/// **bản sao thứ hai** của cùng một luật, ở nơi không ai đọc thấy khi đọc use
/// case. Giữ mặc định `RESTRICT` biến một bước bị bỏ sót thành lỗi ồn ào ngay
/// tại chỗ, thay vì thành dữ liệu biến mất trong im lặng.
abstract final class LedgerSchema {
  /// Phiên bản lược đồ, tăng mỗi lần cấu trúc đổi; [migrate] là nơi mô tả đường
  /// đi từ phiên bản cũ lên.
  static const int version = 1;

  static const String bankAccount = 'bank_account';
  static const String importSession = 'import_session';
  static const String importFileRecord = 'import_file_record';
  static const String importErrorRow = 'import_error_row';

  /// `transaction` là từ khoá của SQLite nên bảng mang tên đầy đủ hơn; né một
  /// lần ở đây rẻ hơn việc mọi câu lệnh phải nhớ đặt dấu nháy.
  static const String transaction = 'ledger_transaction';

  static const String reconciliationPair = 'reconciliation_pair';
  static const String rejectedMatch = 'rejected_match';
  static const String appSettings = 'app_settings';

  /// Mọi bảng, theo thứ tự **an toàn để xoá sạch**: con trước, cha sau. Dùng khi
  /// khôi phục từ sao lưu và khi reset ứng dụng (UC-12, UC-13).
  static const List<String> tablesInDeletionOrder = <String>[
    rejectedMatch,
    reconciliationPair,
    transaction,
    importErrorRow,
    importFileRecord,
    importSession,
    bankAccount,
    appSettings,
  ];

  /// Các bảng đi vào **bản sao lưu**, theo thứ tự an toàn để ghi lại: cha
  /// trước, con sau.
  ///
  /// `app_settings` cố ý **vắng mặt**, và đây là quyết định có hệ quả trực tiếp
  /// tới việc UC-12 có lối thoát hay không. Lối thoát khi quên PIN là reset ứng
  /// dụng rồi khôi phục từ bản sao lưu; nếu bản sao lưu mang theo `pin_hash` thì
  /// ngay sau khi khôi phục, ứng dụng khoá lại bằng đúng mã PIN vừa quên — và
  /// use case tự triệt tiêu. UC-13 cũng liệt kê nội dung bản sao lưu đúng bằng
  /// bốn thứ nghiệp vụ: tài khoản, giao dịch, kết quả đối soát, phán quyết từ
  /// chối.
  static const List<String> tablesInBackupOrder = <String>[
    bankAccount,
    importSession,
    importFileRecord,
    importErrorRow,
    transaction,
    reconciliationPair,
    rejectedMatch,
  ];

  /// Các câu lệnh dựng lược đồ từ con số không.
  static const List<String> createStatements = <String>[
    'CREATE TABLE $bankAccount ('
        ' account_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' display_name TEXT NOT NULL,'
        ' account_number TEXT,'
        ' created_at INTEGER NOT NULL'
        ')',
    // Danh sách tài khoản luôn sắp theo tên hiển thị (UC-01 bước 1).
    'CREATE INDEX idx_account_display_name ON $bankAccount (display_name)',

    'CREATE TABLE $importSession ('
        ' session_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' started_at INTEGER NOT NULL,'
        ' completed_at INTEGER,'
        ' status TEXT NOT NULL'
        ')',
    // Lịch sử nhập hiện theo thời gian gần nhất trước (UC-03 bước 2).
    'CREATE INDEX idx_session_started_at ON $importSession (started_at DESC)',
    // Lượt quét dọn lúc khởi động chỉ hỏi đúng các lượt còn InProgress
    // (Rule – A Dead Process Leaves Honest Records).
    'CREATE INDEX idx_session_status ON $importSession (status)',

    'CREATE TABLE $importFileRecord ('
        ' record_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' session_id INTEGER NOT NULL REFERENCES $importSession (session_id),'
        ' account_id INTEGER NOT NULL REFERENCES $bankAccount (account_id),'
        ' file_name TEXT NOT NULL,'
        ' detected_format TEXT NOT NULL,'
        ' order_index INTEGER NOT NULL,'
        ' status TEXT NOT NULL,'
        ' imported_count INTEGER NOT NULL DEFAULT 0,'
        ' duplicate_skipped_count INTEGER NOT NULL DEFAULT 0,'
        ' error_row_count INTEGER NOT NULL DEFAULT 0,'
        ' reverted_at INTEGER'
        ')',
    // Bản ghi con của một lượt luôn được trả về theo thứ tự người dùng chọn
    // (Rule – Write Order Is Deterministic).
    'CREATE INDEX idx_file_record_session'
        ' ON $importFileRecord (session_id, order_index)',
    // Xoá tài khoản kéo theo bản ghi nhập của các file gán vào nó (UC-01).
    'CREATE INDEX idx_file_record_account ON $importFileRecord (account_id)',

    'CREATE TABLE $importErrorRow ('
        ' error_row_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' record_id INTEGER NOT NULL REFERENCES $importFileRecord (record_id),'
        ' source_line_number INTEGER NOT NULL,'
        ' raw_excerpt TEXT NOT NULL,'
        ' reason TEXT NOT NULL'
        ')',
    // Dòng lỗi xuất lại theo đúng thứ tự dòng trong file gốc (UC-11).
    'CREATE INDEX idx_error_row_record'
        ' ON $importErrorRow (record_id, source_line_number)',

    'CREATE TABLE $transaction ('
        ' transaction_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' account_id INTEGER NOT NULL REFERENCES $bankAccount (account_id),'
        ' booking_date TEXT NOT NULL,'
        ' amount_minor INTEGER NOT NULL,'
        ' currency TEXT NOT NULL,'
        ' counterparty_name TEXT,'
        ' description TEXT NOT NULL,'
        ' search_text TEXT NOT NULL,'
        ' fingerprint TEXT NOT NULL,'
        ' import_file_record_id INTEGER NOT NULL'
        '   REFERENCES $importFileRecord (record_id),'
        ' source_line_number INTEGER,'
        ' is_manually_edited INTEGER NOT NULL DEFAULT 0,'
        ' imported_at INTEGER NOT NULL'
        ')',
    // Danh sách mặc định: mọi tài khoản, ngày gần nhất trước, phá hoà bằng định
    // danh để phân trang không bao giờ bỏ sót hay lặp dòng (UC-04).
    'CREATE INDEX idx_transaction_booking_date'
        ' ON $transaction (booking_date DESC, transaction_id)',
    // Lọc về một tài khoản mà vẫn giữ nguyên thứ tự (UC-07).
    'CREATE INDEX idx_transaction_account_date'
        ' ON $transaction (account_id, booking_date DESC)',
    // Chống trùng hỏi "tài khoản này đang có mấy dòng mang fingerprint này"
    // (UC-02). Cố ý **không** phải UNIQUE: hai dòng giống hệt nhau trong cùng
    // một file là hai giao dịch thật
    // (Rule – Identity Is Local and Surrogate; Sameness Is Fingerprint).
    'CREATE INDEX idx_transaction_fingerprint'
        ' ON $transaction (account_id, fingerprint)',
    // Tìm kiếm tức thời chạy trên cột đã chuẩn hoá sẵn (UC-06).
    'CREATE INDEX idx_transaction_search_text ON $transaction (search_text)',
    // Hoàn tác xoá đúng những gì một file đã ghi (UC-03).
    'CREATE INDEX idx_transaction_record'
        ' ON $transaction (import_file_record_id)',
    // Thống kê luôn được tính theo **một** loại tiền, trong một khoảng ngày
    // (UC-10).
    'CREATE INDEX idx_transaction_currency_date'
        ' ON $transaction (currency, booking_date)',
    // Tập ứng viên ghép cặp thu hẹp bằng loại tiền + số tiền đối nhau trước, rồi
    // mới tới cửa sổ thời gian (UC-08 bước 2).
    'CREATE INDEX idx_transaction_match'
        ' ON $transaction (currency, amount_minor, booking_date)',

    'CREATE TABLE $reconciliationPair ('
        ' pair_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' outgoing_transaction_id INTEGER NOT NULL UNIQUE'
        '   REFERENCES $transaction (transaction_id),'
        ' incoming_transaction_id INTEGER NOT NULL UNIQUE'
        '   REFERENCES $transaction (transaction_id),'
        ' status TEXT NOT NULL,'
        ' created_at INTEGER NOT NULL,'
        ' confirmed_at INTEGER,'
        ' CHECK (outgoing_transaction_id <> incoming_transaction_id)'
        ')',
    // Hai ràng buộc UNIQUE ở trên **là** luật "một giao dịch chỉ thuộc tối đa
    // một cặp" (UC-08): chiều tiền nằm ở dấu của số tiền nên một giao dịch chỉ
    // đứng được ở đúng một trong hai vế, và duy nhất trên từng vế là đủ.
    'CREATE INDEX idx_pair_status ON $reconciliationPair (status)',

    'CREATE TABLE $rejectedMatch ('
        ' rejected_match_id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' transaction_a_id INTEGER NOT NULL'
        '   REFERENCES $transaction (transaction_id),'
        ' transaction_b_id INTEGER NOT NULL'
        '   REFERENCES $transaction (transaction_id),'
        ' rejected_at INTEGER NOT NULL,'
        ' UNIQUE (transaction_a_id, transaction_b_id),'
        ' CHECK (transaction_a_id < transaction_b_id)'
        ')',
    // `CHECK` ở trên giữ đúng bất biến mà `RejectedMatch.between` đã dựng: cặp
    // không có thứ tự nên hai định danh luôn nằm theo chiều tăng dần, và nhờ vậy
    // một lần tra là đủ để biết cặp ứng viên đã bị từ chối hay chưa (UC-09).
    'CREATE INDEX idx_rejection_b ON $rejectedMatch (transaction_b_id)',

    'CREATE TABLE $appSettings ('
        ' settings_id INTEGER PRIMARY KEY CHECK (settings_id = 1),'
        ' app_lock_enabled INTEGER NOT NULL,'
        ' pin_hash TEXT,'
        ' biometric_enabled INTEGER NOT NULL,'
        ' match_window_days INTEGER NOT NULL'
        ')',
  ];

  /// Đường đi từ một lược đồ cũ lên [version].
  ///
  /// Hiện chưa có phiên bản nào trước v1 nên danh sách rỗng; hàm tồn tại sẵn để
  /// lần thêm cột đầu tiên không phải đụng vào `AppDatabase`.
  static List<String> migrate({
    required int fromVersion,
    required int toVersion,
  }) => const <String>[];
}
