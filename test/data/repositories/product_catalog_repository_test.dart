import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  test(
    'cleans an alternating legacy history and persists the migration',
    () async {
      final firstSeenAt = DateTime(2026, 7, 20, 11, 16);
      final corruptedHistory = List<PriceHistoryEntry>.generate(
        40,
        (index) => PriceHistoryEntry(
          price: index.isEven ? 19.59 : 22,
          recordedAt: firstSeenAt.add(Duration(minutes: index ~/ 4)),
        ),
      );
      final storage = _MemoryProductCatalogStorage([
        _product(
          unitPrice: 22,
          updatedAt: DateTime(2026, 7, 20, 11, 36),
          history: corruptedHistory,
        ),
      ]);
      final repository = ProductCatalogRepository(storage);

      await repository.load();

      final product = repository.allProducts().single;
      expect(product.priceHistory.map((entry) => entry.price), [19.59, 22]);
      expect(product.unitPrice, 22);
      expect(storage.saveCalls, 1);
      expect(storage.savedProducts.single.priceHistory, hasLength(2));
    },
  );

  test('merging the same list history repeatedly is idempotent', () async {
    final first = PriceHistoryEntry(
      price: 19.59,
      recordedAt: DateTime(2026, 7, 19, 10),
    );
    final second = PriceHistoryEntry(
      price: 22,
      recordedAt: DateTime(2026, 7, 20, 11),
    );
    final storage = _MemoryProductCatalogStorage([
      _product(
        unitPrice: 22,
        updatedAt: second.recordedAt,
        history: [first, second],
      ),
    ]);
    final repository = ProductCatalogRepository(storage);
    await repository.load();
    final list = ShoppingListModel(
      id: 'list-1',
      name: 'Mercado',
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 20, 12),
      items: [
        ShoppingItem(
          id: 'item-1',
          name: 'Produto',
          quantity: 1,
          unitPrice: 22,
          category: ShoppingCategory.grocery,
          priceHistory: [first, second, first, second],
        ),
      ],
    );

    await repository.ingestFromLists([list]);
    await repository.ingestFromLists([list]);

    expect(
      repository.allProducts().single.priceHistory.map((entry) => entry.price),
      [19.59, 22],
    );
  });

  test(
    'saving the same observed price does not create another record',
    () async {
      var now = DateTime(2026, 7, 20, 9);
      final repository = ProductCatalogRepository(
        _MemoryProductCatalogStorage(),
        now: () => now,
      );
      await repository.load();
      const firstDraft = ShoppingItemDraft(
        name: 'Produto',
        quantity: 1,
        unitPrice: 19.59,
        category: ShoppingCategory.grocery,
      );

      await repository.upsertFromDraft(firstDraft);
      now = DateTime(2026, 7, 20, 15);
      await repository.upsertFromDraft(firstDraft);
      now = DateTime(2026, 7, 21, 9);
      await repository.upsertFromDraft(firstDraft);
      now = DateTime(2026, 7, 21, 10);
      await repository.upsertFromDraft(
        const ShoppingItemDraft(
          name: 'Produto',
          quantity: 1,
          unitPrice: 22,
          category: ShoppingCategory.grocery,
        ),
      );

      final product = repository.allProducts().single;
      expect(product.priceHistory.map((entry) => entry.price), [19.59, 22]);
      expect(product.usageCount, 4);
    },
  );

  test(
    'keeps existing history authoritative over a stale unit price',
    () async {
      final storage = _MemoryProductCatalogStorage([
        _product(
          unitPrice: 10.50,
          updatedAt: DateTime(2026, 4, 4),
          history: [
            PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 4)),
            PriceHistoryEntry(price: 10.50, recordedAt: DateTime(2026, 4, 2)),
            PriceHistoryEntry(price: 11, recordedAt: DateTime(2026, 4, 3)),
          ],
        ),
      ]);
      final repository = ProductCatalogRepository(storage);

      await repository.load();
      final loaded = repository.allProducts();

      expect(loaded.single.unitPrice, 11);
      expect(loaded.single.priceHistory.map((entry) => entry.price), [
        10,
        10.50,
        11,
      ]);
    },
  );
}

CatalogProduct _product({
  required double unitPrice,
  required DateTime updatedAt,
  required List<PriceHistoryEntry> history,
}) {
  return CatalogProduct(
    id: 'product-1',
    name: 'Produto',
    category: ShoppingCategory.grocery,
    unitPrice: unitPrice,
    usageCount: 1,
    updatedAt: updatedAt,
    priceHistory: history,
  );
}

class _MemoryProductCatalogStorage implements ProductCatalogStorage {
  _MemoryProductCatalogStorage([
    List<CatalogProduct> initial = const <CatalogProduct>[],
  ]) : _products = List<CatalogProduct>.from(initial);

  List<CatalogProduct> _products;
  int saveCalls = 0;

  List<CatalogProduct> get savedProducts =>
      List<CatalogProduct>.unmodifiable(_products);

  @override
  Future<List<CatalogProduct>> loadProducts() async {
    return List<CatalogProduct>.from(_products);
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    saveCalls++;
    _products = List<CatalogProduct>.from(products);
  }
}
