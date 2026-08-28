import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/editor_item_card.dart';

void main() {
  testWidgets('product card is compact and reveals secondary details on tap', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var expanded = false;
    var toggleCount = 0;
    var incrementCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    EditorShoppingItemCard(
                      item: _item(),
                      expanded: expanded,
                      onToggleExpanded: () {
                        toggleCount++;
                        setState(() => expanded = !expanded);
                      },
                      onPurchasedChanged: (_) {},
                      onIncrement: () => incrementCount++,
                      onDecrement: () {},
                      onEdit: () {},
                      onViewHistory: () {},
                      onDelete: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Arroz integral tipo 1 pacote econômico'), findsOneWidget);
    expect(find.textContaining('Mercearia • 2 ×'), findsOneWidget);
    expect(find.textContaining('23,80'), findsOneWidget);
    expect(find.text('7891234567895'), findsNothing);
    expect(find.byTooltip('Diminuir quantidade'), findsNothing);
    expect(tester.takeException(), isNull);
    final compactHeight = tester
        .getSize(find.byType(EditorShoppingItemCard))
        .height;
    expect(compactHeight, lessThan(130));

    await tester.tap(find.text('Arroz integral tipo 1 pacote econômico'));
    await tester.pumpAndSettle();

    expect(toggleCount, 1);
    expect(find.text('7891234567895'), findsOneWidget);
    expect(find.byTooltip('Diminuir quantidade'), findsOneWidget);
    expect(find.byTooltip('Aumentar quantidade'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    final expandedHeight = tester
        .getSize(find.byType(EditorShoppingItemCard))
        .height;
    expect(expandedHeight, greaterThan(compactHeight));

    await tester.tap(find.byTooltip('Aumentar quantidade'));
    await tester.pump();
    expect(incrementCount, 1);
    expect(toggleCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('secondary actions live in the overflow menu', (tester) async {
    var editCount = 0;
    var historyCount = 0;
    var deleteCount = 0;
    var toggleCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorShoppingItemCard(
            item: _item(),
            expanded: false,
            onToggleExpanded: () => toggleCount++,
            onPurchasedChanged: (_) {},
            onIncrement: () {},
            onDecrement: () {},
            onEdit: () => editCount++,
            onViewHistory: () => historyCount++,
            onDelete: () => deleteCount++,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.edit_rounded), findsNothing);
    expect(find.byIcon(Icons.query_stats_rounded), findsNothing);

    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    expect(find.text('Editar item'), findsOneWidget);
    expect(find.text('Histórico de preço'), findsOneWidget);
    expect(find.text('Excluir item'), findsOneWidget);

    await tester.tap(find.text('Editar item'));
    await tester.pumpAndSettle();
    expect(editCount, 1);
    expect(historyCount, 0);
    expect(deleteCount, 0);
    expect(toggleCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('purchased state is conveyed without repeated visual labels', (
    tester,
  ) async {
    var toggleCount = 0;
    bool? changedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EditorShoppingItemCard(
            item: _item(isPurchased: true),
            expanded: false,
            onToggleExpanded: () => toggleCount++,
            onPurchasedChanged: (value) => changedTo = value,
            onIncrement: () {},
            onDecrement: () {},
            onEdit: () {},
            onViewHistory: () {},
            onDelete: () {},
          ),
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
    expect(find.text('Comprado'), findsNothing);
    expect(find.textContaining('Comprado •'), findsNothing);
    expect(
      find.bySemanticsLabel(
        'Marcar Arroz integral tipo 1 pacote econômico como pendente',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(changedTo, isFalse);
    expect(toggleCount, 0);
  });

  testWidgets(
    'compact card remains usable with large text on a narrow screen',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EditorShoppingItemCard(
                  item: _item(unitPrice: 123456.78),
                  expanded: false,
                  onToggleExpanded: () {},
                  onPurchasedChanged: (_) {},
                  onIncrement: () {},
                  onDecrement: () {},
                  onEdit: () {},
                  onViewHistory: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('246.913,56'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

ShoppingItem _item({bool isPurchased = false, double unitPrice = 11.9}) {
  return ShoppingItem(
    id: 'item-1',
    name: 'Arroz integral tipo 1 pacote econômico',
    quantity: 2,
    unitPrice: unitPrice,
    barcode: '7891234567895',
    isPurchased: isPurchased,
    category: ShoppingCategory.grocery,
  );
}
