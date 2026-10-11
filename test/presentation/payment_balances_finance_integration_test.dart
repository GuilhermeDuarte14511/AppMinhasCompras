import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';

void main() {
  testWidgets(
    'criação com resposta perdida reutiliza ID e salva reserva em centavos',
    (tester) async {
      final repository = _PaymentSourcesRepository(failFirstCreate: true);
      PaymentBalancesEditorResult? result;
      await _openBalances(tester, repository, (value) => result = value);
      await _showCreateAction(tester);
      await tester.tap(find.text('Criar no Finanças'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('payment_source_name_field')),
        '  Crédito real  ',
      );
      await tester.enterText(
        find.byKey(const Key('payment_source_digits_field')),
        '9012',
      );
      await tester.enterText(
        find.byKey(const Key('payment_source_amount_field')),
        '12345',
      );
      await tester.tap(find.text('Criar e usar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Resposta indisponível. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.text('Novo meio de pagamento'), findsOneWidget);
      await tester.tap(find.text('Criar e usar'));
      await tester.pumpAndSettle();
      expect(repository.requests, hasLength(2));
      expect(
        repository.requests.last.externalRequestId,
        repository.requests.first.externalRequestId,
      );
      final request = repository.requests.last;
      expect(request.name, 'Crédito real');
      expect(request.lastDigits, '9012');
      expect(request.availableCents, 12345);
      expect(request.closingDay, 5);
      expect(request.dueDay, 10);
      await _showReservedAmount(tester);
      await tester.enterText(
        find.byKey(const Key('finance_source_amount_field')),
        '10001',
      );
      await tester.tap(find.text('Usar nesta lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      final balance = result!.value!.single;
      expect(balance.amount, 100.01);
      expect(balance.type, PaymentBalanceType.card);
      expect(balance.financeSourceId, 'created-id');
      expect(
        balance.financeSourceKind,
        FinancePaymentSourceKind.credit.wireValue,
      );
      expect(
        PaymentBalance.fromJson(balance.toJson()).toJson(),
        balance.toJson(),
      );
      expect(repository.submittedPlans, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelar criação retorna à seleção sem criar fonte nem perder reserva',
    (tester) async {
      final repository = _PaymentSourcesRepository();
      PaymentBalancesEditorResult? result;
      await _openBalances(tester, repository, (value) => result = value);
      await tester.tap(find.text('VR Alelo'));
      await tester.pumpAndSettle();
      await _showReservedAmount(tester);
      await tester.enterText(
        find.byKey(const Key('finance_source_amount_field')),
        '1234',
      );
      await _showCreateAction(tester);
      await tester.tap(find.text('Criar no Finanças'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('payment_source_name_field')),
        'Não criar',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      await tester.tap(find.text('Usar nesta lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(result!.value!.single.amount, 12.34);
      expect(result!.value!.single.financeSourceId, 'vr-id');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelar saldo manual não adiciona fonte sincronizada selecionada',
    (tester) async {
      final repository = _PaymentSourcesRepository();
      PaymentBalancesEditorResult? result;
      await _openBalances(tester, repository, (value) => result = value);
      await tester.tap(find.text('VR Alelo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar manualmente'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(result!.value, isEmpty);
      expect(repository.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelar a seleção sincronizada preserva os saldos existentes', (
    tester,
  ) async {
    const initial = PaymentBalance(
      id: 'cash',
      name: 'Dinheiro',
      type: PaymentBalanceType.cash,
      amount: 75,
    );
    PaymentBalancesEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showPaymentBalancesEditorDialog(
                  context,
                  initialValues: const [initial],
                  financeRepository: _PaymentSourcesRepository(),
                );
              },
              child: const Text('Abrir saldos'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir saldos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VR Alelo'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Saldos de pagamento'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(result!.value!.single.toJson(), initial.toJson());
    expect(tester.takeException(), isNull);
  });

  testWidgets('adiciona à lista um saldo existente no Minhas Finanças', (
    tester,
  ) async {
    final repository = _PaymentSourcesRepository();
    PaymentBalancesEditorResult? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await showPaymentBalancesEditorDialog(
                  context,
                  financeRepository: repository,
                );
              },
              child: const Text('Abrir saldos'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir saldos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();

    expect(find.text('Meios do Minhas Finanças'), findsOneWidget);
    expect(find.text('VR Alelo'), findsOneWidget);
    await _showCreateAction(tester);
    expect(find.text('Criar no Finanças'), findsOneWidget);

    await tester.tap(find.text('VR Alelo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar nesta lista'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    final balance = result!.value!.single;
    expect(balance.name, 'VR Alelo');
    expect(balance.type, PaymentBalanceType.mealVoucher);
    expect(balance.amount, 850);
    expect(balance.financeSourceId, 'vr-id');
    expect(balance.financeSourceKind, 'mealVoucher');
    final restored = PaymentBalance.fromJson(balance.toJson());
    expect(restored.financeSourceId, 'vr-id');
    expect(restored.type, PaymentBalanceType.mealVoucher);
  });

  testWidgets('cria VR no Finanças e já o usa como saldo da lista', (
    tester,
  ) async {
    final repository = _PaymentSourcesRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPaymentBalancesEditorDialog(
                context,
                financeRepository: repository,
              ),
              child: const Text('Abrir saldos'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir saldos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await _showCreateAction(tester);
    await tester.tap(find.text('Criar no Finanças'));
    await tester.pumpAndSettle();

    expect(find.text('Crédito'), findsWidgets);
    expect(find.text('Débito'), findsWidgets);
    expect(find.text('VA'), findsWidgets);
    expect(find.text('VR'), findsWidgets);

    await tester.tap(find.text('VR').last);
    await tester.enterText(
      find.byKey(const Key('payment_source_name_field')),
      'VR Flash',
    );
    await tester.enterText(
      find.byKey(const Key('payment_source_digits_field')),
      '5566',
    );
    await tester.enterText(
      find.byKey(const Key('payment_source_amount_field')),
      '60000',
    );
    await tester.tap(find.text('Criar e usar'));
    await tester.pumpAndSettle();

    expect(
      repository.createdRequest?.kind,
      FinancePaymentSourceKind.mealVoucher,
    );
    expect(repository.createdRequest?.name, 'VR Flash');
    expect(repository.createdRequest?.availableCents, 60000);
    expect(find.text('VR Flash'), findsOneWidget);
  });

  testWidgets('seletor permanece utilizável em 320 px com fonte ampliada', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPaymentBalancesEditorDialog(
                context,
                financeRepository: _PaymentSourcesRepository(),
              ),
              child: const Text('Abrir saldos'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir saldos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();

    expect(find.text('Adicionar manualmente'), findsOneWidget);
    expect(find.text('Usar nesta lista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _showCreateAction(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Criar no Finanças'),
    100,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('finance_sources_scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _showReservedAmount(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('finance_source_amount_field')),
    100,
    scrollable: find
        .descendant(
          of: find.byKey(const ValueKey('finance_sources_scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openBalances(
  WidgetTester tester,
  _PaymentSourcesRepository repository,
  ValueChanged<PaymentBalancesEditorResult?> onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async => onResult(
              await showPaymentBalancesEditorDialog(
                context,
                financeRepository: repository,
              ),
            ),
            child: const Text('Abrir saldos'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir saldos'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Novo saldo'));
  await tester.pumpAndSettle();
}

class _PaymentSourcesRepository implements FinanceIntegrationRepository {
  _PaymentSourcesRepository({this.failFirstCreate = false});
  final bool failFirstCreate;
  final List<FinancePaymentSourceRequest> requests = [];
  int submittedPlans = 0;
  FinancePaymentSourceRequest? createdRequest;

  static final workspace = FinanceWorkspace(
    householdId: 'household-id',
    householdName: 'Casa',
    cards: const [],
    paymentSources: const [
      FinancePaymentSource(
        id: 'credit-id',
        kind: FinancePaymentSourceKind.credit,
        name: 'Nubank',
        lastDigits: '1234',
        availableCents: 374950,
        colorHex: '#7B2CBF',
        closingDay: 20,
        dueDay: 27,
      ),
      FinancePaymentSource(
        id: 'vr-id',
        kind: FinancePaymentSourceKind.mealVoucher,
        name: 'VR Alelo',
        lastDigits: '7788',
        availableCents: 85000,
        colorHex: '#0D7B9A',
      ),
    ],
    categories: const [],
    asOf: DateTime(2026, 9, 3),
  );

  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) async {
    createdRequest = request;
    requests.add(request);
    if (failFirstCreate && requests.length == 1) {
      throw const FinanceIntegrationException(
        'Resposta indisponível. Tente novamente.',
        retryable: true,
      );
    }
    return FinancePaymentSource(
      id: 'created-id',
      kind: request.kind,
      name: request.name,
      lastDigits: request.lastDigits,
      availableCents: request.availableCents,
      colorHex: request.colorHex,
      closingDay: request.closingDay,
      dueDay: request.dueDay,
    );
  }

  @override
  Future<bool> isConnected() async => true;

  @override
  Future<FinanceWorkspace> loadWorkspace() async => workspace;

  @override
  Future<String> connectionId() async => 'test-connection';
  @override
  Future<void> submitPurchasePlan(List<FinancePurchaseSync> plan) async {
    submittedPlans++;
  }

  @override
  Future<List<FinancePurchaseSync>> purchaseSyncHistory() async => [];
  @override
  Future<void> retryPurchase(String purchaseId) async {}
  @override
  Future<void> disconnect() async {}

  @override
  Future<FinanceIntegrationConnection> connect(String code) =>
      throw UnimplementedError();

  @override
  Future<int> pendingPurchaseCount() async => 0;

  @override
  Future<int> retryPendingPurchases() async => 0;

  @override
  Future<FinancePurchaseSubmission> submitPurchase(
    FinancePurchaseRequest purchase,
  ) => throw UnimplementedError();
}
