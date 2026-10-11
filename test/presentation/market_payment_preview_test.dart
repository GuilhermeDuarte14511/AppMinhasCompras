import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/market_payment_preview.dart';

void main() {
  testWidgets(
    'usa saldo do Finanças e respeita o valor reservado em cada meio',
    (tester) async {
      final repository = _Repository();
      await _pump(
        tester,
        repository,
        balances: const [
          PaymentBalance(
            id: 'va',
            name: 'Alelo VA',
            type: PaymentBalanceType.foodVoucher,
            amount: 300,
            financeSourceId: 'va-id',
            financeSourceKind: 'foodVoucher',
          ),
          PaymentBalance(
            id: 'cash',
            name: 'Dinheiro',
            type: PaymentBalanceType.other,
            amount: 400,
          ),
        ],
      );
      expect(_balance(tester, 'va'), contains('660,00'));
      expect(_balance(tester, 'cash'), contains('150,00'));
      expect(_balance(tester, 'cash'), contains('saldo informado'));
      expect(repository.loads, 1);
      repository.availableCents = 80000;
      await tester.tap(find.text('Atualizar saldo'));
      await tester.pumpAndSettle();
      expect(_balance(tester, 'va'), contains('500,00'));
    },
  );

  testWidgets('mostra saldo insuficiente sem inventar cobertura', (
    tester,
  ) async {
    final repository = _Repository()..availableCents = 20000;
    await _pump(tester, repository);
    expect(_balance(tester, 'va'), contains('faltam'));
    expect(_balance(tester, 'va'), contains('350,00'));
  });

  testWidgets('não usa o saldo antigo como atual após falha de atualização', (
    tester,
  ) async {
    final repository = _Repository();
    await _pump(tester, repository);
    expect(_balance(tester, 'va'), contains('410,00'));
    repository.fail = true;
    await tester.tap(find.text('Atualizar saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Alelo VA: saldo indisponível'), findsOneWidget);
    expect(find.textContaining('410,00'), findsNothing);
  });
}

String? _balance(WidgetTester tester, String id) =>
    tester.widget<Text>(find.byKey(ValueKey('market_balance_$id'))).data;

Future<void> _pump(
  WidgetTester tester,
  _Repository repository, {
  List<PaymentBalance>? balances,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: MarketPaymentPreview(
          repository: repository,
          onEditBalances: () {},
          list: ShoppingListModel(
            id: 'weekly',
            name: 'Compra',
            createdAt: DateTime(2026, 9, 10),
            updatedAt: DateTime(2026, 9, 10),
            items: const [
              ShoppingItem(
                id: 'rice',
                name: 'Arroz',
                quantity: 2,
                unitPrice: 275,
                isPurchased: true,
              ),
              ShoppingItem(
                id: 'milk',
                name: 'Leite',
                quantity: 1,
                unitPrice: 50,
                isPurchased: false,
              ),
            ],
            paymentBalances:
                balances ??
                const [
                  PaymentBalance(
                    id: 'va',
                    name: 'Alelo VA',
                    type: PaymentBalanceType.foodVoucher,
                    amount: 960,
                    financeSourceId: 'va-id',
                    financeSourceKind: 'foodVoucher',
                  ),
                ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Repository implements FinanceIntegrationRepository {
  int availableCents = 96000;
  bool fail = false;
  int loads = 0;
  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    loads++;
    if (fail) throw StateError('offline');
    return FinanceWorkspace(
      householdId: 'home',
      householdName: 'Casa',
      cards: const [],
      categories: const [],
      asOf: DateTime(2026, 9, 10),
      paymentSources: [
        FinancePaymentSource(
          id: 'va-id',
          kind: FinancePaymentSourceKind.foodVoucher,
          name: 'Alelo VA',
          availableCents: availableCents,
          colorHex: '#006B45',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
