import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/finance_integration_page.dart';

void main() {
  testWidgets('connects with a code and displays cards and available limit', (
    tester,
  ) async {
    final repository = _FakeFinanceIntegrationRepository();
    await tester.pumpWidget(
      MaterialApp(home: FinanceIntegrationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conectar ao Minhas Finanças'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ABCD-EFGH-IJKL');
    await tester.tap(find.widgetWithText(FilledButton, 'Conectar'));
    await tester.pumpAndSettle();

    expect(repository.receivedCode, 'ABCD-EFGH-IJKL');
    expect(find.textContaining('Nubank'), findsOneWidget);
    expect(find.textContaining('3.749,50'), findsOneWidget);
    expect(find.text('VR'), findsOneWidget);
    expect(find.textContaining('850,00'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets('shows pending purchases and retries them', (tester) async {
    final repository = _FakeFinanceIntegrationRepository(
      connected: true,
      pendingCount: 2,
    );
    await tester.pumpWidget(
      MaterialApp(home: FinanceIntegrationPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 lançamentos pendentes'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();

    expect(repository.didRetry, isTrue);
    expect(find.textContaining('sincronizados'), findsOneWidget);
  });
}

class _FakeFinanceIntegrationRepository
    implements FinanceIntegrationRepository {
  _FakeFinanceIntegrationRepository({
    this.connected = false,
    this.pendingCount = 0,
  });

  bool connected;
  int pendingCount;
  String? receivedCode;
  bool didRetry = false;

  static final workspace = FinanceWorkspace(
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
    paymentSources: const [
      FinancePaymentSource(
        id: 'card-id',
        kind: FinancePaymentSourceKind.credit,
        name: 'Nubank',
        lastDigits: '1234',
        availableCents: 374950,
        colorHex: '#7B2CBF',
        limitCents: 500000,
        usedCents: 125050,
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
    asOf: DateTime(2026, 9, 1),
  );

  @override
  Future<FinanceIntegrationConnection> connect(String code) async {
    receivedCode = code;
    connected = true;
    return const FinanceIntegrationConnection(
      id: 'integration-id',
      householdId: 'household-id',
      householdName: 'Casa',
      ownerName: 'Gui',
      permissions: ['cards:read', 'purchases:write'],
    );
  }

  @override
  Future<String> connectionId() async => 'test-connection';
  @override
  Future<void> submitPurchasePlan(List<FinancePurchaseSync> plan) async {}
  @override
  Future<List<FinancePurchaseSync>> purchaseSyncHistory() async => [];
  @override
  Future<void> retryPurchase(String purchaseId) async {}
  @override
  Future<void> disconnect() async => connected = false;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<FinanceWorkspace> loadWorkspace() async => workspace;

  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) async => FinancePaymentSource(
    id: 'created-source-id',
    kind: request.kind,
    name: request.name,
    availableCents: request.availableCents,
    colorHex: request.colorHex,
    lastDigits: request.lastDigits,
    closingDay: request.closingDay,
    dueDay: request.dueDay,
  );

  @override
  Future<int> pendingPurchaseCount() async => pendingCount;

  @override
  Future<int> retryPendingPurchases() async {
    didRetry = true;
    final synced = pendingCount;
    pendingCount = 0;
    return synced;
  }

  @override
  Future<FinancePurchaseSubmission> submitPurchase(
    FinancePurchaseRequest purchase,
  ) async => const FinancePurchaseSubmission(queued: false, created: true);
}
