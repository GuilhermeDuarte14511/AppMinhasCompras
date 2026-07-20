import 'dart:math';

import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import '../domain/pantry.dart';

class PantryInventoryPolicy {
  const PantryInventoryPolicy();

  List<PantryItem> replenishFromPurchase({
    required Iterable<PantryItem> current,
    required Iterable<ShoppingItem> purchasedItems,
    required Iterable<CatalogProduct> catalogProducts,
    required DateTime purchasedAt,
    required String Function() createId,
  }) {
    final result = current
        .map((item) => item.copyWith())
        .toList(growable: true);
    final catalog = List<CatalogProduct>.from(catalogProducts);

    for (final purchased in purchasedItems) {
      final name = purchased.name.trim();
      if (name.isEmpty) {
        continue;
      }

      final barcode = sanitizeBarcode(purchased.barcode);
      final normalizedName = _normalizedIdentity(name);
      final pantryIndex = _findPantryIndex(
        result,
        barcode: barcode,
        normalizedName: normalizedName,
      );
      final catalogMatch = _findCatalogProduct(
        catalog,
        barcode: barcode,
        normalizedName: normalizedName,
      );
      final existing = pantryIndex < 0 ? null : result[pantryIndex];
      final resolvedPrice = purchased.unitPrice > 0
          ? purchased.unitPrice
          : existing?.unitPrice ?? catalogMatch?.unitPrice;
      final replenished = PantryItem(
        id: existing?.id ?? createId(),
        catalogProductId: catalogMatch?.id ?? existing?.catalogProductId,
        name: name,
        category: _preferredCategory(
          purchased.category,
          existing?.category,
          catalogMatch?.category,
        ),
        barcode: barcode ?? existing?.barcode ?? catalogMatch?.barcode,
        unitPrice: resolvedPrice,
        suggestedQuantity: max(1, purchased.quantity),
        status: PantryStockStatus.inStock,
        updatedAt: purchasedAt,
        lastPurchasedAt: purchasedAt,
      );

      if (pantryIndex < 0) {
        result.add(replenished);
      } else {
        result[pantryIndex] = replenished;
      }
    }

    return _sorted(result);
  }

  List<PantryItem> addCatalogProduct({
    required Iterable<PantryItem> current,
    required CatalogProduct product,
    required PantryStockStatus status,
    required DateTime updatedAt,
    required String Function() createId,
  }) {
    final result = current
        .map((item) => item.copyWith())
        .toList(growable: true);
    final barcode = sanitizeBarcode(product.barcode);
    final index = _findPantryIndex(
      result,
      barcode: barcode,
      normalizedName: _normalizedIdentity(product.name),
    );
    final existing = index < 0 ? null : result[index];
    final updated = PantryItem(
      id: existing?.id ?? createId(),
      catalogProductId: product.id,
      name: product.name.trim(),
      category: product.category,
      barcode: barcode,
      unitPrice: product.unitPrice,
      suggestedQuantity: existing?.suggestedQuantity ?? 1,
      status: status,
      updatedAt: updatedAt,
      lastPurchasedAt: existing?.lastPurchasedAt,
    );
    if (index < 0) {
      result.add(updated);
    } else {
      result[index] = updated;
    }
    return _sorted(result);
  }

  ShoppingItemDraft toShoppingDraft(PantryItem item) {
    return ShoppingItemDraft(
      name: item.name.trim(),
      quantity: max(1, item.suggestedQuantity),
      unitPrice: max(0, item.unitPrice ?? 0),
      category: item.category,
      barcode: sanitizeBarcode(item.barcode),
    );
  }

  int _findPantryIndex(
    List<PantryItem> items, {
    required String? barcode,
    required String normalizedName,
  }) {
    if (barcode != null) {
      final byBarcode = items.indexWhere(
        (item) => sanitizeBarcode(item.barcode) == barcode,
      );
      if (byBarcode >= 0) {
        return byBarcode;
      }
    }
    return items.indexWhere(
      (item) => _normalizedIdentity(item.name) == normalizedName,
    );
  }

  CatalogProduct? _findCatalogProduct(
    List<CatalogProduct> products, {
    required String? barcode,
    required String normalizedName,
  }) {
    if (barcode != null) {
      for (final product in products) {
        if (sanitizeBarcode(product.barcode) == barcode) {
          return product;
        }
      }
    }
    for (final product in products) {
      if (_normalizedIdentity(product.name) == normalizedName) {
        return product;
      }
    }
    return null;
  }

  ShoppingCategory _preferredCategory(
    ShoppingCategory purchased,
    ShoppingCategory? existing,
    ShoppingCategory? catalog,
  ) {
    if (purchased != ShoppingCategory.other) {
      return purchased;
    }
    if (existing != null && existing != ShoppingCategory.other) {
      return existing;
    }
    return catalog ?? ShoppingCategory.other;
  }

  List<PantryItem> _sorted(List<PantryItem> items) {
    items.sort((a, b) {
      final byStatus = a.status.index.compareTo(b.status.index);
      if (byStatus != 0) {
        return byStatus;
      }
      return _normalizedIdentity(a.name).compareTo(_normalizedIdentity(b.name));
    });
    return List<PantryItem>.unmodifiable(items);
  }

  String _normalizedIdentity(String value) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    var normalized = normalizeQuery(value);
    for (var index = 0; index < accents.length; index++) {
      normalized = normalized.replaceAll(accents[index], plain[index]);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}
