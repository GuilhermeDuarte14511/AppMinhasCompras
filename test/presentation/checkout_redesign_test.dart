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

  testWidgets('checkout mobile editorial visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester, workspace: _workspace());
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/checkout_stitch_390.png'),
    );
    await tester.ensureVisible(find.text('Lançar no Minhas Finanças'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/checkout_finance_stitch_390.png'),
    );
    expect(find.text('Fechamento de compra'), findsOneWidget);
    expect(find.textContaining('Pix'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending selection and cancellation preserve source items', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Incluir itens pendentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result?.markPendingAsPurchased, isTrue);
    expect(result?.reviewedItems.last.isPurchased, isFalse);
    expect(result?.sendToFinance, isFalse);
    expect(result?.financeAllocations, isEmpty);
    result = null;
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('finance load failure remains visible and allows local close', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    await _open(
      tester,
      error: 'Não foi possível carregar os saldos.',
      onResult: (value) => result = value,
    );
    expect(
      find.textContaining('A compra ainda pode ser fechada.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result?.sendToFinance, isFalse);
    expect(result?.financeAllocations, isEmpty);
  });

  testWidgets('compact dark checkout supports enlarged text and keyboard', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _open(tester, dark: true, scale: 1.5);
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
      '3780',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar fechamento'),
          )
          .onPressed,
      isNotNull,
    );
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byTooltip('Corrigir Café especial torrado e moído 250g'),
    );
    await tester.tap(
      find.byTooltip('Corrigir Café especial torrado e moído 250g'),
    );
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Valor unitário'),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '1990',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester tester, {
  FinanceWorkspace? workspace,
  String? error,
  ValueChanged<PurchaseCheckoutResult?>? onResult,
  bool dark = false,
  double scale = 1,
}) async {
  final theme = editorialWorkspaceTheme(
    dark ? ThemeData.dark() : ThemeData.light(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
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
                  list: _list(),
                  financeWorkspace: workspace,
                  financeLoadError: error,
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

ShoppingListModel _list() => ShoppingListModel(
  id: 'checkout',
  name: 'Compras da semana',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 10),
  items: const [
    ShoppingItem(
      id: 'coffee',
      name: 'Café especial torrado e moído 250g',
      quantity: 2,
      unitPrice: 18.9,
      isPurchased: true,
    ),
    ShoppingItem(
      id: 'milk',
      name: 'Leite integral',
      quantity: 1,
      unitPrice: 6.9,
      isPurchased: false,
    ),
  ],
);

FinanceWorkspace _workspace() => FinanceWorkspace(
  householdId: 'home',
  householdName: 'Casa',
  cards: const [],
  paymentSources: const [
    FinancePaymentSource(
      id: 'debit',
      kind: FinancePaymentSourceKind.debit,
      name: 'Conta da casa',
      availableCents: 50000,
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
