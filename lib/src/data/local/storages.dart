import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/pantry.dart';

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

class SharedPrefsSharedCatalogImportPreferences
    implements SharedCatalogImportPreferences {
  static const String _autoImportOwnedKey =
      'shared_catalog_import_auto_import_owned';
  static const String _autoImportAllKey =
      'shared_catalog_import_auto_import_all';
  static const String _enabledListIdsKey =
      'shared_catalog_import_enabled_list_ids';

  const SharedPrefsSharedCatalogImportPreferences();

  @override
  Future<bool> loadAutoImportOwnedSharedLists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoImportOwnedKey) ?? true;
  }

  @override
  Future<void> saveAutoImportOwnedSharedLists(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoImportOwnedKey, enabled);
  }

  @override
  Future<bool> loadAutoImportAllSharedLists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoImportAllKey) ?? false;
  }

  @override
  Future<Set<String>> loadEnabledSharedListIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_enabledListIdsKey) ?? const <String>[])
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  @override
  Future<void> saveAutoImportAllSharedLists(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoImportAllKey, enabled);
  }

  @override
  Future<void> saveEnabledSharedListIds(Set<String> listIds) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized =
        listIds
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false)
          ..sort();
    await prefs.setStringList(_enabledListIdsKey, normalized);
  }
}

class InMemorySharedCatalogImportPreferences
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
      ..addAll(
        listIds.map((entry) => entry.trim()).where((entry) => entry.isNotEmpty),
      );
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

class SharedPrefsPantryStorage implements PantryStorage {
  static const String _storageKey = 'shopping_pantry_v1';

  @override
  Future<List<PantryItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const <PantryItem>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <PantryItem>[];
      }
      return decoded
          .whereType<Map>()
          .map((entry) => PantryItem.fromJson(Map<String, dynamic>.from(entry)))
          .where((item) => item.name.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const <PantryItem>[];
    }
  }

  @override
  Future<void> saveItems(List<PantryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(items.map((item) => item.toJson()).toList(growable: false)),
    );
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

class InMemoryPantryStorage implements PantryStorage {
  List<PantryItem> _items = const <PantryItem>[];

  @override
  Future<List<PantryItem>> loadItems() async {
    return _items.map((item) => item.copyWith()).toList(growable: false);
  }

  @override
  Future<void> saveItems(List<PantryItem> items) async {
    _items = items.map((item) => item.copyWith()).toList(growable: false);
  }
}
