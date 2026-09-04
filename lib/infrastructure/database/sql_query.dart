import 'package:sqflite_common/sqlite_api.dart';

/// Những mảnh SQL lặp lại ở nhiều repository, gom về một chỗ.
abstract final class SqlQuery {
  /// Trần số tham số tự đặt cho một mệnh đề `IN (...)`.
  ///
  /// SQLite có trần thật của riêng nó (mặc định 999 ở các bản cũ), và vượt trần
  /// là một lỗi **chỉ xuất hiện khi dữ liệu đủ lớn** — đúng quy mô mà đề tài lấy
  /// làm trọng tâm, và đúng lúc không ai còn ngồi debug. Chia lô ở một ngưỡng
  /// thấp hơn hẳn là cách để câu hỏi "danh sách này có dài quá không" không bao
  /// giờ phải đặt ra ở nơi gọi.
  static const int maxVariablesPerStatement = 500;

  /// `?, ?, ?` cho một mệnh đề `IN`.
  static String placeholders(int count) =>
      List<String>.filled(count, '?').join(', ');

  /// Cắt một danh sách định danh thành các lô vừa [maxVariablesPerStatement].
  ///
  /// [maxPerChunk] để nơi gọi hạ trần xuống khi **một lô đi vào nhiều hơn một**
  /// mệnh đề `IN` trong cùng câu lệnh: trần của SQLite tính trên tổng số tham số
  /// của cả câu, không phải trên từng mệnh đề.
  static Iterable<List<T>> chunked<T>(Iterable<T> items, {int? maxPerChunk}) sync* {
    final size = maxPerChunk ?? maxVariablesPerStatement;
    final all = items.toList(growable: false);
    for (var start = 0; start < all.length; start += size) {
      final end = start + size;
      yield all.sublist(start, end < all.length ? end : all.length);
    }
  }

  /// Ký tự thoát dùng cho mọi mệnh đề `LIKE` của ứng dụng.
  static const String likeEscape = r'\';

  /// Vô hiệu hoá `%` và `_` trong từ khoá người dùng gõ.
  ///
  /// Thiếu bước này thì gõ `_` sẽ khớp mọi ký tự và gõ `%` sẽ khớp mọi thứ — một
  /// ô tìm kiếm im lặng trả về kết quả sai chứ không báo lỗi (UC-06).
  static String escapeLike(String value) => value
      .replaceAll(likeEscape, r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

/// Các phép đọc trả về đúng một con số.
extension SqlCountQuery on DatabaseExecutor {
  /// Chạy một truy vấn `SELECT COUNT(...)` và lấy con số ra.
  ///
  /// Đếm bằng SQL thay vì nạp danh sách rồi lấy `length`: mọi con số trong ứng
  /// dụng đều có thể là hàng trăm nghìn, và một phép đếm nạp cả bảng lên luồng
  /// chính chỉ để bỏ đi là thứ vỡ đúng vào lúc dữ liệu lớn nhất.
  Future<int> countRows(String sql, [List<Object?>? arguments]) async {
    final rows = await rawQuery(sql, arguments);
    if (rows.isEmpty) return 0;
    return (rows.first.values.first as int?) ?? 0;
  }
}
