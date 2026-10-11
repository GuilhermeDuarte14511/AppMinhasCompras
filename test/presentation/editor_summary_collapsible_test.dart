import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/editor_editorial_summary.dart';

void main() {
  testWidgets(
    'EditorEditorialSummary colapsavel exibe apenas Total da compra e Total disponivel quando fechado e expande ao tocar',
    (tester) async {
      final list = ShoppingListModel(
        id: 'list-1',
        name: 'Compras Outubro',
        createdAt: DateTime(2026, 10, 11),
        updatedAt: DateTime(2026, 10, 11),
        budget: 814.0,
        items: [
          const ShoppingItem(
            id: 'item-1',
            name: 'Empanado de frango',
            unitPrice: 9.60,
            quantity: 3,
            isPurchased: false,
          ),
        ],
      );

      bool marketTapped = false;
      bool checkoutTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditorEditorialSummary(
                list: list,
                onBudget: () {},
                onReminder: () {},
                onBalances: () {},
                onMarket: () => marketTapped = true,
                onCheckout: () => checkoutTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('editor_summary_toggle'));
      expect(toggleFinder, findsOneWidget);

      // 1. No estado colapsado:
      // O botão colapsável exibe Total da compra e Total disponível
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total da compra:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text(formatCurrency(28.80)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total disponível:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text(formatCurrency(785.20)),
        ),
        findsOneWidget,
      );

      // 2. Ao tocar no botão colapsável para expandir:
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Agora a seção expandida está visível:
      expect(find.text('Modo compra'), findsOneWidget);
      expect(find.text('Fechar compra'), findsOneWidget);
      expect(find.text('TOTAL CALCULADO'), findsOneWidget);
      expect(find.text('TETO ORÇADO'), findsOneWidget);

      // Tocar no Modo compra funciona normalmente
      await tester.tap(find.text('Modo compra'));
      expect(marketTapped, isTrue);

      // Tocar no Fechar compra funciona normalmente
      await tester.tap(find.text('Fechar compra'));
      expect(checkoutTapped, isTrue);

      // 3. Ao tocar no botão colapsável novamente para recolher:
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Volta a recolher
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total da compra:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total disponível:'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EditorEditorialSummary exibe excesso em vermelho quando o orcamento foi estourado',
    (tester) async {
      final list = ShoppingListModel(
        id: 'list-2',
        name: 'Compras Estouradas',
        createdAt: DateTime(2026, 10, 11),
        updatedAt: DateTime(2026, 10, 11),
        budget: 20.0,
        items: [
          const ShoppingItem(
            id: 'item-1',
            name: 'Item Caro',
            unitPrice: 50.0,
            quantity: 1,
            isPurchased: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorEditorialSummary(
              list: list,
              onBudget: () {},
              onReminder: () {},
              onBalances: () {},
              onMarket: () {},
              onCheckout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('editor_summary_toggle'));
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total da compra:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text(formatCurrency(50.0)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total disponível:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Excesso ${formatCurrency(30.0)}'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'EditorEditorialSummary exibe "Sem orçamento" quando a lista nao tem teto',
    (tester) async {
      final list = ShoppingListModel(
        id: 'list-3',
        name: 'Sem Teto',
        createdAt: DateTime(2026, 10, 11),
        updatedAt: DateTime(2026, 10, 11),
        budget: null,
        items: [
          const ShoppingItem(
            id: 'item-1',
            name: 'Item',
            unitPrice: 15.0,
            quantity: 1,
            isPurchased: false,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditorEditorialSummary(
              list: list,
              onBudget: () {},
              onReminder: () {},
              onBalances: () {},
              onMarket: () {},
              onCheckout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('editor_summary_toggle'));
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total da compra:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text(formatCurrency(15.0)),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: toggleFinder,
          matching: find.text('Total disponível:'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: toggleFinder, matching: find.text('Sem orçamento')),
        findsOneWidget,
      );
    },
  );
}
