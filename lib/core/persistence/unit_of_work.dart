/// Ranh giới "được ăn cả, ngã về không" bao quanh một khối việc.
///
/// Nó nói **cần gì** — mọi thứ bên trong commit cùng nhau hoặc không gì cả — và
/// không nói **làm thế nào**. Hiện tại tầng Infrastructure ánh xạ nó thành một
/// transaction SQLite; trong test nó chỉ là một lời gọi hàm thường; và sau này
/// một thao tác phải giữ file với cơ sở dữ liệu đồng bộ với nhau cũng ánh xạ vào
/// đây được mà không nơi gọi nào phải sửa.
///
/// ## Vì sao ứng dụng cần nó
///
/// Nhiều luật trải trên hơn một aggregate và không được phép làm nửa vời:
///
/// * xoá tài khoản thì xoá luôn giao dịch của nó, các bản ghi nhập của những file
///   gán vào nó, cùng các cặp và phán quyết từ chối dính tới các giao dịch đó
///   (UC-01);
/// * hoàn tác một lượt nhập thì xoá đúng những gì file đó đã ghi, kèm các cặp và
///   phán quyết treo trên các dòng ấy (UC-03);
/// * xoá hoặc sửa một giao dịch thì huỷ cặp mà nó đang thuộc về (UC-05, UC-09).
///
/// Domain cố ý **không** lồng các aggregate đó vào nhau — một tài khoản với hàng
/// trăm nghìn giao dịch không thể là một đơn vị nạp-và-ghi — nên tính nhất quán
/// mà chúng cần được tầng Application thi hành tường minh. Cổng này chính là chữ
/// "tường minh" đó: không có nó, use case sẽ phải với thẳng xuống cơ sở dữ liệu
/// và quy tắc phụ thuộc vỡ ngay ở chuỗi xoá đầu tiên.
abstract interface class UnitOfWork {
  /// Chạy [action] sao cho mọi phép ghi bên trong nó commit cùng nhau.
  ///
  /// Một thất bại — dù là domain error được ném ra hay lỗi lưu trữ — sẽ rollback
  /// toàn bộ ranh giới và lỗi vẫn tiếp tục lan ra ngoài.
  ///
  /// Chỉ lỗi **được ném** mới rollback. Use case nào bắt lỗi rồi trả về một giá
  /// trị thất bại tức là đã báo với ranh giới rằng mọi thứ ổn, và phần đã ghi sẽ
  /// commit. Hãy đổi sang `Result` ở **ngoài** [transaction], đừng làm bên trong.
  ///
  /// Phần hiện thực phải cho các cộng tác viên lấy từ DI container — trên thực
  /// tế là các repository — tham gia vào ranh giới đang mở, và phải coi lời gọi
  /// lồng nhau là một phần của ranh giới ngoài chứ không mở transaction thứ hai.
  ///
  /// Các đường chỉ đọc (danh sách, tìm kiếm, thống kê) không cần tới nó: chúng
  /// chạy một truy vấn duy nhất, không có gì để giữ nhất quán giữa nhiều lời gọi.
  Future<T> transaction<T>(Future<T> Function() action);
}
