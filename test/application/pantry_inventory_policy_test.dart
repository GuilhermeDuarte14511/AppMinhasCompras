import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/pantry_inventory_policy.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/pantry.dart';

void main() {
  const policy = PantryInventoryPolicy();
  final purchasedAt = DateTime(2026, 7, 20, 12);

  test('finalized purchase replenishes matching pantry item by barcode', () {
    final result = policy.replenishFromPurchase(
      current: [
        PantryItem(
          id: 'pantry-1',
          name: 'Detergente antigo',
          category: ShoppingCategory.cleaning,
          barcode: '7891234567895',
          unitPrice: 2.5,
          suggestedQuantity: 1,
          status: PantryStockStatus.outOfStock,
          updatedAt: DateTime(2026, 7, 10),
        ),
      ],
      purchasedItems: [
        const ShoppingItem(
          id: 'item-1',
          name: 'Detergente Minuano',
          quantity: 3,
          unitPrice: 3.49,
          category: ShoppingCategory.cleaning,
          barcode: '7891234567895',
          isPurchased: true,
        ),
      ],
      catalogProducts: const [],
      purchasedAt: purchasedAt,
      createId: () => 'new-id',
    );

    expect(result, hasLength(1));
    expect(result.single.id, 'pantry-1');
    expect(result.single.name, 'Detergente Minuano');
    expect(result.single.status, PantryStockStatus.inStock);
    expect(result.single.suggestedQuantity, 3);
    expect(result.single.unitPrice, 3.49);
    expect(result.single.lastPurchasedAt, purchasedAt);
  });

  test('purchase creates pantry item and links the catalog product', () {
    final result = policy.replenishFromPurchase(
      current: const [],
      purchasedItems: [
        const ShoppingItem(
          id: 'item-1',
          name: 'Arroz',
          quantity: 2,
          unitPrice: 20,
          category: ShoppingCategory.grocery,
          isPurchased: true,
        ),
      ],
      catalogProducts: [
        CatalogProduct(
          id: 'catalog-1',
          name: 'arroz',
          category: ShoppingCategory.grocery,
          unitPrice: 19.5,
          updatedAt: purchasedAt,
        ),
      ],
      purchasedAt: purchasedAt,
      createId: () => 'pantry-1',
    );

    expect(result.single.id, 'pantry-1');
    expect(result.single.catalogProductId, 'catalog-1');
    expect(result.single.status, PantryStockStatus.inStock);
  });

  test('catalog insertion merges normalized names instead of duplicating', () {
    final result = policy.addCatalogProduct(
      current: [
        PantryItem(
          id: 'pantry-1',
          name: 'Café',
          category: ShoppingCategory.grocery,
          status: PantryStockStatus.runningLow,
          updatedAt: DateTime(2026, 7, 10),
        ),
      ],
      product: CatalogProduct(
        id: 'catalog-1',
        name: 'cafe',
        category: ShoppingCategory.grocery,
        unitPrice: 18,
        updatedAt: purchasedAt,
      ),
      status: PantryStockStatus.inStock,
      updatedAt: purchasedAt,
      createId: () => 'new-id',
    );

    expect(result, hasLength(1));
    expect(result.single.id, 'pantry-1');
    expect(result.single.catalogProductId, 'catalog-1');
    expect(result.single.status, PantryStockStatus.inStock);
  });

  test('restock draft uses last purchased quantity and safe price', () {
    final draft = policy.toShoppingDraft(
      PantryItem(
        id: 'pantry-1',
        name: 'Leite',
        category: ShoppingCategory.dairy,
        unitPrice: null,
        suggestedQuantity: 4,
        status: PantryStockStatus.outOfStock,
        updatedAt: purchasedAt,
      ),
    );

    expect(draft.name, 'Leite');
    expect(draft.quantity, 4);
    expect(draft.unitPrice, 0);
  });
}
