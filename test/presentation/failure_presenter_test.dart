import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/presentation/shared/failures/failure_presenter.dart';
import 'package:ledger_tracer/presentation/shared/failures/feedback_message.dart';

void main() {
  /// Mọi nhánh của `Failure`. Danh sách này là chốt chặn thật: thêm một nhánh
  /// failure ở tầng `core` mà quên câu chữ cho nó thì `switch` trong
  /// `FailurePresenter` không còn vét cạn và biên dịch hỏng — nhưng chỉ khi ở
  /// đây có ai đó dựng nó lên.
  final failures = <Failure>[
    const ValidationFailure('name is empty'),
    const NotFoundFailure('no transaction with id 41'),
    const StorageFailure('database is locked'),
    const FileAccessFailure('permission denied'),
    const ParsingFailure('not a CSV'),
    const SecurityFailure('wrong pin'),
    const CancelledFailure(),
    const UnsupportedOnPlatformFailure('no biometrics on web'),
    UnexpectedFailure('boom', cause: 'boom', stackTrace: StackTrace.empty),
  ];

  test('mọi nhánh failure đều có câu chữ riêng', () {
    final texts = <String>{
      for (final failure in failures) FailurePresenter.of(failure).text,
    };
    expect(texts.length, failures.length);
  });

  test('không câu nào rò chuỗi kỹ thuật của tầng dưới ra màn hình', () {
    for (final failure in failures) {
      final message = FailurePresenter.of(failure);
      expect(
        message.text,
        isNot(contains(failure.message)),
        reason:
            'chữ hiển thị phải được chọn theo nhánh failure, không phải lấy '
            'nguyên chuỗi dành cho lập trình viên',
      );
      // Chuỗi ấy vẫn phải giữ được, cho log và cho màn hình chẩn đoán.
      expect(message.detail, failure.message);
    }
  });

  test('huỷ là một kết cục, không phải một lỗi', () {
    final message = FailurePresenter.of(const CancelledFailure());
    expect(message.severity, FeedbackSeverity.info);
    expect(FailurePresenter.isCancellation(const CancelledFailure()), isTrue);
    expect(
      FailurePresenter.isCancellation(const StorageFailure('x')),
      isFalse,
    );
  });

  test('mức độ phân theo việc người dùng phải làm gì tiếp', () {
    // Sửa được ngay tại ô nhập, hoặc chỉ cần tải lại: cảnh báo.
    expect(
      FailurePresenter.of(const ValidationFailure('x')).severity,
      FeedbackSeverity.warning,
    );
    expect(
      FailurePresenter.of(const NotFoundFailure('x')).severity,
      FeedbackSeverity.warning,
    );
    // Chạm tới lớp bảo vệ, hoặc thao tác không đi tới đâu: nguy hiểm.
    expect(
      FailurePresenter.of(const SecurityFailure('x')).severity,
      FeedbackSeverity.danger,
    );
    expect(
      FailurePresenter.of(const StorageFailure('x')).severity,
      FeedbackSeverity.danger,
    );
    // Nền tảng không làm được: thông tin, vì không có gì để sửa.
    expect(
      FailurePresenter.of(const UnsupportedOnPlatformFailure('x')).severity,
      FeedbackSeverity.info,
    );
  });

  test('câu "không tìm thấy" nói đúng thứ vừa biến mất', () {
    expect(
      FailurePresenter.of(
        const NotFoundFailure('x'),
        context: 'cặp đối soát',
      ).text,
      contains('cặp đối soát'),
    );
  });

  test('câu về bảo mật không bao giờ nói bí mật sai ở đâu', () {
    final text = FailurePresenter.of(
      const SecurityFailure('pin hash mismatch for user'),
    ).text;
    expect(text, isNot(contains('hash')));
    expect(text.toLowerCase(), isNot(contains('mismatch')));
  });
}
