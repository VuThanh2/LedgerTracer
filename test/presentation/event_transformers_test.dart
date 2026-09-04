import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/presentation/shared/bloc/event_transformers.dart';

/// BLoC bé xíu chỉ để quan sát một transformer làm gì với một dòng sự kiện.
///
/// Mỗi sự kiện chạy một tác vụ dài [_delay] rồi phát ra chính chữ của nó, nên
/// thứ tự và số lượng state phát ra nói đủ về hành vi: cái nào bị bỏ, cái nào bị
/// huỷ giữa chừng, cái nào chạy tới cùng.
final class _ProbeBloc extends Bloc<String, List<String>> {
  _ProbeBloc(EventTransformer<String> transformer, this._delay)
    : super(const <String>[]) {
    on<String>((event, emit) async {
      await Future<void>.delayed(_delay);
      emit(<String>[...state, event]);
    }, transformer: transformer);
  }

  final Duration _delay;
}

void main() {
  const work = Duration(milliseconds: 40);

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 300));

  test('sequential: chạy lần lượt, giữ nguyên thứ tự, không bỏ sót', () async {
    final bloc = _ProbeBloc(EventTransformers.sequential(), work);
    bloc
      ..add('a')
      ..add('b')
      ..add('c');
    await settle();

    expect(bloc.state, <String>['a', 'b', 'c']);
    await bloc.close();
  });

  test('droppable: bỏ qua sự kiện tới khi lượt trước còn chạy', () async {
    final bloc = _ProbeBloc(EventTransformers.droppable(), work);
    // Ba sự kiện tới liền nhau: chỉ cái đầu được chạy, hai cái sau rơi. Đây
    // chính là hành vi cần cho nút "Chạy đối soát" — bấm nhiều lần không được
    // xếp hàng thành nhiều lượt quét.
    bloc
      ..add('a')
      ..add('b')
      ..add('c');
    await settle();

    expect(bloc.state, <String>['a']);
    await bloc.close();
  });

  test('restartable: sự kiện mới huỷ lượt đang chạy', () async {
    final bloc = _ProbeBloc(EventTransformers.restartable(), work);
    bloc
      ..add('a')
      ..add('b')
      ..add('c');
    await settle();

    // Chỉ cái cuối cùng sống sót: hai cái trước bị huỷ trước khi kịp `emit`.
    expect(bloc.state, <String>['c']);
    await bloc.close();
  });

  test(
    'searchInput: chỉ xử lý phím gõ cuối của một khoảng lặng',
    () async {
      final bloc = _ProbeBloc(
        EventTransformers.searchInput(const Duration(milliseconds: 60)),
        Duration.zero,
      );
      bloc
        ..add('n')
        ..add('ng')
        ..add('ngu');
      await settle();

      expect(bloc.state, <String>['ngu']);
      await bloc.close();
    },
  );

  test(
    'searchInput: hai khoảng lặng là hai lần xử lý',
    () async {
      final bloc = _ProbeBloc(
        EventTransformers.searchInput(const Duration(milliseconds: 40)),
        Duration.zero,
      );
      bloc.add('a');
      await Future<void>.delayed(const Duration(milliseconds: 120));
      bloc.add('ab');
      await settle();

      expect(bloc.state, <String>['a', 'ab']);
      await bloc.close();
    },
  );

  test(
    'searchInput: phím gõ cuối không bị nuốt khi dòng sự kiện kết thúc',
    () async {
      // Màn hình đóng ngay sau một phím gõ: nếu debounce nuốt mất nó thì ô tìm
      // kiếm có chữ mà danh sách chưa hề lọc theo.
      final controller = StreamController<String>();
      final transformed = EventTransformers.searchInput(
        const Duration(seconds: 5),
      )(controller.stream, (event) => Stream<String>.value(event));

      final collected = <String>[];
      final done = transformed
          .cast<String>()
          .listen(collected.add)
          .asFuture<void>();

      controller.add('a');
      await controller.close();
      await done;

      expect(collected, <String>['a']);
    },
  );
}
