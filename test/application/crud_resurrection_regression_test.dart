import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/shared_list_sync_policy.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/application/sync/snapshot_cleanup_policy.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  test('new list persists budget and multiple finance-linked cards', () async {
    final lists = _Lists([]);
    final store = _store(lists, _Catalog());
    addTearDown(store.dispose);
    await store.load();
    const balances = [
      PaymentBalance(
        id: 'a',
        name: 'VA A',
        type: PaymentBalanceType.foodVoucher,
        amount: 814,
        financeSourceId: 'remote-a',
        financeSourceKind: 'foodVoucher',
      ),
      PaymentBalance(
        id: 'b',
        name: 'Cartão B',
        type: PaymentBalanceType.card,
        amount: 100,
        financeSourceId: 'remote-b',
        financeSourceKind: 'credit',
      ),
    ];
    final created = await store.createList(
      name: 'Compra',
      budget: 914,
      paymentBalances: balances,
    );
    expect(created.budget, 914);
    expect(lists.values.single.paymentBalances.map((b) => b.financeSourceId), [
      'remote-a',
      'remote-b',
    ]);
  });
  test(
    'cloud hydration preserves history item IDs across repeated imports',
    () async {
      final store = _store(_Lists([]), _Catalog());
      addTearDown(store.dispose);
      await store.load();
      final purchase = CompletedPurchase(
        id: 'stable-history',
        listId: 'original-list',
        listName: 'Compra',
        closedAt: DateTime(2026, 10, 1),
        items: [
          _riceList().items.single.copyWith(
            priceHistory: [
              PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 10, 1)),
            ],
          ),
        ],
      );
      final backup = jsonEncode({
        'version': 5,
        'lists': [],
        'purchaseHistory': [purchase.toJson()],
        'catalog': [],
        'pantry': [],
      });
      await store.importBackupJson(backup, replaceExisting: true);
      expect(store.purchaseHistory.single.items.single.id, 'rice');
      final first = store.purchaseHistory.single.toJson();
      await store.importBackupJson(backup, replaceExisting: true);
      expect(store.purchaseHistory.single.toJson(), first);
    },
  );
  test(
    'trash then permanent deletion persists and requests remote delete',
    () async {
      final lists = _Lists([_riceList()]);
      final catalog = _Catalog();
      final store = _store(lists, catalog);
      await store.load();
      await store.deleteList('old-open-list');
      expect(store.lists, isEmpty);
      expect(store.trashedLists.single.id, 'old-open-list');
      await store.deleteListForever('old-open-list');
      expect(store.allLists, isEmpty);
      expect(lists.values, isEmpty);
      expect(
        planSnapshotDeletes(
          localIds: store.allLists.map((list) => list.id).toSet(),
          remoteIds: {'old-open-list'},
        ),
        {'old-open-list'},
      );
      store.dispose();

      final restarted = _store(lists, catalog);
      addTearDown(restarted.dispose);
      await restarted.load();
      expect(restarted.allLists, isEmpty);
    },
  );

  test('owned shared mirror cannot overwrite a newer local edit', () {
    expect(
      resolveOwnedSharedListMirrorAction(
        hasSourceLocalListId: true,
        hasLocalCopy: true,
        localUpdatedAt: DateTime(2026, 10, 11),
        sharedUpdatedAt: DateTime(2026, 10, 10),
      ),
      SharedListMirrorAction.skip,
    );
  });

  test('deleted catalog product stays deleted after local restart', () async {
    final lists = _Lists([_riceList()]);
    final catalog = _Catalog();
    final original = _store(lists, catalog);
    await original.load();
    // Explicit catalog deletion must not delete the item from its old list.
    await original.replaceCatalogProducts([]);
    expect(original.catalogProducts, isEmpty);
    expect(original.allLists.single.items.single.name, 'Arroz Camil');
    original.dispose();

    final restarted = _store(lists, catalog);
    addTearDown(restarted.dispose);
    await restarted.load();
    expect(restarted.loadError, isNull);
    expect(restarted.catalogProducts, isEmpty);
    expect(restarted.allLists.single.items.single.name, 'Arroz Camil');
  });

  test(
    'empty catalog in remote snapshot does not resurrect list products',
    () async {
      final store = _store(_Lists([]), _Catalog());
      addTearDown(store.dispose);
      await store.load();
      await store.importBackupJson(
        jsonEncode({
          'version': 4,
          'lists': [_riceList().toJson()],
          'purchaseHistory': [],
          'catalog': [],
          'pantry': [],
        }),
        replaceExisting: true,
      );
      expect(store.allLists.single.items.single.name, 'Arroz Camil');
      expect(store.catalogProducts, isEmpty);
    },
  );
}

ShoppingListModel _riceList() => ShoppingListModel(
  id: 'old-open-list',
  name: 'Mercado antigo',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
  items: const [
    ShoppingItem(id: 'rice', name: 'Arroz Camil', quantity: 2, unitPrice: 10),
  ],
);

ShoppingListsStore _store(_Lists lists, _Catalog catalog) => ShoppingListsStore(
  lists,
  reminderService: const NoopShoppingReminderService(),
  productCatalog: ProductCatalogRepository(catalog),
  historyStorage: _History(),
  lookupService: _Lookup(),
  homeWidgetService: const NoopShoppingHomeWidgetService(),
);

class _Lists implements ShoppingListsStorage {
  _Lists(this.values);
  List<ShoppingListModel> values;
  @override
  Future<List<ShoppingListModel>> loadLists() async =>
      values.map((list) => list.deepCopy()).toList();
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    values = lists.map((list) => list.deepCopy()).toList();
  }
}

class _Catalog implements ProductCatalogStorage {
  List<CatalogProduct> values = [];
  @override
  Future<List<CatalogProduct>> loadProducts() async => List.of(values);
  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    values = List.of(products);
  }
}

class _History implements PurchaseHistoryStorage {
  @override
  Future<List<CompletedPurchase>> loadHistory() async => [];
  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {}
}

class _Lookup implements ProductLookupService {
  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async => null;
}
