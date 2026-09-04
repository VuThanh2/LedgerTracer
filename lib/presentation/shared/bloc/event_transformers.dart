import 'dart:async';

import 'package:bloc/bloc.dart';

/// Các cách xử lý một dòng sự kiện, viết tay thay vì kéo `bloc_concurrency` vào.
///
/// Lý do không phải là tiết kiệm một dependency mà là **phạm vi**: ứng dụng chỉ
/// cần đúng bốn hành vi dưới đây, cả bốn đều là vài chục dòng `dart:async`, và
/// mỗi cái ở đây được gắn thẳng với tình huống nó tồn tại để giải quyết. Một gói
/// bên ngoài mang theo cả họ toán tử stream mà không chỗ nào trong dự án dùng
/// tới, còn phần dùng tới thì vẫn phải đọc tài liệu mới biết nên chọn cái nào.
///
/// Mặc định của `bloc` là xử lý **song song**: hai sự kiện tới liền nhau chạy
/// chồng lên nhau và thứ tự `emit` không được bảo đảm. Với đọc thuần thì vô hại,
/// nhưng với phân trang thì nó trộn hai trang vào nhau, và với một tác vụ nền
/// thì nó cho phép chạy hai lượt cùng lúc — nên gần như mọi `on<Event>` trong
/// dự án đều phải nói rõ mình muốn kiểu nào.
abstract final class EventTransformers {
  /// Chờ [duration] im lặng rồi mới xử lý, và **huỷ lượt đang chạy** khi có sự
  /// kiện mới.
  ///
  /// Đây là hình dạng của ô tìm kiếm sống (UC-06): mỗi phím gõ là một sự kiện,
  /// nhưng chỉ khoảng lặng mới đáng một truy vấn, và khi khoảng lặng tới thì kết
  /// quả của từ khoá cũ đã không còn ai cần. Thiếu vế thứ hai thì một truy vấn
  /// chậm của từ khoá cũ có thể về sau và ghi đè kết quả của từ khoá mới.
  static EventTransformer<E> searchInput<E>([
    Duration duration = defaultDebounce,
  ]) =>
      (events, mapper) => _switchMap(_debounce(events, duration), mapper);

  /// Huỷ lượt đang chạy khi có sự kiện mới, không chờ đợi gì.
  ///
  /// Dùng cho những chỗ mà sự kiện sau **thay thế** sự kiện trước: đổi bộ lọc,
  /// đổi tab loại tiền, chọn một cặp khác để xem chi tiết.
  static EventTransformer<E> restartable<E>() =>
      (events, mapper) => _switchMap(events, mapper);

  /// Xử lý lần lượt, không chồng lấn, giữ nguyên thứ tự.
  ///
  /// Dùng cho phân trang và cho mọi thao tác ghi: hai trang xử lý song song sẽ
  /// nối vào danh sách theo thứ tự nào tuỳ lúc, và hai lệnh ghi chồng nhau thì
  /// lệnh sau đọc phải trạng thái trước khi lệnh trước kịp xong.
  static EventTransformer<E> sequential<E>() =>
      (events, mapper) => events.asyncExpand(mapper);

  /// **Bỏ qua** sự kiện mới khi lượt trước còn đang chạy.
  ///
  /// Dùng cho các tác vụ nền dài: bấm "Chạy đối soát" lần thứ hai trong lúc lượt
  /// đầu đang quét không được sinh ra lượt thứ hai, cũng không được xếp hàng chờ
  /// để chạy lại ngay sau đó. Đường dừng một lượt đang chạy là nút Huỷ, một sự
  /// kiện khác hẳn (UC-02 bước 7, UC-08).
  static EventTransformer<E> droppable<E>() =>
      (events, mapper) => _exhaustMap(events, mapper);

  /// Đủ dài để một người gõ liên tục không sinh ra truy vấn nào giữa chừng, đủ
  /// ngắn để kết quả vẫn có cảm giác đi theo tay gõ.
  static const Duration defaultDebounce = Duration(milliseconds: 300);
}

/// Chỉ phát phần tử cuối cùng của mỗi khoảng lặng dài [duration].
///
/// Phần tử đang chờ được **xả ra khi nguồn kết thúc** thay vì bị bỏ: nguồn kết
/// thúc là lúc BLoC đóng, và nuốt mất phím gõ cuối cùng ở đó nghĩa là màn hình
/// đóng lại với một ô tìm kiếm có chữ mà danh sách chưa hề lọc theo.
Stream<T> _debounce<T>(Stream<T> source, Duration duration) {
  final controller = StreamController<T>();
  StreamSubscription<T>? subscription;
  Timer? timer;
  late T pending;
  var hasPending = false;

  controller.onListen = () {
    subscription = source.listen(
      (event) {
        pending = event;
        hasPending = true;
        timer?.cancel();
        timer = Timer(duration, () {
          hasPending = false;
          controller.add(pending);
        });
      },
      onError: controller.addError,
      onDone: () {
        timer?.cancel();
        if (hasPending) controller.add(pending);
        controller.close();
      },
    );
  };
  controller.onCancel = () async {
    timer?.cancel();
    await subscription?.cancel();
  };
  return controller.stream;
}

/// Mỗi phần tử mới huỷ luồng con đang chạy và thay bằng luồng con của chính nó.
Stream<T> _switchMap<S, T>(Stream<S> source, Stream<T> Function(S event) map) {
  final controller = StreamController<T>();
  StreamSubscription<S>? outer;
  StreamSubscription<T>? inner;
  var outerDone = false;

  void closeIfIdle() {
    if (outerDone && inner == null) controller.close();
  }

  controller.onListen = () {
    outer = source.listen(
      (event) {
        // Không `await` phép huỷ: `await` ở đây để nguồn chạy tiếp trong lúc chờ
        // và hai luồng con có thể cùng sống một nhịp.
        inner?.cancel();
        late StreamSubscription<T> current;
        current = map(event).listen(
          controller.add,
          onError: controller.addError,
          // Chỉ luồng con **đang giữ chỗ** mới được tự dọn: một luồng đã bị thay
          // thế mà chạy nốt onDone sẽ xoá mất luồng vừa thế chỗ nó.
          onDone: () {
            if (identical(inner, current)) {
              inner = null;
              closeIfIdle();
            }
          },
        );
        inner = current;
      },
      onError: controller.addError,
      onDone: () {
        outerDone = true;
        closeIfIdle();
      },
    );
  };
  controller.onCancel = () async {
    await outer?.cancel();
    await inner?.cancel();
  };
  return controller.stream;
}

/// Bỏ qua phần tử mới trong lúc luồng con còn đang chạy.
Stream<T> _exhaustMap<S, T>(Stream<S> source, Stream<T> Function(S event) map) {
  final controller = StreamController<T>();
  StreamSubscription<S>? outer;
  StreamSubscription<T>? inner;
  var outerDone = false;

  void closeIfIdle() {
    if (outerDone && inner == null) controller.close();
  }

  controller.onListen = () {
    outer = source.listen(
      (event) {
        if (inner != null) return;
        inner = map(event).listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            inner = null;
            closeIfIdle();
          },
        );
      },
      onError: controller.addError,
      onDone: () {
        outerDone = true;
        closeIfIdle();
      },
    );
  };
  controller.onCancel = () async {
    await outer?.cancel();
    await inner?.cancel();
  };
  return controller.stream;
}
