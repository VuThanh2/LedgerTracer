import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/domain/value_objects/currency.dart';
import 'package:ledger_tracer/domain/value_objects/money.dart';
import 'package:ledger_tracer/presentation/transactions/view_models/transaction_row_view_model.dart';
import 'package:ledger_tracer/presentation/transactions/widgets/transaction_detail_pane.dart';

void main() {
  TransactionDetailViewModel detail({String counterparty = 'NGUYEN VAN A'}) =>
      TransactionDetailViewModel(
        transactionId: 1,
        accountId: 1,
        dateText: '10/03/2025',
        accountName: 'Vietinbank vận hành',
        amountText: '−500.000 VND',
        amount: const Money(-500000, Currency.vnd),
        counterpartyText: counterparty,
        descriptionText: 'CK tien hang thang 3 cho nha cung cap',
        confirmedPairId: null,
        isManuallyEdited: false,
        sourceLineText: '—',
        importedAtText: '11/03/2025 09:30',
      );

  Future<void> pump(
    WidgetTester tester,
    TransactionDetailViewModel model,
    double width,
  ) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light(),
        home: Scaffold(
          body: TransactionDetailPane(
            detail: model,
            onEdit: () {},
            onDelete: () {},
            onOpenReconciliation: () {},
          ),
        ),
      ),
    );
  }

  for (final width in <double>[TransactionDetailPane.paneWidth, 412]) {
    testWidgets('chia hai nhóm, không tràn ở bề ngang ${width.toInt()}px', (
      tester,
    ) async {
      await pump(tester, detail(), width);
      expect(tester.takeException(), isNull);
      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.text('SOURCE'), findsOneWidget);
      expect(find.text('NGUYEN VAN A'), findsOneWidget);
    });
  }

  testWidgets('trường trống hiện "—" nhạt màu, không đậm như dữ liệu', (
    tester,
  ) async {
    await pump(tester, detail(counterparty: ''), 412);
    final dashes = tester.widgetList<SelectableText>(
      find.widgetWithText(SelectableText, '—'),
    );
    // Đối tác trống và dòng nguồn không rõ.
    expect(dashes, hasLength(2));
    for (final dash in dashes) {
      expect(dash.style!.fontWeight, FontWeight.w400);
    }
  });
}
