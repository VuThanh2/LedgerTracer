/// Một đường đọc đang ở đâu.
///
/// Bốn giá trị chứ không phải một cặp cờ `isLoading`/`hasError`: [initial] và
/// [loading] khác nhau ở chỗ màn hình vẽ gì — lần đầu là khung xương, các lần
/// sau là danh sách cũ mờ đi — còn `isLoading && hasError` là một tổ hợp không
/// có nghĩa nhưng vẫn biểu diễn được nếu dùng hai cờ.
enum LoadStatus {
  /// Chưa yêu cầu gì. Màn hình chưa từng có dữ liệu để vẽ.
  initial,

  /// Đang đọc. Dữ liệu cũ (nếu có) vẫn còn trong state và vẫn hiển thị được.
  loading,

  /// Đã có dữ liệu. Rỗng vẫn là [ready] — "không có kết quả nào" là một câu trả
  /// lời, không phải một trạng thái dở dang.
  ready,

  /// Lần đọc gần nhất thất bại. Dữ liệu cũ vẫn còn để màn hình không trắng xoá.
  failed;

  bool get isInitial => this == LoadStatus.initial;

  bool get isLoading => this == LoadStatus.loading;

  bool get isReady => this == LoadStatus.ready;

  bool get isFailed => this == LoadStatus.failed;
}
