import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';

void main() {
  testWidgets('requires and returns the selected finance card at checkout', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    final now = DateTime(2026, 9, 1);
    final list = ShoppingListModel(
      id: 'list-id',
      name: 'Compra da semana',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Mercado',
          quantity: 1,
          unitPrice: 12,
          isPurchased: true,
        ),
      ],
    );
    final workspace = FinanceWorkspace(
      householdId: 'household-id',
      householdName: 'Casa',
      cards: const [
        FinanceCard(
          id: 'card-id',
          name: 'Nubank',
          lastDigits: '1234',
          closingDay: 20,
          dueDay: 27,
          limitCents: 500000,
          usedCents: 125050,
          availableCents: 374950,
          colorHex: '#7B2CBF',
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'category-id',
          name: 'Mercado',
          iconKey: 'shopping_cart',
          colorHex: '#00897B',
        ),
      ],
      asOf: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showPurchaseCheckoutDialog(
                  context,
                  list: list,
                  financeWorkspace: workspace,
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

    expect(find.text('Lançar no Minhas Finanças'), findsOneWidget);
    expect(find.textContaining('Nubank'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
    await tester.pumpAndSettle();

    expect(result?.sendToFinance, isTrue);
    expect(result?.financeCardId, 'card-id');
    expect(result?.financeCategoryId, 'category-id');
  });

  testWidgets('permite lançar a compra usando um VR sincronizado', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    final now = DateTime(2026, 9, 3);
    final list = ShoppingListModel(
      id: 'list-id',
      name: 'Almoço da semana',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Mercado',
          quantity: 1,
          unitPrice: 12,
          isPurchased: true,
        ),
      ],
      paymentBalances: const [
        PaymentBalance(
          id: 'balance-id',
          name: 'VR Alelo',
          type: PaymentBalanceType.mealVoucher,
          amount: 250,
          financeSourceId: 'vr-id',
          financeSourceKind: 'mealVoucher',
        ),
      ],
    );
    final workspace = FinanceWorkspace(
      householdId: 'household-id',
      householdName: 'Casa',
      cards: const [],
      paymentSources: const [
        FinancePaymentSource(
          id: 'vr-id',
          kind: FinancePaymentSourceKind.mealVoucher,
          name: 'VR Alelo',
          availableCents: 85000,
          colorHex: '#0D7B9A',
        ),
      ],
      categories: const [],
      asOf: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showPurchaseCheckoutDialog(
                  context,
                  list: list,
                  financeWorkspace: workspace,
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

    expect(find.text('MEIO DE PAGAMENTO'), findsOneWidget);
    expect(find.textContaining('VR Alelo'), findsOneWidget);
    expect(
      find.textContaining('Não reduzem o saldo previsto do mês'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
    await tester.pumpAndSettle();

    expect(result?.financePaymentSourceId, 'vr-id');
    expect(
      result?.financePaymentSourceKind,
      FinancePaymentSourceKind.mealVoucher.wireValue,
    );
    expect(result?.reviewedItems.single.name, 'Mercado');
  });

  testWidgets('impede lançamento quando o saldo sincronizado é insuficiente', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    final now = DateTime(2026, 9, 3);
    final list = ShoppingListModel(
      id: 'list-id',
      name: 'Compra grande',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'item-id',
          name: 'Mercado',
          quantity: 1,
          unitPrice: 120,
          isPurchased: true,
        ),
      ],
    );
    final workspace = FinanceWorkspace(
      householdId: 'household-id',
      householdName: 'Casa',
      cards: const [],
      paymentSources: const [
        FinancePaymentSource(
          id: 'va-id',
          kind: FinancePaymentSourceKind.foodVoucher,
          name: 'VA Flash',
          availableCents: 5000,
          colorHex: '#0D7B9A',
        ),
      ],
      categories: const [],
      asOf: now,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showPurchaseCheckoutDialog(
                  context,
                  list: list,
                  financeWorkspace: workspace,
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

    expect(find.textContaining('não cobre esta compra'), findsOneWidget);
    final closeButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar fechamento'),
    );
    expect(closeButton.onPressed, isNull);
    await tester.tap(find.text('Alterar valor final'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar fechamento'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor final pago'),
      '4000',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result?.financeAllocations.single.amountCents, 4000);
    expect(result?.finalTotalCents, 4000);
    expect(result?.reviewedItems.single.unitPrice, 120);
  });

  testWidgets('permite alterar somente o valor final da compra', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    final now = DateTime(2026, 9, 16);
    final list = ShoppingListModel(
      id: 'review-list',
      name: 'Compra conferida',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Mercado',
          quantity: 1,
          unitPrice: 12,
          isPurchased: true,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showPurchaseCheckoutDialog(context, list: list);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Conferir compra'), findsOneWidget);
    expect(find.text('Total calculado'), findsOneWidget);
    expect(find.text('Alterar valor final'), findsOneWidget);
    await tester.tap(find.text('Alterar valor final'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Valor final pago'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Valor final pago'),
      '1300',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ajuste de'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar fechamento'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Valor final pago'),
      '1200',
    );
    await tester.pumpAndSettle();
    expect(find.text('Valor final igual ao total dos itens'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor final pago'),
      '950',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result?.finalTotalCents, 950);
    expect(result?.reviewedItems.single.unitPrice, 12);
  });

  testWidgets('corrige item sem sair da conferência', (tester) async {
    PurchaseCheckoutResult? result;
    final now = DateTime(2026, 9, 16);
    final list = ShoppingListModel(
      id: 'correction-list',
      name: 'Compra com pendência',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'milk',
          name: 'Leite',
          quantity: 1,
          unitPrice: 0,
          isPurchased: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showPurchaseCheckoutDialog(context, list: list);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('1 item precisa de preço.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar fechamento'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byTooltip('Corrigir Leite'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '1200',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar correção'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,00'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
    await tester.pumpAndSettle();
    expect(result?.reviewedItems.single.unitPrice, 12);
  });

  testWidgets('conferência cabe em uma tela de 320 pixels', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final now = DateTime(2026, 9, 16);
    final list = ShoppingListModel(
      id: 'compact-list',
      name: 'Compra no celular',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Arroz integral',
          quantity: 2,
          unitPrice: 15,
          isPurchased: true,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showPurchaseCheckoutDialog(context, list: list),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Conferir compra'), findsOneWidget);
    expect(find.text('Confirmar fechamento'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('permite incluir e retirar itens pendentes', (tester) async {
    final now = DateTime(2026, 9, 27);
    final list = ShoppingListModel(
      id: 'pending-review',
      name: 'Teste',
      createdAt: now,
      updatedAt: now,
      items: const [
        ShoppingItem(
          id: 'pending',
          name: 'Arroz',
          quantity: 1,
          unitPrice: 10,
          isPurchased: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showPurchaseCheckoutDialog(context, list: list),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(SwitchListTile, 'Incluir itens pendentes'),
    );
    await tester.tap(find.text('Incluir itens pendentes'));
    await tester.pumpAndSettle();
    expect(find.text('Incluir itens pendentes'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Incluir itens pendentes'),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.text('Incluir itens pendentes'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Incluir itens pendentes'),
          )
          .value,
      isFalse,
    );
  });
}
