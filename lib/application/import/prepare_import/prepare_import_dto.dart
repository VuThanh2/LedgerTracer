import 'dart:typed_data';

import '../../../domain/value_objects/statement_format.dart';

/// Một file người dùng vừa chọn từ thiết bị, trước khi ứng dụng biết gì về nó
/// (UC-02 bước 1).
final class PickedFile {
  const PickedFile({required this.fileName, required this.bytes});

  final String fileName;

  final Uint8List bytes;
}

/// Kết quả soi một file đã chọn (UC-02 bước 2).
///
/// Là một [sealed class] chứ không phải một `RecognizedFile` với trường nullable:
/// một file không nhận diện được không có định dạng, không có số tài khoản, và
/// không đi tiếp được — mọi nơi đọc buộc phải xử lý nhánh đó thay vì quên.
sealed class InspectedFile {
  const InspectedFile({required this.fileName});

  final String fileName;
}

/// File đã nhận ra định dạng và đọc xong phần đầu.
final class RecognizedFile extends InspectedFile {
  const RecognizedFile({
    required super.fileName,
    required this.bytes,
    required this.format,
    required this.embeddedAccountNumber,
  });

  final Uint8List bytes;

  final StatementFormat format;

  /// Số tài khoản nhúng trong chính file, `null` khi định dạng không mang nó.
  /// Người dùng không phải gõ số này ở bất kỳ đâu (UC-02 bước 4).
  final String? embeddedAccountNumber;

  bool get carriesAccountNumber => embeddedAccountNumber != null;
}

/// File không thuộc bốn định dạng được hỗ trợ, hoặc hỏng tới mức không đoán
/// được.
///
/// Là **dữ liệu**, không phải lỗi làm hỏng cả lượt: một file lạ trong nhóm file
/// người dùng chọn không được kéo theo những file còn lại (UC-02).
final class UnrecognizedFile extends InspectedFile {
  const UnrecognizedFile({required super.fileName, required this.reason});

  final String reason;
}

/// Phán quyết của việc đối chiếu số tài khoản nhúng trong file với số đã ghi
/// nhận ở tài khoản đích (UC-02 bước 4).
enum AccountNumberVerdict {
  /// Định dạng không mang số tài khoản — không có gì để đối chiếu. Đây cũng là
  /// tình huống của mọi file CSV/Excel/JSON thông thường.
  fileCarriesNoNumber,

  /// Tài khoản đích chưa có số và file thì có: hệ thống sẽ **tự ghi nhận** số
  /// này làm mốc đối chiếu cho các lần nhập sau.
  willLearn,

  /// Số trong file khớp với số đã ghi nhận.
  matches,

  /// Số trong file khác số đã ghi nhận — cảnh báo, **không chặn cứng**: có lý do
  /// hợp lệ (ngân hàng cấp lại số, hoặc lần nhập đầu đã học sai).
  mismatch,
}

/// Kết quả đối chiếu, kèm hai con số để hộp thoại cảnh báo nói được cụ thể.
final class AccountAssignmentCheck {
  const AccountAssignmentCheck({
    required this.verdict,
    this.embeddedAccountNumber,
    this.recordedAccountNumber,
  });

  final AccountNumberVerdict verdict;

  /// Số đọc được trong file, đã chuẩn hoá.
  final String? embeddedAccountNumber;

  /// Số tài khoản đích đang giữ, đã chuẩn hoá.
  final String? recordedAccountNumber;

  /// Chỉ [AccountNumberVerdict.mismatch] mới cần người dùng quyết định giữa gán
  /// lại tài khoản khác, vẫn nhập, hay bỏ qua file này.
  bool get needsUserDecision => verdict == AccountNumberVerdict.mismatch;
}
