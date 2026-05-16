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
    'suggestReplenishmentItems prioritizes products repeated across history',
    () async {
      final store = ShoppingListsStore(
        _MemoryShoppingListsStorage(),
        reminderService: const NoopShoppingReminderService(),
        productCatalog: ProductCatalogRepository(
          _MemoryProductCatalogStorage([
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
          ]),
        ),
        historyStorage: _MemoryPurchaseHistoryStorage([
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
        ]),
        lookupService: const _NoopLookupService(),
        homeWidgetService: const NoopShoppingHomeWidgetService(),
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

class _MemoryShoppingListsStorage implements ShoppingListsStorage {
  @override
  Future<List<ShoppingListModel>> loadLists() async {
    return const <ShoppingListModel>[];
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
