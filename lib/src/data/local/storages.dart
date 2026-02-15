import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports.dart';
import '../../domain/models_and_utils.dart';

class SharedPrefsShoppingListsStorage implements ShoppingListsStorage {
  static const String _storageKey = 'shopping_lists_v2';

  @override
  Future<List<ShoppingListModel>> loadLists() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <ShoppingListModel>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <ShoppingListModel>[];
      }

      final lists = <ShoppingListModel>[];
      for (final entry in decoded) {
        if (entry is Map) {
          lists.add(
            ShoppingListModel.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      return lists;
    } catch (_) {
      return const <ShoppingListModel>[];
    }
  }

  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      lists.map((list) => list.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, payload);
  }
}

class SharedPrefsProductCatalogStorage implements ProductCatalogStorage {
  static const String _storageKey = 'shopping_product_catalog_v2';

  @override
  Future<List<CatalogProduct>> loadProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <CatalogProduct>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CatalogProduct>[];
      }

      final products = <CatalogProduct>[];
      for (final entry in decoded) {
        if (entry is Map) {
          products.add(
            CatalogProduct.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      return products;
    } catch (_) {
      return const <CatalogProduct>[];
    }
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      products.map((product) => product.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, payload);
  }
}

class SharedPrefsPurchaseHistoryStorage implements PurchaseHistoryStorage {
  static const String _storageKey = 'shopping_completed_history_v1';

  @override
  Future<List<CompletedPurchase>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <CompletedPurchase>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <CompletedPurchase>[];
      }
      final history = <CompletedPurchase>[];
      for (final entry in decoded) {
        if (entry is Map) {
          history.add(
            CompletedPurchase.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
      return history;
    } catch (_) {
      return const <CompletedPurchase>[];
    }
  }

  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(
      history.map((entry) => entry.toJson()).toList(growable: false),
    );
    await prefs.setString(_storageKey, payload);
  }
}

class InMemoryProductCatalogStorage implements ProductCatalogStorage {
  List<CatalogProduct> _products = const <CatalogProduct>[];

  @override
  Future<List<CatalogProduct>> loadProducts() async {
    return _cloneProducts(_products);
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    _products = _cloneProducts(products);
  }

  List<CatalogProduct> _cloneProducts(List<CatalogProduct> source) {
    return source
        .map(
          (product) => product.copyWith(
            priceHistory: List<PriceHistoryEntry>.from(product.priceHistory),
            updatedAt: product.updatedAt,
          ),
        )
        .toList(growable: false);
  }
}

class InMemoryPurchaseHistoryStorage implements PurchaseHistoryStorage {
  List<CompletedPurchase> _history = const <CompletedPurchase>[];

  @override
  Future<List<CompletedPurchase>> loadHistory() async {
    return _history
        .map(
          (entry) => entry.copyWith(
            items: entry.items
                .map((item) => item.copyWith())
                .toList(growable: false),
            closedAt: entry.closedAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {
    _history = history
        .map(
          (entry) => entry.copyWith(
            items: entry.items
                .map((item) => item.copyWith())
                .toList(growable: false),
            closedAt: entry.closedAt,
          ),
        )
        .toList(growable: false);
  }
}
