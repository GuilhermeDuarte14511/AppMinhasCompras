import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  test(
    'shared catalog import preference can be enabled per list or globally',
    () async {
      final preferences = _MemorySharedCatalogImportPreferences();
      final store = _createStore(sharedCatalogImportPreferences: preferences);

      await store.load();

      expect(store.isSharedCatalogImportEnabled('shared-a'), isFalse);
      expect(store.autoImportOwnedSharedCatalogs, isTrue);

      await store.setSharedCatalogImportEnabled('shared-a', enabled: true);

      expect(store.isSharedCatalogImportEnabled('shared-a'), isTrue);
      expect(store.isSharedCatalogImportEnabled('shared-b'), isFalse);

      final reloadedStore = _createStore(
        sharedCatalogImportPreferences: preferences,
      );
      await reloadedStore.load();

      expect(reloadedStore.isSharedCatalogImportEnabled('shared-a'), isTrue);
      expect(reloadedStore.autoImportOwnedSharedCatalogs, isTrue);

      await reloadedStore.setAutoImportOwnedSharedCatalogs(false);

      final ownerPreferenceReloadedStore = _createStore(
        sharedCatalogImportPreferences: preferences,
      );
      await ownerPreferenceReloadedStore.load();

      expect(
        ownerPreferenceReloadedStore.autoImportOwnedSharedCatalogs,
        isFalse,
      );

      await reloadedStore.setSharedCatalogImportEnabled(
        'shared-b',
        enabled: true,
        enableForFutureLists: true,
      );

      expect(reloadedStore.isSharedCatalogImportEnabled('shared-c'), isTrue);
    },
  );

  test(
    'cloud shared catalog import settings update local preference cache',
    () async {
      final preferences = _MemorySharedCatalogImportPreferences();
      final store = _createStore(sharedCatalogImportPreferences: preferences);

      await store.load();
      await store.applySharedCatalogImportSettings(
        autoImportOwnedSharedCatalogs: false,
        autoImportAllSharedCatalogs: false,
        enabledSharedListIds: {'shared-cloud'},
      );

      expect(store.autoImportOwnedSharedCatalogs, isFalse);
      expect(store.isSharedCatalogImportEnabled('shared-cloud'), isTrue);
      expect(store.isSharedCatalogImportEnabled('shared-other'), isFalse);

      final reloadedStore = _createStore(
        sharedCatalogImportPreferences: preferences,
      );
      await reloadedStore.load();

      expect(reloadedStore.autoImportOwnedSharedCatalogs, isFalse);
      expect(
        reloadedStore.isSharedCatalogImportEnabled('shared-cloud'),
        isTrue,
      );
      expect(
        reloadedStore.isSharedCatalogImportEnabled('shared-other'),
        isFalse,
      );
    },
  );

  test(
    'importSharedListItemsToCatalog merges by barcode and normalized name',
    () async {
      final store = _createStore(
        catalogProducts: [
          _catalogProduct(
            name: 'Leite',
            barcode: '789100000001',
            unitPrice: 6,
            usageCount: 4,
          ),
          _catalogProduct(
            name: 'Arroz',
            barcode: '789100000002',
            unitPrice: 20,
            usageCount: 2,
          ),
        ],
      );
      await store.load();

      final report = await store.importSharedListItemsToCatalog(
        _shoppingList(
          name: 'Lista compartilhada',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 20),
          items: [
            _item(
              name: 'Leite integral',
              quantity: 1,
              unitPrice: 8,
              barcode: '789100000001',
            ),
            _item(name: 'arroz', quantity: 1, unitPrice: 22),
            _item(name: 'Feijão', quantity: 1, unitPrice: 9),
          ],
        ),
      );

      expect(report.createdCount, 1);
      expect(report.mergedCount, 2);
      expect(store.catalogProducts, hasLength(3));
      expect(
        store.catalogProducts.where((product) => product.name == 'Feijão'),
        hasLength(1),
      );
      expect(
        store.catalogProducts.where(
          (product) => product.barcode == '789100000001',
        ),
        hasLength(1),
      );
      expect(
        store.catalogProducts.where(
          (product) => product.name.toLowerCase() == 'arroz',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'upsertList can skip catalog ingestion for owned shared mirrors',
    () async {
      final store = _createStore();
      await store.load();

      await store.upsertList(
        _shoppingList(
          name: 'Lista compartilhada espelhada',
          createdAt: DateTime(2026, 6, 1),
          updatedAt: DateTime(2026, 6, 20),
          items: [
            _item(
              name: 'Produto da Carol',
              quantity: 1,
              unitPrice: 12,
              barcode: '789100000099',
            ),
          ],
        ),
        ingestCatalog: false,
      );

      expect(store.catalogProducts, isEmpty);

      await store.upsertList(
        _shoppingList(
          name: 'Lista local',
          createdAt: DateTime(2026, 6, 2),
          updatedAt: DateTime(2026, 6, 21),
          items: [
            _item(
              name: 'Produto local',
              quantity: 1,
              unitPrice: 10,
              barcode: '789100000100',
            ),
          ],
        ),
      );

      expect(store.catalogProducts.map((product) => product.name), [
        'Produto local',
      ]);
    },
  );

  test(
    'listsByCreatedAt keeps newer created lists first when old lists are updated',
    () async {
      final olderCreatedSyncedList = _shoppingList(
        name: 'Lista antiga sincronizada',
        createdAt: DateTime(2026, 1, 10),
        updatedAt: DateTime(2026, 6, 10),
      );
      final newerCreatedList = _shoppingList(
        name: 'Lista criada depois',
        createdAt: DateTime(2026, 5, 10),
        updatedAt: DateTime(2026, 5, 10),
      );
      final store = _createStore(
        lists: [olderCreatedSyncedList, newerCreatedList],
      );

      await store.load();

      expect(store.listsByCreatedAt.map((list) => list.name), [
        'Lista criada depois',
        'Lista antiga sincronizada',
      ]);
    },
  );

  test(
    'suggestReplenishmentItems prioritizes products repeated across history',
    () async {
      final store = _createStore(
        catalogProducts: [
          _catalogProduct(
            name: 'Arroz',
            barcode: '789100000001',
            unitPrice: 12,
            usageCount: 3,
          ),
          _catalogProduct(
            name: 'Chocolate',
            barcode: '789100000002',
            unitPrice: 9,
            usageCount: 1,
          ),
        ],
        history: [
          _purchase(
            closedAt: DateTime(2026, 1, 8),
            items: [_item(name: 'Arroz', quantity: 2, unitPrice: 10)],
          ),
          _purchase(
            closedAt: DateTime(2026, 2, 8),
            items: [_item(name: 'Arroz', quantity: 2, unitPrice: 11)],
          ),
          _purchase(
            closedAt: DateTime(2026, 3, 8),
            items: [_item(name: 'Arroz', quantity: 3, unitPrice: 12)],
          ),
          _purchase(
            closedAt: DateTime(2026, 4, 8),
            items: [_item(name: 'Chocolate', quantity: 6, unitPrice: 9)],
          ),
        ],
      );

      await store.load();

      final suggestions = store.suggestReplenishmentItems(
        referenceDate: DateTime(2026, 5, 15),
        limit: 5,
      );

      expect(suggestions.first.name, 'Arroz');
      expect(suggestions.first.source, ReplenishmentSuggestionSource.recurring);
      expect(suggestions.first.occurrences, 3);
      expect(suggestions.first.suggestedQuantity, 2);
      expect(suggestions.first.suggestedUnitPrice, 12);
    },
  );
}

ShoppingListsStore _createStore({
  List<ShoppingListModel> lists = const <ShoppingListModel>[],
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
  List<CompletedPurchase> history = const <CompletedPurchase>[],
  SharedCatalogImportPreferences? sharedCatalogImportPreferences,
}) {
  return ShoppingListsStore(
    _MemoryShoppingListsStorage(lists),
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(
      _MemoryProductCatalogStorage(catalogProducts),
    ),
    historyStorage: _MemoryPurchaseHistoryStorage(history),
    lookupService: const _NoopLookupService(),
    homeWidgetService: const NoopShoppingHomeWidgetService(),
    sharedCatalogImportPreferences: sharedCatalogImportPreferences,
  );
}

class _MemoryShoppingListsStorage implements ShoppingListsStorage {
  const _MemoryShoppingListsStorage([
    this._lists = const <ShoppingListModel>[],
  ]);

  final List<ShoppingListModel> _lists;

  @override
  Future<List<ShoppingListModel>> loadLists() async {
    return _lists;
  }

  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {}
}

class _MemoryProductCatalogStorage implements ProductCatalogStorage {
  _MemoryProductCatalogStorage(this._products);

  final List<CatalogProduct> _products;

  @override
  Future<List<CatalogProduct>> loadProducts() async {
    return _products;
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {}
}

class _MemoryPurchaseHistoryStorage implements PurchaseHistoryStorage {
  _MemoryPurchaseHistoryStorage(this._history);

  final List<CompletedPurchase> _history;

  @override
  Future<List<CompletedPurchase>> loadHistory() async {
    return _history;
  }

  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {}
}

class _NoopLookupService implements ProductLookupService {
  const _NoopLookupService();

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    return null;
  }
}

CompletedPurchase _purchase({
  required DateTime closedAt,
  required List<ShoppingItem> items,
}) {
  return CompletedPurchase(
    id: uniqueId(),
    listId: uniqueId(),
    listName: 'Compra',
    closedAt: closedAt,
    items: items,
  );
}

ShoppingItem _item({
  required String name,
  required int quantity,
  required double unitPrice,
  String? barcode,
}) {
  return ShoppingItem(
    id: uniqueId(),
    name: name,
    quantity: quantity,
    unitPrice: unitPrice,
    barcode: barcode,
    isPurchased: true,
    category: ShoppingCategory.grocery,
    priceHistory: [
      PriceHistoryEntry(price: unitPrice, recordedAt: DateTime(2026, 1, 1)),
    ],
  );
}

CatalogProduct _catalogProduct({
  required String name,
  required String barcode,
  required double unitPrice,
  required int usageCount,
}) {
  return CatalogProduct(
    id: uniqueId(),
    name: name,
    category: ShoppingCategory.grocery,
    barcode: barcode,
    unitPrice: unitPrice,
    usageCount: usageCount,
    updatedAt: DateTime(2026, 4, 1),
    priceHistory: [
      PriceHistoryEntry(price: unitPrice, recordedAt: DateTime(2026, 4, 1)),
    ],
  );
}

ShoppingListModel _shoppingList({
  required String name,
  required DateTime createdAt,
  required DateTime updatedAt,
  List<ShoppingItem> items = const <ShoppingItem>[],
}) {
  return ShoppingListModel(
    id: uniqueId(),
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    items: items,
  );
}

class _MemorySharedCatalogImportPreferences
    implements SharedCatalogImportPreferences {
  bool _autoImportOwned = true;
  bool _autoImportAll = false;
  final Set<String> _enabledListIds = <String>{};

  @override
  Future<bool> loadAutoImportOwnedSharedLists() async {
    return _autoImportOwned;
  }

  @override
  Future<void> saveAutoImportOwnedSharedLists(bool enabled) async {
    _autoImportOwned = enabled;
  }

  @override
  Future<bool> loadAutoImportAllSharedLists() async {
    return _autoImportAll;
  }

  @override
  Future<Set<String>> loadEnabledSharedListIds() async {
    return {..._enabledListIds};
  }

  @override
  Future<void> saveAutoImportAllSharedLists(bool enabled) async {
    _autoImportAll = enabled;
  }

  @override
  Future<void> saveEnabledSharedListIds(Set<String> listIds) async {
    _enabledListIds
      ..clear()
      ..addAll(listIds);
  }
}
