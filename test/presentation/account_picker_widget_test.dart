import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledger_tracer/app/theme.dart';
import 'package:ledger_tracer/domain/entities/bank_account.dart';
import 'package:ledger_tracer/presentation/import/widgets/account_picker.dart';

void main() {
  final created = DateTime(2026);
  final accounts = <BankAccount>[
    BankAccount(
      accountId: 1,
      displayName: 'Vietinbank vận hành',
      createdAt: created,
    ),
    BankAccount(
      accountId: 2,
      displayName: 'Techcombank hộ kinh doanh',
      accountNumber: '19036521',
      createdAt: created,
    ),
  ];

  Future<List<int?>> pump(
    WidgetTester tester, {
    int? selectedId,
    List<BankAccount>? list,
  }) async {
    final changes = <int?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: LedgerTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 260,
              child: AccountPicker(
                accounts: list ?? accounts,
                selectedId: selectedId,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  testWidgets('mở menu và chọn một tài khoản', (tester) async {
    final changes = await pump(tester);
    expect(find.text('Choose an account…'), findsOneWidget);
    expect(find.byTooltip('Clear selection'), findsNothing);

    await tester.tap(find.byType(AccountPicker));
    await tester.pumpAndSettle();
    // Số tài khoản đã học hiện dưới tên để phân biệt.
    expect(find.text('19036521'), findsOneWidget);
    // Chưa chọn gì thì không có mục bỏ chọn.
    expect(find.text('Clear selection'), findsNothing);

    await tester.tap(find.text('Techcombank hộ kinh doanh'));
    await tester.pumpAndSettle();
    expect(changes, <int?>[2]);
  });

  testWidgets('bỏ chọn bằng nút × trên ô', (tester) async {
    final changes = await pump(tester, selectedId: 1);
    expect(find.text('Vietinbank vận hành'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear selection'));
    await tester.pumpAndSettle();
    expect(changes, <int?>[null]);
  });

  testWidgets('bỏ chọn bằng mục cuối menu, dòng đang chọn có dấu ✓', (
    tester,
  ) async {
    final changes = await pump(tester, selectedId: 1);

    await tester.tap(find.byType(AccountPicker));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.widgetWithText(MenuItemButton, 'Clear selection'));
    await tester.pumpAndSettle();
    expect(changes, <int?>[null]);
  });

  testWidgets('chưa có tài khoản thì chỉ đường thay vì mở menu rỗng', (
    tester,
  ) async {
    await pump(tester, list: const <BankAccount>[]);
    await tester.tap(find.byType(AccountPicker));
    await tester.pumpAndSettle();
    expect(find.textContaining('Settings → Accounts'), findsOneWidget);
  });
}
