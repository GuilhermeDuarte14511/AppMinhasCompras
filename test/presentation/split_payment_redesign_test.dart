import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/finance_split_payment_editor.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

const sources = [
  FinancePaymentSource(
    id: 'va',
    kind: FinancePaymentSourceKind.foodVoucher,
    name: 'Alelo',
    availableCents: 8000,
    colorHex: '#006B45',
  ),
  FinancePaymentSource(
    id: 'debit',
    kind: FinancePaymentSourceKind.debit,
    name: 'Conta corrente',
    availableCents: 100000,
    colorHex: '#006B45',
  ),
];

Future<void> open(
  WidgetTester tester,
  ValueChanged<List<FinancePaymentAllocation>?> onChanged, {
  bool compact = false,
  int total = 18430,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: compact ? Brightness.dark : Brightness.light),
      ),
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(compact ? 1.5 : 1),
              ),
              child: FinanceSplitPaymentEditor(
                totalCents: total,
                sources: sources,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  testWidgets('remaining shortcut recalculates excluding its own amount', (
    tester,
  ) async {
    List<FinancePaymentAllocation>? value;
    await open(tester, (v) => value = v, total: 12000);
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-0')),
      '8000',
    );
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-1')),
      '1000',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('split-remaining-1')));
    await tester.tap(find.byKey(const ValueKey('split-remaining-1')));
    await tester.pumpAndSettle();
    expect(value?.map((a) => a.amountCents), [8000, 4000]);
  });
  testWidgets(
    'remaining over available stays invalid and visible instead of clamping',
    (tester) async {
      List<FinancePaymentAllocation>? value;
      await open(tester, (v) => value = v, total: 12000);
      await tester.enterText(find.byKey(const ValueKey('split-amount-0')), '1');
      await tester.tap(find.byKey(const ValueKey('split-remaining-0')));
      await tester.pumpAndSettle();
      expect(value, isNull);
      expect(
        find.text('Valor acima do saldo ou limite disponível.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('split-amount-0')))
            .controller!
            .text,
        endsWith('120,00'),
      );
    },
  );
  testWidgets('remaining never assigns a negative amount', (tester) async {
    List<FinancePaymentAllocation>? value;
    await open(tester, (v) => value = v, total: 12000);
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-0')),
      '8000',
    );
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-1')),
      '13000',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('split-remaining-0')));
    await tester.tap(find.byKey(const ValueKey('split-remaining-0')));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('split-amount-0')))
          .controller!
          .text,
      endsWith('0,00'),
    );
  });
  testWidgets(
    'real checkout blocks invalid split and returns both allocations',
    (tester) async {
      PurchaseCheckoutResult? result;
      final now = DateTime(2026, 10, 10);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPurchaseCheckoutDialog(
                    context,
                    list: ShoppingListModel(
                      id: 'split',
                      name: 'Compra',
                      createdAt: now,
                      updatedAt: now,
                      items: const [
                        ShoppingItem(
                          id: 'item',
                          name: 'Mercado',
                          quantity: 1,
                          unitPrice: 120,
                          isPurchased: true,
                        ),
                      ],
                    ),
                    financeWorkspace: FinanceWorkspace(
                      householdId: 'home',
                      householdName: 'Casa',
                      cards: const [],
                      categories: const [],
                      paymentSources: sources,
                      asOf: now,
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dividir pagamento'));
      await tester.tap(find.text('Dividir pagamento'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar fechamento'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('split-amount-0')));
      await tester.enterText(
        find.byKey(const ValueKey('split-amount-0')),
        '8000',
      );
      await tester.ensureVisible(find.text('Adicionar pagamento'));
      await tester.tap(find.text('Adicionar pagamento'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('split-amount-1')));
      await tester.enterText(
        find.byKey(const ValueKey('split-amount-1')),
        '2000',
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar fechamento'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('split-remaining-1')),
      );
      await tester.tap(find.byKey(const ValueKey('split-remaining-1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar fechamento'),
      );
      await tester.pumpAndSettle();
      expect(result?.financeAllocations.map((a) => a.sourceId), [
        'va',
        'debit',
      ]);
      expect(result?.financeAllocations.map((a) => a.amountCents), [
        8000,
        4000,
      ]);
      expect(result?.finalTotalCents, isNull);
      expect(result?.reviewedItems.single.unitPrice, 120);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'preferred source, five-source cap, unique choices and removal stay intact',
    (tester) async {
      final many = List.generate(
        6,
        (i) => FinancePaymentSource(
          id: 'source-$i',
          kind: FinancePaymentSourceKind.debit,
          name: 'Conta $i',
          availableCents: 10000,
          colorHex: '#006B45',
        ),
      );
      List<FinancePaymentAllocation>? value;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: FinanceSplitPaymentEditor(
                sources: many,
                totalCents: 1000,
                preferredSourceId: 'source-3',
                onChanged: (v) => value = v,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(value?.single.sourceId, 'source-3');
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.text('Adicionar pagamento'));
        await tester.tap(find.text('Adicionar pagamento'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Adicionar pagamento'), findsNothing);
      expect(value, isNull);
      final dropdowns = tester
          .widgetList<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .toList();
      expect(dropdowns.length, 5);
      final menus = tester.widgetList<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(menus.map((m) => m.value).toSet().length, 5);
      expect(menus.every((m) => m.items!.length == 2), isTrue);
      for (var i = 4; i > 0; i--) {
        await tester.ensureVisible(
          find.byTooltip('Remover pagamento ${i + 1}'),
        );
        await tester.tap(find.byTooltip('Remover pagamento ${i + 1}'));
        await tester.pumpAndSettle();
      }
      expect(value?.single.sourceId, 'source-3');
      expect(value?.single.amountCents, 1000);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('editorial split golden with real allocations', (tester) async {
    await open(tester, (_) {});
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-0')),
      '8000',
    );
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/split_payment_stitch_390.png'),
    );
  });
  testWidgets('compact dark enlarged text with keyboard remains scrollable', (
    tester,
  ) async {
    await open(tester, (_) {}, compact: true, total: 12000);
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Adicionar pagamento'));
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('split-amount-1')));
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-1')),
      '4000',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
