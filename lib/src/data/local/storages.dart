import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/pantry.dart';

typedef _JsonEntityDecoder<T> = T Function(Map<String, dynamic> json);

class LocalStorageCorruptionException implements Exception {
  const LocalStorageCorruptionException({
    required this.storageKey,
    required this.cause,
  });

  final String storageKey;
  final Object cause;

  @override
  String toString() {
    return 'Os dados locais de "$storageKey" estão corrompidos e não puderam '
        'ser recuperados. Causa: $cause';
  }
}

Future<List<T>> _loadProtectedJsonList<T>({
  required String storageKey,
  required _JsonEntityDecoder<T> decodeEntity,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final pendingKey = '${storageKey}_pending';
  final backupKey = '${storageKey}_backup';
  final candidates = <String>[pendingKey, storageKey, backupKey];
  Object? lastError;
  var foundPayload = false;

  for (final candidateKey in candidates) {
    final raw = prefs.getString(candidateKey);
    if (raw == null || raw.isEmpty) {
      continue;
    }
    foundPayload = true;
    try {
      final decoded = _decodeJsonList(raw, decodeEntity);
      if (candidateKey != storageKey) {
        await prefs.setString(storageKey, raw);
      }
      await prefs.remove(pendingKey);
      return decoded;
    } catch (error) {
      lastError = error;
    }
  }

  if (!foundPayload) {
    return const [];
  }
  throw LocalStorageCorruptionException(
    storageKey: storageKey,
    cause: lastError ?? const FormatException('Conteúdo inválido.'),
  );
}

List<T> _decodeJsonList<T>(String raw, _JsonEntityDecoder<T> decodeEntity) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    throw const FormatException('Era esperada uma lista JSON.');
  }
  return decoded
      .map<T>((entry) {
        if (entry is! Map) {
          throw const FormatException('Registro local não é um objeto JSON.');
        }
        return decodeEntity(Map<String, dynamic>.from(entry));
      })
      .toList(growable: false);
}

Future<void> _saveProtectedJsonList<T>({
  required String storageKey,
  required Iterable<T> entries,
  required Map<String, dynamic> Function(T entry) encodeEntity,
  required _JsonEntityDecoder<T> decodeEntity,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final pendingKey = '${storageKey}_pending';
  final backupKey = '${storageKey}_backup';
  final payload = jsonEncode(entries.map(encodeEntity).toList(growable: false));

  _decodeJsonList(payload, decodeEntity);
  await prefs.setString(pendingKey, payload);

  final current = prefs.getString(storageKey);
  if (current != null && current.isNotEmpty) {
    try {
      _decodeJsonList(current, decodeEntity);
      await prefs.setString(backupKey, current);
    } on Object {
      // Preserve the last valid backup instead of replacing it with corruption.
    }
  }

  await prefs.setString(storageKey, payload);
  await prefs.remove(pendingKey);
}

class SharedPrefsShoppingListsStorage implements ShoppingListsStorage {
  static const String _storageKey = 'shopping_lists_v2';

  @override
  Future<List<ShoppingListModel>> loadLists() => _loadProtectedJsonList(
    storageKey: _storageKey,
    decodeEntity: ShoppingListModel.fromJson,
  );

  @override
  Future<void> saveLists(List<ShoppingListModel> lists) =>
      _saveProtectedJsonList(
        storageKey: _storageKey,
        entries: lists,
        encodeEntity: (list) => list.toJson(),
        decodeEntity: ShoppingListModel.fromJson,
      );
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
  Future<List<CatalogProduct>> loadProducts() => _loadProtectedJsonList(
    storageKey: _storageKey,
    decodeEntity: CatalogProduct.fromJson,
  );

  @override
  Future<void> saveProducts(List<CatalogProduct> products) =>
      _saveProtectedJsonList(
        storageKey: _storageKey,
        entries: products,
        encodeEntity: (product) => product.toJson(),
        decodeEntity: CatalogProduct.fromJson,
      );
}

class SharedPrefsPurchaseHistoryStorage implements PurchaseHistoryStorage {
  static const String _storageKey = 'shopping_completed_history_v1';

  @override
  Future<List<CompletedPurchase>> loadHistory() => _loadProtectedJsonList(
    storageKey: _storageKey,
    decodeEntity: CompletedPurchase.fromJson,
  );

  @override
  Future<void> saveHistory(List<CompletedPurchase> history) =>
      _saveProtectedJsonList(
        storageKey: _storageKey,
        entries: history,
        encodeEntity: (entry) => entry.toJson(),
        decodeEntity: CompletedPurchase.fromJson,
      );
}

class SharedPrefsPantryStorage implements PantryStorage {
  static const String _storageKey = 'shopping_pantry_v1';

  @override
  Future<List<PantryItem>> loadItems() => _loadProtectedJsonList(
    storageKey: _storageKey,
    decodeEntity: PantryItem.fromJson,
  );

  @override
  Future<void> saveItems(List<PantryItem> items) => _saveProtectedJsonList(
    storageKey: _storageKey,
    entries: items,
    encodeEntity: (item) => item.toJson(),
    decodeEntity: PantryItem.fromJson,
  );
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
