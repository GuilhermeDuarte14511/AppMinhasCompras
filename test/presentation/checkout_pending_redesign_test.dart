import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/purchase_checkout_dialog.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

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

  testWidgets('pending checkout editorial reference uses actual off total', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    expect(find.text('R\$\u00a063,80'), findsOneWidget);
    expect(find.text('Pendente'), findsOneWidget);
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/checkout_pending_stitch_390.png'),
    );
    expect(
      tester.getSize(find.byTooltip('Corrigir Queijo minas frescal')).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'inclusion updates math prospectively and exclusion restores it',
    (tester) async {
      final list = _list();
      PurchaseCheckoutResult? result;
      await _open(tester, list: list, onResult: (value) => result = value);
      await _togglePending(tester);
      expect(find.text('R\$\u00a082,90'), findsOneWidget);
      expect(find.text('Será comprado'), findsOneWidget);
      expect(list.items.last.isPurchased, isFalse);
      await _togglePending(tester);
      expect(find.text('R\$\u00a063,80'), findsOneWidget);
      expect(find.text('Pendente'), findsOneWidget);
      await tester.tap(find.text('Confirmar fechamento'));
      await tester.pumpAndSettle();
      expect(result!.markPendingAsPurchased, isFalse);
      expect(result!.finalTotalCents, isNull);
      expect(result!.reviewedItems.last.isPurchased, isFalse);
      expect(list.items.last.isPurchased, isFalse);
    },
  );

  testWidgets(
    'included result remains a draft and cancellation discards inclusion',
    (tester) async {
      final list = _list();
      PurchaseCheckoutResult? result;
      await _open(tester, list: list, onResult: (value) => result = value);
      await _togglePending(tester);
      await tester.tap(find.text('Confirmar fechamento'));
      await tester.pumpAndSettle();
      expect(result!.markPendingAsPurchased, isTrue);
      expect(result!.reviewedItems.last.isPurchased, isFalse);
      expect(result!.sendToFinance, isFalse);
      expect(result!.financeAllocations, isEmpty);
      expect(list.items.last.isPurchased, isFalse);
      result = null;
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      await _togglePending(tester);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(list.items.last.isPurchased, isFalse);
    },
  );

  testWidgets('missing price blocks included pending item until corrected', (
    tester,
  ) async {
    final list = _list(missingPrice: true);
    PurchaseCheckoutResult? result;
    await _open(tester, list: list, onResult: (value) => result = value);
    expect(_canConfirm(tester), isTrue);
    await _togglePending(tester);
    expect(_canConfirm(tester), isFalse);
    expect(find.text('Sem preço'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Corrigir Queijo minas frescal'));
    await tester.tap(find.byTooltip('Corrigir Queijo minas frescal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '1910',
    );
    await tester.tap(find.text('Aplicar correção'));
    await tester.pumpAndSettle();
    expect(find.text('R\$\u00a0102,00'), findsOneWidget);
    expect(_canConfirm(tester), isTrue);
    await tester.tap(find.text('Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result!.reviewedItems.last.quantity, 2);
    expect(result!.reviewedItems.last.unitPrice, 19.1);
    expect(result!.reviewedItems.last.isPurchased, isFalse);
    expect(list.items.last.quantity, 1);
    expect(list.items.last.unitPrice, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'receipt override permits missing prices while preserving reviewed items',
    (tester) async {
      final list = _list(missingPrice: true);
      PurchaseCheckoutResult? result;
      await _open(tester, list: list, onResult: (value) => result = value);
      await _togglePending(tester);
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor final pago'),
        '8000',
      );
      await tester.pumpAndSettle();
      expect(_canConfirm(tester), isTrue);
      await tester.tap(find.text('Confirmar fechamento'));
      await tester.pumpAndSettle();
      expect(result!.markPendingAsPurchased, isTrue);
      expect(result!.finalTotalCents, 8000);
      expect(result!.reviewedItems.last.unitPrice, 0);
      expect(list.items.last.isPurchased, isFalse);
    },
  );

  testWidgets(
    'pending total revalidates funds and finance receives actual included total',
    (tester) async {
      await _open(tester, workspace: _workspace(7000));
      expect(_canConfirm(tester), isTrue);
      await _togglePending(tester);
      expect(_canConfirm(tester), isFalse);
      await _togglePending(tester);
      expect(_canConfirm(tester), isTrue);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      PurchaseCheckoutResult? result;
      await _open(
        tester,
        workspace: _workspace(10000),
        onResult: (value) => result = value,
      );
      await _togglePending(tester);
      await tester.tap(find.text('Confirmar fechamento'));
      await tester.pumpAndSettle();
      expect(result!.sendToFinance, isTrue);
      expect(result!.financeAllocations.single.amountCents, 8290);
      expect(result!.financeAllocations.single.sourceId, 'debit');
    },
  );

  testWidgets(
    'compact dark pending rows scroll with enlarged text and keyboard',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _open(tester, dark: true, scale: 1.5);
      await _togglePending(tester);
      await tester.ensureVisible(
        find.byTooltip('Corrigir Queijo minas frescal'),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(TextField, 'Valor final pago'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor final pago'),
        '8290',
      );
      await tester.pumpAndSettle();
      expect(_canConfirm(tester), isTrue);
      expect(
        tester
            .getBottomRight(
              find.widgetWithText(FilledButton, 'Confirmar fechamento'),
            )
            .dy,
        lessThanOrEqualTo(388),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

bool _canConfirm(WidgetTester tester) =>
    tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Confirmar fechamento'),
        )
        .onPressed !=
    null;

Future<void> _togglePending(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Incluir itens pendentes'));
  await tester.tap(find.text('Incluir itens pendentes'));
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester tester, {
  ShoppingListModel? list,
  FinanceWorkspace? workspace,
  ValueChanged<PurchaseCheckoutResult?>? onResult,
  bool dark = false,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        dark ? ThemeData.dark() : ThemeData.light(),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showPurchaseCheckoutDialog(
                  context,
                  list: list ?? _list(),
                  financeWorkspace: workspace,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

ShoppingListModel _list({bool missingPrice = false}) => ShoppingListModel(
  id: 'weekly',
  name: 'Compras da semana',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 10),
  items: [
    const ShoppingItem(
      id: 'coffee',
      name: 'Café torrado e moído 500g',
      quantity: 1,
      unitPrice: 24.9,
      isPurchased: true,
    ),
    const ShoppingItem(
      id: 'oil',
      name: 'Azeite de oliva extra virgem 500ml',
      quantity: 1,
      unitPrice: 38.9,
      isPurchased: true,
    ),
    ShoppingItem(
      id: 'cheese',
      name: 'Queijo minas frescal',
      quantity: 1,
      unitPrice: missingPrice ? 0 : 19.1,
      isPurchased: false,
    ),
  ],
);

FinanceWorkspace _workspace(int cents) => FinanceWorkspace(
  householdId: 'home',
  householdName: 'Casa',
  cards: const [],
  paymentSources: [
    FinancePaymentSource(
      id: 'debit',
      kind: FinancePaymentSourceKind.debit,
      name: 'Conta da casa',
      availableCents: cents,
      colorHex: '#1F412D',
    ),
  ],
  categories: const [
    FinanceCategory(
      id: 'food',
      name: 'Alimentação',
      iconKey: 'shopping_cart',
      colorHex: '#1F412D',
    ),
  ],
  asOf: DateTime(2026, 10, 10),
);
