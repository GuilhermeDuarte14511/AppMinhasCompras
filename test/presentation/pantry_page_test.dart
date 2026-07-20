import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/pantry.dart';
import 'package:lista_compras_material/src/presentation/pantry_page.dart';

void main() {
  testWidgets('pantry page renders without overflow on phone and desktop', (
    tester,
  ) async {
    final store = _buildStore(
      pantry: [
        PantryItem(
          id: 'coffee',
          name: 'Café',
          category: ShoppingCategory.grocery,
          unitPrice: 18,
          status: PantryStockStatus.runningLow,
          updatedAt: DateTime(2026, 7, 20),
        ),
        PantryItem(
          id: 'detergent',
          name: 'Detergente',
          category: ShoppingCategory.cleaning,
          unitPrice: 3.49,
          status: PantryStockStatus.outOfStock,
          updatedAt: DateTime(2026, 7, 20),
        ),
      ],
    );
    await store.load();

    for (final size in [const Size(390, 844), const Size(1280, 900)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(MaterialApp(home: PantryPage(store: store)));
      await tester.pumpAndSettle();

      expect(find.text('Despensa'), findsOneWidget);
      expect(find.text('2 para repor'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);
      expect(find.text('Detergente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('out of stock item is added to the only open list', (
    tester,
  ) async {
    final list = ShoppingListModel(
      id: 'weekly',
      name: 'Compra semanal',
      createdAt: DateTime(2026, 7, 20),
      updatedAt: DateTime(2026, 7, 20),
      items: const [],
    );
    final store = _buildStore(
      lists: [list],
      pantry: [
        PantryItem(
          id: 'rice',
          name: 'Arroz',
          category: ShoppingCategory.grocery,
          unitPrice: 20,
          suggestedQuantity: 2,
          status: PantryStockStatus.outOfStock,
          updatedAt: DateTime(2026, 7, 20),
        ),
      ],
    );
    await store.load();
    await tester.pumpWidget(MaterialApp(home: PantryPage(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar à lista'));
    await tester.pumpAndSettle();

    expect(store.findById('weekly')!.items, hasLength(1));
    expect(store.findById('weekly')!.items.single.name, 'Arroz');
    expect(store.findById('weekly')!.items.single.quantity, 2);
    expect(find.textContaining('foi adicionado a Compra semanal'), findsOne);
  });
}

ShoppingListsStore _buildStore({
  List<ShoppingListModel> lists = const [],
  List<PantryItem> pantry = const [],
}) {
  return ShoppingListsStore(
    _ListStorage(lists),
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(_CatalogStorage()),
    historyStorage: _HistoryStorage(),
    pantryStorage: _PantryStorage(pantry),
    lookupService: const _LookupService(),
    homeWidgetService: const NoopShoppingHomeWidgetService(),
  );
}

class _ListStorage implements ShoppingListsStorage {
  _ListStorage(this.items);

  List<ShoppingListModel> items;

  @override
  Future<List<ShoppingListModel>> loadLists() async => items;

  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    items = lists;
  }
}

class _PantryStorage implements PantryStorage {
  _PantryStorage(this.items);

  List<PantryItem> items;

  @override
  Future<List<PantryItem>> loadItems() async => items;

  @override
  Future<void> saveItems(List<PantryItem> items) async {
    this.items = items;
  }
}

class _CatalogStorage implements ProductCatalogStorage {
  @override
  Future<List<CatalogProduct>> loadProducts() async => const [];

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {}
}

class _HistoryStorage implements PurchaseHistoryStorage {
  @override
  Future<List<CompletedPurchase>> loadHistory() async => const [];

  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {}
}

class _LookupService implements ProductLookupService {
  const _LookupService();

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async => null;
}
