import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/presentation/shared/failures/feedback_message.dart';
import 'package:ledger_tracer/presentation/shared/widgets/banner_message.dart';
import 'package:ledger_tracer/presentation/shared/widgets/money_text.dart';
import 'package:ledger_tracer/presentation/shared/widgets/verdict_pill.dart';

/// Kiểm thử những quy tắc của hệ thống thiết kế mà mắt người khó bắt được khi
/// chúng trôi đi.
///
/// Không kiểm thử "widget có dựng lên không" — điều đó phép phân tích tĩnh đã
/// nói. Ba bài dưới đây chốt ba quy tắc mà DESIGN.md gọi là bắt buộc, và cả ba
/// đều là loại lỗi sửa một chỗ khác rồi vô tình phá hỏng.
void main() {
  Widget host(Widget child) => MaterialApp(
    theme: LedgerTheme.light(),
    home: Scaffold(body: Center(child: child)),
  );

  group('kênh ngữ nghĩa hướng tiền', () {
    testWidgets('tiền vào và tiền ra dùng hai token màu khác nhau', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const Column(
            children: <Widget>[
              MoneyText('+1.000.000', isIncoming: true),
              MoneyText('−1.000.000', isIncoming: false),
            ],
          ),
        ),
      );

      final incoming = tester.widget<Text>(find.text('+1.000.000'));
      final outgoing = tester.widget<Text>(find.text('−1.000.000'));

      expect(incoming.style?.color, LedgerColors.light.moneyIn);
      expect(outgoing.style?.color, LedgerColors.light.moneyOut);
      // Dạng gốc của ruby chỉ dành cho chỉ báo đồ hoạ; chữ đỏ phải dùng biến thể
      // tối hơn để đạt 4.5:1.
      expect(outgoing.style?.color, isNot(LedgerColors.light.moneyOutGraphic));
    });

    testWidgets('chữ số dùng tabular figures để cột thẳng hàng', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const MoneyText('+1.000.000', isIncoming: true)),
      );

      final text = tester.widget<Text>(find.text('+1.000.000'));
      expect(text.style?.fontFeatures, contains(LedgerText.tnum));
    });
  });

  group('tách hai kênh bằng hình dạng', () {
    testWidgets('pill trạng thái không bao giờ có icon', (tester) async {
      await tester.pumpWidget(
        host(
          const VerdictPill(tone: VerdictTone.confirmed, label: 'Đã xác nhận'),
        ),
      );

      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('banner phản hồi luôn có icon', (tester) async {
      await tester.pumpWidget(
        host(
          const BannerMessage(FeedbackMessage.warning('Có gì đó cần chú ý.')),
        ),
      );

      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
