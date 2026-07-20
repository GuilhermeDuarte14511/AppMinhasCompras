import 'dart:math';

import '../../application/ports.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class ProductCatalogRepository implements ProductCatalogGateway {
  ProductCatalogRepository(this._storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ProductCatalogStorage _storage;
  final DateTime Function() _now;
  final List<CatalogProduct> _products = <CatalogProduct>[];
  final Map<String, int> _indexByNormalizedName = <String, int>{};
  final Map<String, int> _indexByBarcode = <String, int>{};

  bool _loaded = false;
  bool _suggestionsDirty = true;
  List<CatalogProduct> _sortedSuggestionCache = const <CatalogProduct>[];

  @override
  Future<void> load() async {
    if (_loaded) {
      return;
    }

    final loaded = await _storage.loadProducts();
    final normalized = _mergeDuplicatedProducts(
      loaded,
      collapseLegacyDailyDuplicates: true,
    );
    _products
      ..clear()
      ..addAll(normalized);
    _rebuildIndexes();
    _loaded = true;
    if (!_sameCatalogProducts(loaded, normalized)) {
      await _save();
    }
  }

  @override
  List<CatalogProduct> allProducts() {
    if (!_loaded) {
      return const <CatalogProduct>[];
    }
    return List.unmodifiable(
      _products.map(
        (product) => product.copyWith(
          priceHistory: List<PriceHistoryEntry>.from(product.priceHistory),
        ),
      ),
    );
  }

  @override
  void dispose() {}

  @override
  CatalogProduct? findByName(String rawName) {
    if (!_loaded) {
      return null;
    }

    final normalized = normalizeQuery(rawName);
    if (normalized.isEmpty) {
      return null;
    }

    final exactIndex = _indexByNormalizedName[normalized];
    if (exactIndex != null) {
      return _products[exactIndex];
    }

    for (final product in _sortedForSuggestions()) {
      final candidate = normalizeQuery(product.name);
      if (candidate.contains(normalized) || normalized.contains(candidate)) {
        return product;
      }
    }

    return null;
  }

  @override
  CatalogProduct? findByBarcode(String? rawBarcode) {
    if (!_loaded) {
      return null;
    }

    final barcode = sanitizeBarcode(rawBarcode);
    if (barcode == null) {
      return null;
    }

    final index = _indexByBarcode[barcode];
    if (index == null) {
      return null;
    }
    return _products[index];
  }

  @override
  List<String> suggestNames({String query = '', int limit = 20}) {
    if (!_loaded || limit <= 0) {
      return const <String>[];
    }

    final normalizedQuery = normalizeQuery(query);
    final output = <String>[];
    for (final product in _sortedForSuggestions()) {
      final name = product.name.trim();
      if (name.isEmpty) {
        continue;
      }
      final normalized = normalizeQuery(name);
      if (normalizedQuery.isNotEmpty && !normalized.contains(normalizedQuery)) {
        continue;
      }
      output.add(name);
      if (output.length >= limit) {
        break;
      }
    }
    return output;
  }

  @override
  Future<void> upsertFromDraft(ShoppingItemDraft draft) async {
    await _ensureLoaded();
    final now = _now();
    final changed = _upsertCatalogEntry(
      name: draft.name,
      category: draft.category,
      unitPrice: draft.unitPrice,
      barcode: draft.barcode,
      usageIncrement: 1,
      incomingHistory: const <PriceHistoryEntry>[],
      updatedAt: now,
    );

    if (changed) {
      await _save();
    }
  }

  @override
  Future<void> upsertFromLookupResult(ProductLookupResult result) async {
    await _ensureLoaded();

    final name = result.name?.trim();
    if (name == null || name.isEmpty) {
      return;
    }

    final now = _now();
    final changed = _upsertCatalogEntry(
      name: name,
      category: result.category ?? ShoppingCategory.other,
      unitPrice: result.unitPrice,
      barcode: result.barcode,
      usageIncrement: 1,
      incomingHistory: result.priceHistory,
      updatedAt: now,
    );

    if (changed) {
      await _save();
    }
  }

  @override
  Future<void> ingestFromLists(Iterable<ShoppingListModel> lists) async {
    await _ensureLoaded();

    var changed = false;
    for (final list in lists) {
      for (final item in list.items) {
        final didChange = _upsertCatalogEntry(
          name: item.name,
          category: item.category,
          unitPrice: item.unitPrice,
          barcode: item.barcode,
          usageIncrement: 0,
          incomingHistory: item.priceHistory,
          updatedAt: list.updatedAt,
        );
        if (didChange) {
          changed = true;
        }
      }
    }

    if (changed) {
      await _save();
    }
  }

  @override
  Future<void> replaceAllProducts(List<CatalogProduct> products) async {
    _products
      ..clear()
      ..addAll(
        _mergeDuplicatedProducts(products, collapseLegacyDailyDuplicates: true),
      );
    _rebuildIndexes();
    _loaded = true;
    await _save();
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) {
      return;
    }
    await load();
  }

  bool _upsertCatalogEntry({
    required String name,
    required ShoppingCategory category,
    required double? unitPrice,
    required String? barcode,
    required int usageIncrement,
    required List<PriceHistoryEntry> incomingHistory,
    required DateTime updatedAt,
  }) {
    final trimmedName = name.trim();
    final normalizedName = normalizeQuery(trimmedName);
    if (normalizedName.isEmpty) {
      return false;
    }

    final sanitizedBarcode = sanitizeBarcode(barcode);
    final price = unitPrice != null && unitPrice > 0 ? unitPrice : null;
    var normalizedHistory = _normalizeHistory(incomingHistory);
    normalizedHistory = _appendPriceChange(
      normalizedHistory,
      price: price,
      recordedAt: updatedAt,
    );

    final existingIndex = _findExistingIndex(
      normalizedName: normalizedName,
      barcode: sanitizedBarcode,
    );

    if (existingIndex == null) {
      final now = updatedAt;
      _products.add(
        CatalogProduct(
          id: uniqueId(),
          name: trimmedName,
          category: category,
          unitPrice: price,
          barcode: sanitizedBarcode,
          usageCount: max(1, usageIncrement),
          updatedAt: now,
          priceHistory: normalizedHistory,
        ),
      );
      _rebuildIndexes();
      return true;
    }

    final existing = _products[existingIndex];
    final resolvedName = trimmedName.isEmpty ? existing.name : trimmedName;
    final resolvedCategory = _resolveCategory(existing.category, category);
    final mergedHistory = _mergeHistory(
      existing.priceHistory,
      normalizedHistory,
      fallbackPrice: price,
      fallbackRecordedAt: updatedAt,
    );

    final resolvedUnitPrice = mergedHistory.isNotEmpty
        ? mergedHistory.last.price
        : (price ?? existing.unitPrice);

    final resolvedBarcode = sanitizedBarcode ?? existing.barcode;
    final resolvedUsage = existing.usageCount + usageIncrement;

    final updated = existing.copyWith(
      name: resolvedName,
      category: resolvedCategory,
      unitPrice: resolvedUnitPrice,
      barcode: resolvedBarcode,
      usageCount: resolvedUsage,
      updatedAt: updatedAt.isAfter(existing.updatedAt)
          ? updatedAt
          : existing.updatedAt,
      priceHistory: mergedHistory,
    );

    final changed =
        updated.name != existing.name ||
        updated.category != existing.category ||
        updated.unitPrice != existing.unitPrice ||
        updated.barcode != existing.barcode ||
        updated.usageCount != existing.usageCount ||
        updated.updatedAt != existing.updatedAt ||
        !_sameHistory(updated.priceHistory, existing.priceHistory);

    if (!changed) {
      return false;
    }

    _products[existingIndex] = updated;
    _rebuildIndexes();
    return true;
  }

  int? _findExistingIndex({
    required String normalizedName,
    required String? barcode,
  }) {
    final byName = _indexByNormalizedName[normalizedName];
    if (byName != null) {
      return byName;
    }

    if (barcode != null) {
      final byBarcode = _indexByBarcode[barcode];
      if (byBarcode != null) {
        return byBarcode;
      }
    }

    return null;
  }

  void _rebuildIndexes() {
    _indexByNormalizedName.clear();
    _indexByBarcode.clear();

    for (var i = 0; i < _products.length; i++) {
      final product = _products[i];
      final normalizedName = normalizeQuery(product.name);
      if (normalizedName.isNotEmpty) {
        final current = _indexByNormalizedName[normalizedName];
        if (current == null || _isBetter(_products[i], _products[current])) {
          _indexByNormalizedName[normalizedName] = i;
        }
      }

      final barcode = sanitizeBarcode(product.barcode);
      if (barcode != null) {
        final current = _indexByBarcode[barcode];
        if (current == null || _isBetter(_products[i], _products[current])) {
          _indexByBarcode[barcode] = i;
        }
      }
    }

    _suggestionsDirty = true;
  }

  bool _isBetter(CatalogProduct left, CatalogProduct right) {
    final byUsage = left.usageCount.compareTo(right.usageCount);
    if (byUsage != 0) {
      return byUsage > 0;
    }
    return left.updatedAt.isAfter(right.updatedAt);
  }

  List<CatalogProduct> _sortedForSuggestions() {
    if (!_suggestionsDirty) {
      return _sortedSuggestionCache;
    }

    final sorted = [..._products]
      ..sort((a, b) {
        final byUsage = b.usageCount.compareTo(a.usageCount);
        if (byUsage != 0) {
          return byUsage;
        }
        final byDate = b.updatedAt.compareTo(a.updatedAt);
        if (byDate != 0) {
          return byDate;
        }
        return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
      });

    _sortedSuggestionCache = List.unmodifiable(sorted);
    _suggestionsDirty = false;
    return _sortedSuggestionCache;
  }

  Future<void> _save() async {
    await _storage.saveProducts(_products);
  }

  List<CatalogProduct> _mergeDuplicatedProducts(
    List<CatalogProduct> source, {
    bool collapseLegacyDailyDuplicates = false,
  }) {
    final mergedByName = <String, CatalogProduct>{};

    for (final rawProduct in source) {
      final product = _normalizeProduct(
        rawProduct,
        collapseLegacyDailyDuplicates: collapseLegacyDailyDuplicates,
      );
      final normalizedName = normalizeQuery(product.name);
      if (normalizedName.isEmpty) {
        continue;
      }

      final current = mergedByName[normalizedName];
      if (current == null) {
        mergedByName[normalizedName] = product;
        continue;
      }

      final mergedHistory = _mergeHistory(
        current.priceHistory,
        product.priceHistory,
        fallbackPrice: product.unitPrice,
        fallbackRecordedAt: product.updatedAt,
      );
      final merged = current.copyWith(
        category: _resolveCategory(current.category, product.category),
        unitPrice: mergedHistory.isNotEmpty
            ? mergedHistory.last.price
            : (product.unitPrice ?? current.unitPrice),
        barcode: sanitizeBarcode(product.barcode) ?? current.barcode,
        usageCount: max(current.usageCount, product.usageCount),
        updatedAt: product.updatedAt.isAfter(current.updatedAt)
            ? product.updatedAt
            : current.updatedAt,
        priceHistory: mergedHistory,
      );
      mergedByName[normalizedName] = merged;
    }

    return mergedByName.values.toList(growable: false);
  }

  CatalogProduct _normalizeProduct(
    CatalogProduct product, {
    required bool collapseLegacyDailyDuplicates,
  }) {
    var history = _normalizeHistory(
      product.priceHistory,
      collapseLegacyDailyDuplicates: collapseLegacyDailyDuplicates,
    );
    if (history.isEmpty) {
      history = _appendPriceChange(
        history,
        price: product.unitPrice,
        recordedAt: product.updatedAt,
      );
    }
    return product.copyWith(
      unitPrice: history.isNotEmpty ? history.last.price : product.unitPrice,
      priceHistory: history,
    );
  }

  ShoppingCategory _resolveCategory(
    ShoppingCategory current,
    ShoppingCategory incoming,
  ) {
    if (incoming == ShoppingCategory.other) {
      return current;
    }
    return incoming;
  }

  List<PriceHistoryEntry> _normalizeHistory(
    List<PriceHistoryEntry> source, {
    bool collapseLegacyDailyDuplicates = false,
  }) {
    final history = <PriceHistoryEntry>[];
    for (final entry in source) {
      if (entry.price > 0) {
        history.add(entry);
      }
    }

    history.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return _compactHistory(
      history,
      collapseLegacyDailyDuplicates: collapseLegacyDailyDuplicates,
    );
  }

  List<PriceHistoryEntry> _mergeHistory(
    List<PriceHistoryEntry> current,
    List<PriceHistoryEntry> incoming, {
    double? fallbackPrice,
    required DateTime fallbackRecordedAt,
  }) {
    final merged = <PriceHistoryEntry>[...current, ...incoming]
      ..removeWhere((entry) => entry.price <= 0)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    return _appendPriceChange(
      _compactHistory(merged),
      price: fallbackPrice,
      recordedAt: fallbackRecordedAt,
    );
  }

  List<PriceHistoryEntry> _appendPriceChange(
    List<PriceHistoryEntry> history, {
    required double? price,
    required DateTime recordedAt,
  }) {
    if (price == null || price <= 0) {
      return history;
    }
    if (history.isNotEmpty && (history.last.price - price).abs() < 0.0001) {
      return history;
    }
    final updated = <PriceHistoryEntry>[
      ...history,
      PriceHistoryEntry(price: price, recordedAt: recordedAt),
    ]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return _compactHistory(updated);
  }

  List<PriceHistoryEntry> _compactHistory(
    List<PriceHistoryEntry> source, {
    bool collapseLegacyDailyDuplicates = false,
  }) {
    if (source.isEmpty) {
      return const <PriceHistoryEntry>[];
    }

    final compacted = <PriceHistoryEntry>[];
    final seenMinutePrices = <String>{};
    final seenDailyPrices = <String>{};
    for (final entry in source) {
      final priceInCents = (entry.price * 100).round();
      final minuteKey =
          '${entry.recordedAt.year}-${entry.recordedAt.month}-'
          '${entry.recordedAt.day}-${entry.recordedAt.hour}-'
          '${entry.recordedAt.minute}:$priceInCents';
      if (!seenMinutePrices.add(minuteKey)) {
        continue;
      }
      if (collapseLegacyDailyDuplicates) {
        final dailyKey =
            '${entry.recordedAt.year}-${entry.recordedAt.month}-'
            '${entry.recordedAt.day}:$priceInCents';
        if (!seenDailyPrices.add(dailyKey)) {
          continue;
        }
      }
      if (compacted.isEmpty) {
        compacted.add(entry);
        continue;
      }

      final last = compacted.last;
      final samePrice = (last.price - entry.price).abs() < 0.0001;
      if (samePrice) {
        continue;
      }
      compacted.add(entry);
    }

    const maxEntries = 40;
    if (compacted.length <= maxEntries) {
      return compacted;
    }
    return compacted.sublist(compacted.length - maxEntries);
  }

  bool _sameCatalogProducts(
    List<CatalogProduct> left,
    List<CatalogProduct> right,
  ) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      final a = left[index];
      final b = right[index];
      if (a.id != b.id ||
          a.name != b.name ||
          a.category != b.category ||
          a.unitPrice != b.unitPrice ||
          a.barcode != b.barcode ||
          a.usageCount != b.usageCount ||
          a.updatedAt != b.updatedAt ||
          !_sameHistory(a.priceHistory, b.priceHistory)) {
        return false;
      }
    }
    return true;
  }

  bool _sameHistory(
    List<PriceHistoryEntry> left,
    List<PriceHistoryEntry> right,
  ) {
    if (left.length != right.length) {
      return false;
    }

    for (var i = 0; i < left.length; i++) {
      final a = left[i];
      final b = right[i];
      if ((a.price - b.price).abs() > 0.0001) {
        return false;
      }
      if (a.recordedAt != b.recordedAt) {
        return false;
      }
    }

    return true;
  }
}
