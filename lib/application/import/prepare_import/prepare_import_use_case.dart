import 'dart:typed_data';

import '../../../core/result/result.dart';
import '../../../domain/entities/bank_account.dart';
import '../../../domain/errors/account_errors.dart';
import '../../../domain/errors/import_errors.dart';
import '../../../domain/repositories/bank_account_repository.dart';
import '../../shared/domain_failures.dart';
import '../contracts/statement_parser.dart';
import 'prepare_import_dto.dart';

/// Nửa đầu của luồng nhập sao kê: nhận diện định dạng và đối chiếu số tài khoản,
/// **trước khi** bất kỳ isolate nào khởi động (UC-02 bước 2–4).
///
/// Tách khỏi `ImportStatementsUseCase` vì hai nửa có nhịp hoàn toàn khác nhau.
/// Nửa này ngắn, chỉ đọc phần đầu mỗi file, và **cần người dùng trả lời** — chọn
/// tài khoản đích, quyết định phải làm gì khi số tài khoản lệch. Nửa sau chạy
/// hàng phút trên luồng nền và không được dừng lại hỏi ai. Gộp chúng lại đồng
/// nghĩa với việc một hộp thoại chờ người dùng bấm sẽ nghẽn ngay giữa hàng đợi
/// ghi tuần tự — đúng điều UC-02 bước 4 nói phải tránh.
final class PrepareImportUseCase {
  PrepareImportUseCase({
    required this._accounts,
    required this._detector,
    required this._parserFactory,
  });

  final BankAccountRepository _accounts;
  final StatementFormatDetector _detector;
  final StatementParserFactory _parserFactory;

  /// Số byte đầu file được dùng để nhận diện định dạng và dò số tài khoản.
  ///
  /// Cố định và nhỏ: mục đích là trả lời hai câu hỏi trước khi xử lý nền bắt
  /// đầu, không phải đọc dữ liệu. Định dạng nào cần nhiều hơn từng ấy để kết
  /// luận thì trả `null` và luồng đi tiếp như file không mang số tài khoản.
  static const int headByteCount = 64 * 1024;

  /// Soi từng file đã chọn: định dạng nào, có mang số tài khoản không.
  ///
  /// Một file không nhận ra được **không** làm hỏng cả lượt — nó về như
  /// [UnrecognizedFile] để màn hình hiển thị riêng nó là lỗi (UC-02).
  Future<Result<List<InspectedFile>>> inspect(List<PickedFile> files) =>
      Result.guardAsync(
        () async => <InspectedFile>[for (final file in files) _inspectOne(file)],
        onError: failureFromError,
      );

  /// Đối chiếu số tài khoản của một file với tài khoản đích người dùng vừa gán
  /// (UC-02 bước 4). Chỉ đọc — việc ghi nhận số mới là của [learnAccountNumber].
  Future<Result<AccountAssignmentCheck>> checkAssignment({
    required RecognizedFile file,
    required int accountId,
  }) => Result.guardAsync(() async {
    final embedded = file.embeddedAccountNumber;
    if (embedded == null) {
      return const AccountAssignmentCheck(
        verdict: AccountNumberVerdict.fileCarriesNoNumber,
      );
    }

    final account = await _requireAccount(accountId);
    final recorded = account.accountNumber;
    if (recorded == null) {
      return AccountAssignmentCheck(
        verdict: AccountNumberVerdict.willLearn,
        embeddedAccountNumber: embedded,
      );
    }
    return AccountAssignmentCheck(
      verdict: account.matchesAccountNumber(embedded)
          ? AccountNumberVerdict.matches
          : AccountNumberVerdict.mismatch,
      embeddedAccountNumber: embedded,
      recordedAccountNumber: recorded,
    );
  }, onError: failureFromError);

  /// Ghi nhận số tài khoản học được từ file đầu tiên có mang nó.
  ///
  /// Chỉ ghi khi tài khoản **chưa** có số. Đây là lý do nó không dùng lại đường
  /// sửa số ở UC-01: chọn "vẫn nhập" khi số lệch **không** được ghi đè mốc đối
  /// chiếu đã có — muốn đổi mốc thì người dùng phải sửa tường minh ở màn hình
  /// quản lý tài khoản. Gọi lại khi số đã tồn tại là một lệnh không làm gì.
  Future<Result<BankAccount>> learnAccountNumber({
    required int accountId,
    required String accountNumber,
  }) => Result.guardAsync(() async {
    final account = await _requireAccount(accountId);
    if (account.hasAccountNumber) return account;
    final learned = account.withAccountNumber(accountNumber);
    await _accounts.update(learned);
    return learned;
  }, onError: failureFromError);

  InspectedFile _inspectOne(PickedFile file) {
    final head = _headOf(file.bytes);
    final format = _detector.detect(fileName: file.fileName, head: head);
    if (format == null) {
      return UnrecognizedFile(
        fileName: file.fileName,
        reason: UnsupportedStatementFormatError(file.fileName).message,
      );
    }

    final parser = _parserFactory.parserFor(format);
    return RecognizedFile(
      fileName: file.fileName,
      bytes: file.bytes,
      format: format,
      embeddedAccountNumber: _normalizedAccountNumber(
        parser.peekAccountNumber(head),
      ),
    );
  }

  /// Chuẩn hoá ngay tại đây bằng chính hàm của Domain, để phép so khớp về sau là
  /// so hai chuỗi đã cùng dạng chứ không phải so một chuỗi thô với một chuỗi đã
  /// chuẩn hoá. Số không dùng được coi như file không mang số.
  String? _normalizedAccountNumber(String? raw) {
    if (raw == null) return null;
    try {
      return BankAccount.normalizeAccountNumber(raw);
    } on InvalidAccountNumberError {
      return null;
    }
  }

  Uint8List _headOf(Uint8List bytes) => bytes.length <= headByteCount
      ? bytes
      : Uint8List.sublistView(bytes, 0, headByteCount);

  Future<BankAccount> _requireAccount(int accountId) async {
    final account = await _accounts.findById(accountId);
    if (account == null) throw AccountNotFoundError(accountId);
    return account;
  }
}
