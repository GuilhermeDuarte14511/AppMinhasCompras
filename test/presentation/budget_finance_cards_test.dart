import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/budget_editor_dialog.dart';
import 'package:lista_compras_material/src/presentation/dialogs/list_name_dialog.dart';

void main() {
  testWidgets('salvar orçamento mantém as duas fontes e seus vínculos', (
    tester,
  ) async {
    BudgetEditorResult? result;
    final repository = _BudgetFinanceRepository();
    const balances = [
      PaymentBalance(
        id: 'local-pluxee',
        name: 'Pluxee momo',
        type: PaymentBalanceType.foodVoucher,
        amount: 814,
        financeSourceId: 'pluxee-id',
        financeSourceKind: 'foodVoucher',
      ),
      PaymentBalance(
        id: 'local-alelo',
        name: 'VA ALELO',
        type: PaymentBalanceType.foodVoucher,
        amount: 80,
        financeSourceId: 'alelo-id',
        financeSourceKind: 'foodVoucher',
      ),
    ];
    await _openBudget(
      tester,
      repository: repository,
      initialPaymentBalances: balances,
      onResult: (value) => result = value,
    );
    await tester.enterText(find.byKey(const Key('budget_field')), '90000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').hitTestable());
    await tester.pumpAndSettle();
    expect(result?.value, 900);
    expect(
      result!.paymentBalances!.map((balance) => balance.toJson()).toList(),
      balances.map((balance) => balance.toJson()).toList(),
    );
    expect(repository.submittedPurchases, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('orçamento busca cartões do Finanças e permite duas fontes', (
    tester,
  ) async {
    BudgetEditorResult? result;
    final repository = _BudgetFinanceRepository();
    await _openBudget(
      tester,
      repository: repository,
      onResult: (value) => result = value,
    );
    await tester.enterText(find.byKey(const Key('budget_field')), '81400');
    await tester.ensureVisible(find.text('Selecionar cartões'));
    await tester.tap(find.text('Selecionar cartões'));
    await tester.pumpAndSettle();
    expect(find.text('Saldos de pagamento'), findsOneWidget);
    for (final name in ['Pluxee momo', 'VA ALELO']) {
      await tester.ensureVisible(find.text('Novo saldo'));
      await tester.tap(find.text('Novo saldo'));
      await tester.pumpAndSettle();
      expect(find.text('Meios do Minhas Finanças'), findsOneWidget);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar nesta lista'));
      await tester.pumpAndSettle();
    }
    expect(repository.workspaceLoads, greaterThanOrEqualTo(2));
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').hitTestable());
    await tester.pumpAndSettle();
    expect(result?.value, 814);
    expect(result!.paymentBalances, hasLength(2));
    expect(result!.paymentBalances!.map((balance) => balance.financeSourceId), [
      'pluxee-id',
      'alelo-id',
    ]);
    expect(result!.paymentBalances!.map((balance) => balance.amount), [
      814,
      80,
    ]);
    expect(repository.submittedPurchases, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'criar lista conserva nome, orçamento automático e dois cartões',
    (tester) async {
      ListSetupResult? result;
      final repository = _BudgetFinanceRepository();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showListSetupDialog(
                    context,
                    title: 'Nova lista',
                    confirmLabel: 'Criar lista',
                    financeRepository: repository,
                  );
                },
                child: const Text('Abrir criação'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir criação'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('list_name_field')),
        '  Mercado de hoje  ',
      );
      await tester.tap(find.text('Definir orçamento e cartões'));
      await tester.pumpAndSettle();
      await _selectTwoCards(tester);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('budget_field')))
            .controller!
            .text,
        contains('894,00'),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Salvar').hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Criar lista').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(result?.name, 'Mercado de hoje');
      expect(result?.budget, 894);
      expect(
        result!.paymentBalances.map((balance) => balance.financeSourceId),
        ['pluxee-id', 'alelo-id'],
      );
      expect(result!.paymentBalances.map((balance) => balance.amount), [
        814,
        80,
      ]);
      expect(repository.workspaceLoads, greaterThanOrEqualTo(2));
      expect(repository.submittedPurchases, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _selectTwoCards(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Selecionar cartões').hitTestable());
  await tester.tap(find.text('Selecionar cartões').hitTestable());
  await tester.pumpAndSettle();
  for (final name in ['Pluxee momo', 'VA ALELO']) {
    await tester.ensureVisible(find.text('Novo saldo').hitTestable());
    await tester.tap(find.text('Novo saldo').hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).hitTestable());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar nesta lista').hitTestable());
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Salvar').hitTestable());
  await tester.pumpAndSettle();
}

Future<void> _openBudget(
  WidgetTester tester, {
  required _BudgetFinanceRepository repository,
  List<PaymentBalance> initialPaymentBalances = const [],
  required ValueChanged<BudgetEditorResult?> onResult,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(
              await showBudgetEditorDialog(
                context,
                initialPaymentBalances: initialPaymentBalances,
                financeRepository: repository,
              ),
            ),
            child: const Text('Abrir orçamento'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir orçamento'));
  await tester.pumpAndSettle();
}

class _BudgetFinanceRepository implements FinanceIntegrationRepository {
  int workspaceLoads = 0;
  int submittedPurchases = 0;

  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    workspaceLoads++;
    return FinanceWorkspace(
      householdId: 'household-id',
      householdName: 'Casa',
      cards: const [],
      paymentSources: const [
        FinancePaymentSource(
          id: 'pluxee-id',
          kind: FinancePaymentSourceKind.foodVoucher,
          name: 'Pluxee momo',
          availableCents: 81400,
          colorHex: '#176B4B',
        ),
        FinancePaymentSource(
          id: 'alelo-id',
          kind: FinancePaymentSourceKind.foodVoucher,
          name: 'VA ALELO',
          availableCents: 8000,
          colorHex: '#6D9B35',
        ),
      ],
      categories: const [],
      asOf: DateTime(2026, 10, 11),
    );
  }

  @override
  Future<bool> isConnected() async => true;
  @override
  Future<String> connectionId() async => 'budget-test-connection';
  @override
  Future<List<FinancePurchaseSync>> purchaseSyncHistory() async => [];
  @override
  Future<int> pendingPurchaseCount() async => 0;
  @override
  Future<int> retryPendingPurchases() async => 0;
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> retryPurchase(String purchaseId) async {}
  @override
  Future<void> submitPurchasePlan(List<FinancePurchaseSync> plan) async {
    submittedPurchases++;
  }

  @override
  Future<FinancePurchaseSubmission> submitPurchase(
    FinancePurchaseRequest purchase,
  ) {
    submittedPurchases++;
    throw UnimplementedError();
  }

  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) => throw UnimplementedError();
  @override
  Future<FinanceIntegrationConnection> connect(String code) =>
      throw UnimplementedError();
}
