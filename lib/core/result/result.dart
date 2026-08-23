import 'dart:async';

import 'failure.dart';

/// Kết cục của một thao tác: hoặc một giá trị, hoặc một [Failure].
///
/// Use case trả về kiểu này thay vì ném, để mọi nơi gọi — nhất là BLoC — buộc
/// phải đối diện cả hai khả năng ngay tại chỗ chúng thật sự làm được gì đó.
/// Exception vẫn tồn tại bên dưới (Domain ném, SQLite ném); [Result.guard] là
/// nơi duy nhất đổi chúng thành giá trị.
///
/// Là `sealed`, nên `switch` trên `Ok`/`Err` là vét cạn.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;

  const factory Result.err(Failure failure) = Err<T>;

  /// Chạy [action] và bắt lại mọi thứ nó ném ra.
  ///
  /// [onError] ánh xạ lỗi bắt được thành failure; tầng Application truyền vào
  /// một hàm biết về domain error — đó chính là lý do `core` không cần biết
  /// chúng. Không truyền thì mọi thứ ném ra đều thành [UnexpectedFailure].
  static Result<T> guard<T>(
    T Function() action, {
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) {
    try {
      return Ok<T>(action());
    } catch (error, stackTrace) {
      return Err<T>(_toFailure(error, stackTrace, onError));
    }
  }

  /// Bản bất đồng bộ của [guard]; là dạng mà mọi use case sẽ dùng.
  static Future<Result<T>> guardAsync<T>(
    FutureOr<T> Function() action, {
    Failure Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    try {
      return Ok<T>(await action());
    } catch (error, stackTrace) {
      return Err<T>(_toFailure(error, stackTrace, onError));
    }
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Giá trị, hoặc `null` khi đây là thất bại. Khi cần xử lý cả hai nhánh thì
  /// dùng [fold] hoặc `switch`.
  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Gộp cả hai nhánh thành một giá trị.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  T getOrElse(T Function(Failure failure) orElse) =>
      fold((value) => value, orElse);

  /// Biến đổi giá trị, để nguyên thất bại.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Nối tiếp một thao tác mà bản thân nó cũng có thể thất bại.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => transform(value),
    Err<T>(:final failure) => Err<R>(failure),
  };

  /// Viết lại thất bại — dùng khi failure của tầng dưới cần mang ý nghĩa khác ở
  /// tầng trên.
  Result<T> mapFailure(Failure Function(Failure failure) transform) =>
      switch (this) {
        Ok<T>() => this,
        Err<T>(:final failure) => Err<T>(transform(failure)),
      };

  static Failure _toFailure(
    Object error,
    StackTrace stackTrace,
    Failure Function(Object error, StackTrace stackTrace)? onError,
  ) {
    if (error is Failure) return error;
    if (onError != null) return onError(error, stackTrace);
    return UnexpectedFailure(
      error.toString(),
      cause: error,
      stackTrace: stackTrace,
    );
  }
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err($failure)';
}
