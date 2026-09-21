import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/domain/repositories/transaction_repository.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/presentation/shared/failures/feedback_message.dart';
import 'package:ledger_tracer/presentation/shared/widgets/filter_chip_bar.dart';
import 'package:ledger_tracer/presentation/shared/widgets/notice_overlay.dart';
import 'package:ledger_tracer/presentation/transactions/bloc/transactions_state.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_filter_draft.dart';
import 'package:ledger_tracer/presentation/transactions/widgets/filter_panel.dart';

void main() {
  group('Filter Panel', () {
    /// Dựng panel với một BLoC giả tối giản: bản nháp nằm ở đây, panel báo đổi
    /// thì cập nhật, "Clear all" thì về rỗng — đúng như `TransactionsBloc`.
    late TransactionFilterDraft draft;

    Future<void> pumpPanel(
      WidgetTester tester, {
      Map<int, String> accountNames = const <int, String>{},
    }) async {
      draft = const TransactionFilterDraft(currency: Currency.vnd);
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              // Bề ngang của bottom sheet trên điện thoại. Font thử nghiệm của
              // flutter_test rộng hơn Inter, nên ở 312px (panel của bản rộng) nút
              // chân panel tràn — lỗi của font test, không phải của bố cục.
              builder: (context, setState) => SizedBox(
                width: 400,
                child: FilterPanel(
                  state: TransactionsState(
                    draft: draft,
                    accountNames: accountNames,
                    currencies: const <CurrencyUsage>[
                      CurrencyUsage(
                        currency: Currency.vnd,
                        transactionCount: 1,
                      ),
                    ],
                  ),
                  onDraftChanged: (next) => setState(() => draft = next),
                  onApply: () {},
                  onClear: () => setState(
                    () => draft = const TransactionFilterDraft(
                      currency: Currency.vnd,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Finder field(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

    String textOf(WidgetTester tester, Finder finder) =>
        tester.widget<TextField>(finder).controller!.text;

    testWidgets('"Clear all" xoá cả chữ trong các ô, không chỉ bản nháp', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPanel(tester);

      await tester.enterText(field('From').first, '100000');
      await tester.enterText(field('From').last, '01/03/2025');
      await tester.pump();

      await tester.tap(find.text('Clear all'));
      await tester.pump();

      expect(textOf(tester, field('From').first), isEmpty);
      expect(textOf(tester, field('From').last), isEmpty);
    });

    testWidgets('ngày gõ sai thì báo lỗi và khoá Apply; sửa lại thì mở', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPanel(tester);

      FilledButton apply() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Apply'),
      );

      await tester.enterText(field('From').last, '32/13/2025');
      await tester.pump();
      expect(find.text('Use dd/mm/yyyy'), findsOneWidget);
      expect(apply().onPressed, isNull);

      await tester.enterText(field('From').last, '01/03/2025');
      await tester.pump();
      expect(find.text('Use dd/mm/yyyy'), findsNothing);
      expect(apply().onPressed, isNotNull);
    });
  });

  group('Filter Panel — tài khoản và loại tiền', () {
    // Dùng lại cách dựng ở nhóm trên nhưng cần danh sách tài khoản.
    testWidgets('tích được nhiều tài khoản; "All accounts" bỏ hết', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var draft = const TransactionFilterDraft();
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 400,
                child: FilterPanel(
                  state: TransactionsState(
                    draft: draft,
                    accountNames: const <int, String>{1: 'A', 2: 'B', 3: 'C'},
                  ),
                  onDraftChanged: (next) => setState(() => draft = next),
                  onApply: () {},
                  onClear: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('C'));
      await tester.pump();
      expect(draft.accountIds, <int>{1, 3});

      // Bỏ tích một ô.
      await tester.tap(find.text('A'));
      await tester.pump();
      expect(draft.accountIds, <int>{3});

      // Tích đủ cả ba cũng là "mọi tài khoản".
      await tester.tap(find.text('A'));
      await tester.pump();
      await tester.tap(find.text('B'));
      await tester.pump();
      expect(draft.accountIds, isEmpty);

      await tester.tap(find.text('C'));
      await tester.pump();
      await tester.tap(find.text('All accounts'));
      await tester.pump();
      expect(draft.accountIds, isEmpty);
    });

    testWidgets('chip loại tiền ôm theo chữ, không trải hết bề ngang', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Wrap(
                children: <Widget>[
                  ToggleChip(label: 'VND', selected: true, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(ToggleChip)).width, lessThan(120));
    });
  });

  group('Notice Overlay', () {
    Future<BuildContext> pumpHost(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          theme: LedgerTheme.light(),
          builder: (context, child) => NoticeOverlay(child: child!),
          home: Builder(
            builder: (context) {
              captured = context;
              return const Scaffold();
            },
          ),
        ),
      );
      return captured;
    }

    testWidgets('bản hẹp chỉ giữ thẻ mới nhất', (tester) async {
      final context = await pumpHost(tester, 400);
      showNotice(context, const FeedbackMessage.success('Pair confirmed.'));
      showNotice(context, const FeedbackMessage.info('Pair rejected.'));
      await tester.pump();

      expect(find.text('Pair confirmed.'), findsNothing);
      expect(find.text('Pair rejected.'), findsOneWidget);
      await tester.pump(NoticeOverlay.visibleWithActionFor);
    });

    testWidgets('cùng một câu lặp lại thì không xếp thành nhiều thẻ', (
      tester,
    ) async {
      final context = await pumpHost(tester, 1400);
      for (var i = 0; i < 4; i++) {
        showNotice(context, const FeedbackMessage.success('Pair confirmed.'));
      }
      await tester.pump();
      expect(find.text('Pair confirmed.'), findsOneWidget);

      await tester.pump(NoticeOverlay.visibleFor);
      await tester.pump();
      expect(find.text('Pair confirmed.'), findsNothing);
    });

    testWidgets('bản rộng giữ tối đa hai thẻ', (tester) async {
      final context = await pumpHost(tester, 1400);
      for (final text in <String>['One.', 'Two.', 'Three.']) {
        showNotice(context, FeedbackMessage.info(text));
      }
      await tester.pump();
      expect(find.text('One.'), findsNothing);
      expect(find.text('Two.'), findsOneWidget);
      expect(find.text('Three.'), findsOneWidget);
      await tester.pump(NoticeOverlay.visibleFor);
    });
  });
}
