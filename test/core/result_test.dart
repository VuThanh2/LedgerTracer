import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/core/result/failure.dart';
import 'package:ledger_tracer/core/result/result.dart';

/// Result là ranh giới giữa "chuyện bất thường" và "luồng điều khiển". Use case
/// không ném ra ngoài; nó trả về một trong hai nhánh, và giao diện buộc phải xử
/// lý cả hai.
void main() {
  group('Ok và Err', () {
    test('phân biệt được hai nhánh', () {
      const ok = Ok<int>(1);
      const err = Err<int>(ValidationFailure('sai'));
      expect(ok.isOk, isTrue);
      expect(ok.isErr, isFalse);
      expect(err.isErr, isTrue);
      expect(err.isOk, isFalse);
    });

    test('valueOrNull và failureOrNull chỉ có giá trị ở đúng nhánh của mình', () {
      const ok = Ok<int>(1);
      const err = Err<int>(ValidationFailure('sai'));
      expect(ok.valueOrNull, 1);
      expect(ok.failureOrNull, isNull);
      expect(err.valueOrNull, isNull);
      expect(err.failureOrNull, isA<ValidationFailure>());
    });

    test('giá trị null hợp lệ vẫn là một Ok', () {
      // valueOrNull không phân biệt được, nhưng isOk thì có — đó là lý do không
      // được dùng valueOrNull để kiểm tra thành công.
      const ok = Ok<int?>(null);
      expect(ok.isOk, isTrue);
      expect(ok.valueOrNull, isNull);
    });

    test('đẳng thức theo nội dung', () {
      expect(const Ok<int>(1), const Ok<int>(1));
      expect(const Ok<int>(1), isNot(const Ok<int>(2)));
      expect(const Ok<int>(1).hashCode, const Ok<int>(1).hashCode);
    });
  });

  group('fold và getOrElse', () {
    test('fold chạy đúng một nhánh', () {
      expect(const Ok<int>(2).fold((v) => 'ok $v', (f) => 'err'), 'ok 2');
      expect(
        const Err<int>(NotFoundFailure('mất')).fold((v) => 'ok', (f) => f.message),
        'mất',
      );
    });

    test('getOrElse trả giá trị thay thế khi lỗi', () {
      expect(const Ok<int>(2).getOrElse((_) => 0), 2);
      expect(const Err<int>(StorageFailure('x')).getOrElse((_) => 0), 0);
    });
  });

  group('map, flatMap, mapFailure', () {
    test('map chỉ đổi nhánh thành công', () {
      expect(const Ok<int>(2).map((v) => v * 2), const Ok<int>(4));
    });

    test('map giữ nguyên lỗi và đổi được kiểu', () {
      const err = Err<int>(NotFoundFailure('mất'));
      final mapped = err.map((v) => v.toString());
      expect(mapped.isErr, isTrue);
      expect(mapped.failureOrNull, same(err.failure));
    });

    test('flatMap nối được hai bước có thể hỏng', () {
      Result<int> half(int v) =>
          v.isEven ? Ok<int>(v ~/ 2) : const Err<int>(ValidationFailure('lẻ'));
      expect(const Ok<int>(8).flatMap(half), const Ok<int>(4));
      expect(const Ok<int>(7).flatMap(half).isErr, isTrue);
    });

    test('flatMap không chạy bước sau khi bước trước đã hỏng', () {
      var ran = false;
      const Err<int>(StorageFailure('x')).flatMap((v) {
        ran = true;
        return Ok<int>(v);
      });
      expect(ran, isFalse);
    });

    test('mapFailure chỉ đổi nhánh lỗi', () {
      final translated = const Err<int>(
        StorageFailure('kỹ thuật'),
      ).mapFailure((f) => ValidationFailure('thân thiện: ${f.message}'));
      expect(translated.failureOrNull, isA<ValidationFailure>());
      expect(translated.failureOrNull!.message, contains('kỹ thuật'));

      const ok = Ok<int>(1);
      expect(ok.mapFailure((f) => const ValidationFailure('x')), same(ok));
    });
  });

  group('guard', () {
    test('gói giá trị trả về thành Ok', () {
      expect(Result.guard(() => 42), const Ok<int>(42));
    });

    test('biến exception lạ thành UnexpectedFailure kèm nguyên nhân', () {
      final result = Result.guard<int>(() => throw StateError('nổ'));
      final failure = result.failureOrNull!;
      expect(failure, isA<UnexpectedFailure>());
      expect(failure.cause, isA<StateError>());
      expect(failure.stackTrace, isNotNull);
    });

    test('Failure ném ra được giữ nguyên, không bọc thêm một lớp', () {
      // Nếu bọc lại, tầng trên mất khả năng phân biệt lỗi nghiệp vụ với lỗi lạ.
      const original = NotFoundFailure('mất');
      final result = Result.guard<int>(() => throw original);
      expect(result.failureOrNull, same(original));
    });

    test('onError được dùng để dịch lỗi lạ', () {
      final result = Result.guard<int>(
        () => throw StateError('nổ'),
        onError: (error, stack) => ValidationFailure('đã dịch: $error'),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('onError không được gọi cho Failure đã đúng loại', () {
      var called = false;
      Result.guard<int>(
        () => throw const NotFoundFailure('mất'),
        onError: (error, stack) {
          called = true;
          return const ValidationFailure('x');
        },
      );
      expect(called, isFalse);
    });
  });

  group('guardAsync', () {
    test('gói kết quả của Future thành Ok', () async {
      expect(await Result.guardAsync(() async => 42), const Ok<int>(42));
    });

    test('bắt được cả lỗi bất đồng bộ', () async {
      final result = await Result.guardAsync<int>(
        () async => throw StateError('nổ'),
      );
      expect(result.isErr, isTrue);
      expect(result.failureOrNull!.cause, isA<StateError>());
    });

    test('bắt được cả lỗi ném đồng bộ trước await đầu tiên', () async {
      final result = await Result.guardAsync<int>(() => throw StateError('nổ'));
      expect(result.isErr, isTrue);
    });

    test('nhận được cả hàm đồng bộ nhờ FutureOr', () async {
      expect(await Result.guardAsync<int>(() => 7), const Ok<int>(7));
    });
  });

  group('Failure', () {
    test('CancelledFailure có sẵn thông điệp mặc định', () {
      expect(const CancelledFailure().message, isNotEmpty);
    });

    test('toString nêu cả loại lẫn nguyên nhân', () {
      final text = UnexpectedFailure(
        'nổ',
        cause: StateError('gốc'),
        stackTrace: StackTrace.current,
      ).toString();
      expect(text, contains('UnexpectedFailure'));
      expect(text, contains('gốc'));
    });

    test('toString không thêm phần nguyên nhân khi không có', () {
      expect(const ValidationFailure('sai').toString(), 'ValidationFailure: sai');
    });
  });
}
