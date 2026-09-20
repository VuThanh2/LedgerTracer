import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';

/// Hình của nút là một quyết định của **hệ thống**, không của từng màn hình.
///
/// Ba kiểu nút đều lấy hình từ `ThemeData`, nên một bài kiểm ở đây phủ mọi nút
/// trong ứng dụng — kể cả những nút chưa được viết. Kiểm bằng cách dựng một nút
/// rồi soi pixel thì chỉ phủ đúng nút ấy.
void main() {
  final theme = LedgerTheme.light();

  BorderRadius radiusOf(ButtonStyle? style) {
    final shape = style?.shape?.resolve(const <WidgetState>{});
    return (shape! as RoundedRectangleBorder).borderRadius as BorderRadius;
  }

  test('ba kiểu nút dùng chung một hình, bo lg chứ không phải pill', () {
    final styles = <String, ButtonStyle?>{
      'filled': theme.filledButtonTheme.style,
      'outlined': theme.outlinedButtonTheme.style,
      'text': theme.textButtonTheme.style,
    };

    for (final entry in styles.entries) {
      expect(radiusOf(entry.value), Corner.radiusLg, reason: entry.key);
    }
  });

  test('pill vẫn là hình của pill trạng thái và chip', () {
    // Ranh giới phải giữ: hình dạng là kênh phân biệt "thứ bấm được" với "nhãn
    // của một dòng". Nếu ai đó hạ `pill` xuống cùng bán kính với nút, kênh đó
    // biến mất và bài kiểm này phải đỏ.
    expect(Corner.pill, isNot(Corner.radiusLg));
    expect(Corner.pill.topLeft.x, greaterThan(100));
  });

  test('ô nhập giữ bán kính riêng, nhỏ hơn nút', () {
    final border = theme.inputDecorationTheme.enabledBorder!;
    final radius = (border as OutlineInputBorder).borderRadius;
    expect(radius, Corner.radiusSm);
    expect(radius.topLeft.x, lessThan(Corner.radiusLg.topLeft.x));
  });
}
