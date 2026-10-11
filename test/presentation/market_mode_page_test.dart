import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/market_mode_page.dart';

void main() {
  testWidgets('aguarda gravação pendente antes de sair da tela', (
    tester,
  ) async {
    final gate = Completer<void>();
    ShoppingListModel? saved;
    ShoppingListModel? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<ShoppingListModel>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShoppingMarketModePage(
                      initialList: _benefitList(),
                      onSave: (list) async {
                        await gate.future;
                        saved = list;
                      },
                    ),
                  ),
                );
              },
              child: const Text('Abrir compra'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir compra'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Aumentar quantidade'),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('market_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byTooltip('Aumentar quantidade').first);
    await tester.tap(find.byTooltip('Aumentar quantidade').first);
    await tester.pump();
    await tester.tap(find.text('Concluir'));
    await tester.pump();
    expect(find.text('Modo compra'), findsOneWidget);
    expect(result, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Modo compra'), findsNothing);
    expect(saved!.items.first.quantity, 3);
    expect(result!.items.first.quantity, 3);
  });

  testWidgets('mantém alterações e oferece nova tentativa quando não salva', (
    tester,
  ) async {
    var fail = true;
    ShoppingListModel? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingMarketModePage(
          initialList: _benefitList(),
          onSave: (list) async {
            if (fail) throw StateError('storage unavailable');
            saved = list;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byTooltip('Aumentar quantidade'),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('market_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.byTooltip('Aumentar quantidade').first);
    await tester.tap(find.byTooltip('Aumentar quantidade').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar no aparelho.'), findsOneWidget);
    expect(saved, isNull);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(saved!.items.first.quantity, 3);
    expect(find.text('Salvo no aparelho'), findsOneWidget);
  });

  testWidgets('carrinho e saldo do VA acompanham itens pegos em tela pequena', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ShoppingListModel? saved;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: ShoppingMarketModePage(
          initialList: _benefitList(),
          onSave: (list) async => saved = list,
          financeRepository: _FinanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('market_toggle_rice')),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('market_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('market_toggle_rice')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('market_toggle_rice')));
    await tester.pumpAndSettle();
    expect(saved!.items.first.isPurchased, isTrue);
    expect(saved!.isClosed, isFalse);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('market_balance_va')),
      -150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('market_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('market_balance_va'))).data,
      contains('410,00'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha de saldo não impede salvar o carrinho offline', (
    tester,
  ) async {
    ShoppingListModel? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingMarketModePage(
          initialList: _benefitList(),
          onSave: (list) async => saved = list,
          financeRepository: _FinanceRepository(fail: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Alelo VA: saldo indisponível'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('market_toggle_rice')),
      150,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('market_scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('market_toggle_rice')));
    await tester.pumpAndSettle();
    expect(saved!.items.first.isPurchased, isTrue);
    expect(find.text('Salvo no aparelho'), findsOneWidget);
  });

  testWidgets(
    'edita preço sem sair do modo compra ou marcar o item como pego',
    (tester) async {
      final now = DateTime(2026, 9, 10);
      ShoppingListModel? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingMarketModePage(
            onSave: (list) async => saved = list,
            initialList: ShoppingListModel(
              id: 'weekly',
              name: 'Compra semanal',
              createdAt: now,
              updatedAt: now,
              items: const [
                ShoppingItem(
                  id: 'rice',
                  name: 'Arroz',
                  quantity: 2,
                  unitPrice: 20,
                  isPurchased: false,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Editar preço de Arroz'), findsOneWidget);
      await tester.tap(find.byTooltip('Editar preço de Arroz'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('market_price_field')),
        '2590',
      );
      await tester.tap(find.text('Atualizar preço'));
      await tester.pumpAndSettle();
      expect(find.text('Modo compra'), findsOneWidget);
      expect(find.byTooltip('Marcar como pego'), findsOneWidget);
      expect(find.textContaining('25,90'), findsWidgets);
      expect(saved!.items.single.unitPrice, 25.90);
      expect(saved!.items.single.isPurchased, isFalse);
      expect(saved!.totalValue, 51.80);
    },
  );
}

ShoppingListModel _benefitList() => ShoppingListModel(
  id: 'weekly',
  name: 'Compra semanal',
  createdAt: DateTime(2026, 9, 10),
  updatedAt: DateTime(2026, 9, 10),
  items: const [
    ShoppingItem(
      id: 'rice',
      name: 'Arroz',
      quantity: 2,
      unitPrice: 275,
      isPurchased: false,
    ),
    ShoppingItem(
      id: 'milk',
      name: 'Leite',
      quantity: 1,
      unitPrice: 10,
      isPurchased: false,
    ),
  ],
  paymentBalances: const [
    PaymentBalance(
      id: 'va',
      name: 'Alelo VA',
      type: PaymentBalanceType.foodVoucher,
      amount: 960,
      financeSourceId: 'alelo-va',
      financeSourceKind: 'foodVoucher',
    ),
  ],
);

class _FinanceRepository implements FinanceIntegrationRepository {
  _FinanceRepository({this.fail = false});
  final bool fail;
  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    if (fail) throw StateError('offline');
    return FinanceWorkspace(
      householdId: 'household',
      householdName: 'Casa',
      cards: const [],
      categories: const [],
      asOf: DateTime(2026, 9, 10),
      paymentSources: const [
        FinancePaymentSource(
          id: 'alelo-va',
          kind: FinancePaymentSourceKind.foodVoucher,
          name: 'Alelo VA',
          availableCents: 96000,
          colorHex: '#006B45',
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
