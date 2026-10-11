import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  testWidgets(
    'item history opens from actual editor without changing storage',
    (tester) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      final before = storage.list.toJson();
      final saves = storage.saves;
      final row = find.byKey(const ValueKey('list_item_rice'));
      await tester.ensureVisible(row);
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip('Mais ações')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico de preço'));
      await tester.pumpAndSettle();
      expect(find.text('Histórico de preços'), findsOneWidget);
      expect(find.text('Inicial'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Histórico de preços'), findsNothing);
      expect(storage.list.toJson(), before);
      expect(storage.saves, saves);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('swipe duplication persists item metadata with a new identity', (
    tester,
  ) async {
    final storage = _MemoryStorage();
    await _open(tester, storage);
    await _actions(tester);
    await tester.tap(find.text('Duplicar item'));
    await tester.pumpAndSettle();
    expect(storage.list.items, hasLength(2));
    final original = storage.list.items.first;
    final duplicate = storage.list.items.last;
    expect(duplicate.id, isNot(original.id));
    expect(duplicate.name, contains(original.name));
    expect(duplicate.quantity, original.quantity);
    expect(duplicate.unitPrice, original.unitPrice);
    expect(duplicate.barcode, original.barcode);
    expect(duplicate.category, original.category);
    expect(duplicate.priceHistory, original.priceHistory);
    expect(duplicate.isPurchased, isFalse);
    expect(original.isPurchased, isTrue);
    expect(storage.saves, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe deletion cancels safely then removes only selected item', (
    tester,
  ) async {
    final storage = _MemoryStorage(secondItem: true);
    await _open(tester, storage);
    await _actions(tester);
    await tester.tap(find.text('Excluir item'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deseja remover ‘Arroz integral 1kg’ da lista?'),
      findsOneWidget,
    );
    final saves = storage.saves;
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(storage.list.items, hasLength(2));
    expect(storage.saves, saves);
    await _actions(tester);
    await tester.tap(find.text('Excluir item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(storage.list.items.single.id, 'coffee');
    expect(storage.saves, greaterThan(saves));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'swipe edit opens existing item form without immediate mutation',
    (tester) async {
      final storage = _MemoryStorage();
      await _open(tester, storage);
      await _actions(tester);
      final saves = storage.saves;
      await tester.tap(find.text('Editar item'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar item'), findsOneWidget);
      expect(find.text('Arroz integral 1kg'), findsWidgets);
      expect(storage.saves, saves);
      expect(storage.list.items.single.id, 'rice');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(WidgetTester tester, _MemoryStorage storage) async {
  tester.view.physicalSize = const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ShoppingListApp(storage: storage));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('dash_action_lists')));
  await tester.tap(find.byKey(const ValueKey('dash_action_lists')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compras da semana'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Todos (${storage.list.items.length})'));
  await tester.pumpAndSettle();
}

Future<void> _actions(WidgetTester tester) async {
  final row = find.byKey(const ValueKey('list_item_rice'));
  await tester.ensureVisible(row);
  await tester.drag(row, const Offset(-350, 0));
  await tester.pumpAndSettle();
  expect(find.text('Duplicar item'), findsOneWidget);
}

class _MemoryStorage implements ShoppingListsStorage {
  _MemoryStorage({bool secondItem = false}) {
    list = ShoppingListModel(
      id: 'weekly',
      name: 'Compras da semana',
      createdAt: DateTime(2026, 10, 9),
      updatedAt: DateTime(2026, 10, 9),
      items: [
        ShoppingItem(
          id: 'rice',
          name: 'Arroz integral 1kg',
          quantity: 2,
          unitPrice: 11.90,
          isPurchased: true,
          barcode: '7891234567895',
          priceHistory: [
            PriceHistoryEntry(price: 11.90, recordedAt: DateTime(2026, 10, 8)),
          ],
        ),
        if (secondItem)
          const ShoppingItem(
            id: 'coffee',
            name: 'Café',
            quantity: 1,
            unitPrice: 20,
          ),
      ],
    );
  }
  late ShoppingListModel list;
  int saves = 0;
  @override
  Future<List<ShoppingListModel>> loadLists() async => [list];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    saves++;
    list = lists.first;
  }
}
