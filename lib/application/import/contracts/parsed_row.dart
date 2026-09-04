import '../../../domain/value_objects/money.dart';

/// Một dòng sao kê đã phân tích xong nhưng **chưa phải** một `Transaction`.
///
/// Đây là một trong các *Transient Type* đi qua ranh giới isolate: không được
/// lưu, không có định danh nghiệp vụ, và tồn tại chỉ vì Dart isolate không chia
/// sẻ bộ nhớ. Nó phải là dữ liệu thuần, sao chép được qua ranh giới.
///
/// Cố ý thiếu ba thứ mà chỉ giai đoạn ghi trên luồng chính mới cấp được:
///
/// * **accountId** — tài khoản đích được gán cho cả file, giai đoạn ghi biết;
/// * **fingerprint** — chỉ dựng được sau khi có accountId, và việc *đối chiếu*
///   chống trùng cần nhìn thấy những gì đã ghi (UC-02);
/// * **định danh** — do cơ sở dữ liệu tự tăng lúc ghi.
///
/// Việc quy đổi chuỗi số trong file sang [Money] (số nguyên đơn vị nhỏ nhất) đã
/// xảy ra ở đây, trong isolate, một lần duy nhất — mọi tầng phía sau chỉ làm việc
/// với số nguyên (Rule – Money Is a Signed Integer, Never a Floating-Point
/// Number). Chiều tiền nằm trong dấu của [amount]
/// (Rule – The Sign Carries the Direction).
final class ParsedRow {
  const ParsedRow({
    required this.bookingDate,
    required this.amount,
    this.counterpartyName,
    required this.description,
    this.sourceLineNumber,
  });

  /// Ngày ghi nhận đọc từ file, không phải đồng hồ thiết bị
  /// (Rule – File Time and Device Time Are Different Things).
  final DateTime bookingDate;

  /// Số tiền có dấu kèm loại tiền; parser đã áp mặc định VND khi nguồn không nêu
  /// (UC-02).
  final Money amount;

  final String? counterpartyName;

  final String description;

  /// Số thứ tự dòng trong file gốc, mang theo để giao dịch ghi ra đối chiếu được
  /// với file gốc (UC-04, UC-05).
  final int? sourceLineNumber;

  @override
  String toString() =>
      'ParsedRow(${bookingDate.toIso8601String()}, $amount'
      '${sourceLineNumber == null ? '' : ', line $sourceLineNumber'})';
}
