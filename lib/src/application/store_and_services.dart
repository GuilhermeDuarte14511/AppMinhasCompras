import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

import 'ports.dart';

class ShoppingListsStore extends ChangeNotifier {
  ShoppingListsStore(
    this._storage, {
    required ShoppingReminderService reminderService,
    required ProductCatalogGateway productCatalog,
    required PurchaseHistoryStorage historyStorage,
    required ProductLookupService lookupService,
    required ShoppingHomeWidgetService homeWidgetService,
  }) : _reminderService = reminderService,
       _productCatalog = productCatalog,
       _historyStorage = historyStorage,
       _lookupService = lookupService,
       _homeWidgetService = homeWidgetService;

  final ShoppingListsStorage _storage;
  final ShoppingReminderService _reminderService;
  final ProductCatalogGateway _productCatalog;
  final PurchaseHistoryStorage _historyStorage;
  final ProductLookupService _lookupService;
  final ShoppingHomeWidgetService _homeWidgetService;

  final List<ShoppingListModel> _lists = <ShoppingListModel>[];
  final List<CompletedPurchase> _history = <CompletedPurchase>[];
  bool _isLoading = true;
  bool _loaded = false;
  bool _listSuggestionsDirty = true;
  List<String> _cachedListSuggestions = const <String>[];

  bool get isLoading => _isLoading;

  List<ShoppingListModel> get lists => List.unmodifiable(_lists);
  List<CompletedPurchase> get purchaseHistory => List.unmodifiable(_history);
  List<CatalogProduct> get catalogProducts => _productCatalog.allProducts();

  Map<DateTime, List<CompletedPurchase>> historyGroupedByMonth() {
    final groups = <DateTime, List<CompletedPurchase>>{};
    for (final entry in _history) {
      final key = DateTime(entry.closedAt.year, entry.closedAt.month);
      groups.putIfAbsent(key, () => <CompletedPurchase>[]).add(entry);
    }

    final orderedKeys = groups.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final ordered = <DateTime, List<CompletedPurchase>>{};
    for (final key in orderedKeys) {
      final entries = groups[key]!
        ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
      ordered[key] = List.unmodifiable(entries);
    }
    return Map.unmodifiable(ordered);
  }

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final loadedLists = await _storage.loadLists();
      final loadedHistory = await _historyStorage.loadHistory();
      _lists
        ..clear()
        ..addAll(loadedLists);
      _history
        ..clear()
        ..addAll(loadedHistory);
      _sortListsByUpdatedAt();
      _sortHistoryByClosedAt();
      await _productCatalog.load();
      await _productCatalog.ingestFromLists(_lists);
      await _reminderService.syncFromLists(_lists, reset: true);
      await _homeWidgetService.updateFromLists(_lists);
    } finally {
      _loaded = true;
      _isLoading = false;
      _invalidateListSuggestionCache();
      notifyListeners();
    }
  }

  ShoppingListModel? findById(String listId) {
    for (final list in _lists) {
      if (list.id == listId) {
        return list;
      }
    }
    return null;
  }

  Future<ShoppingListModel> createList({
    required String name,
    ShoppingListModel? basedOn,
  }) async {
    final trimmedName = name.trim();
    final now = DateTime.now();
    final source = basedOn;
    final copiedItems = source == null
        ? const <ShoppingItem>[]
        : source.items
              .map((item) => item.copyWith(id: uniqueId(), isPurchased: false))
              .toList(growable: false);
    final copiedPaymentBalances = source == null
        ? const <PaymentBalance>[]
        : source.paymentBalances
              .map((entry) => entry.copyWith(id: uniqueId()))
              .toList(growable: false);

    final created = ShoppingListModel(
      id: uniqueId(),
      name: trimmedName,
      createdAt: now,
      updatedAt: now,
      items: copiedItems,
      budget: source?.budget,
      reminder: null,
      paymentBalances: copiedPaymentBalances,
    );

    _lists.insert(0, created);
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _productCatalog.ingestFromLists([created]);
    return created;
  }

  Future<void> upsertList(ShoppingListModel list) async {
    final index = _lists.indexWhere((entry) => entry.id == list.id);
    if (index >= 0) {
      _lists[index] = list;
    } else {
      _lists.add(list);
    }
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _syncReminderForList(list);
    await _productCatalog.ingestFromLists([list]);
  }

  Future<ShoppingListModel?> finalizeList(
    String listId, {
    bool markPendingAsPurchased = false,
  }) async {
    final index = _lists.indexWhere((entry) => entry.id == listId);
    if (index < 0) {
      return null;
    }

    final source = _lists[index];
    if (source.isClosed) {
      return source.deepCopy();
    }
    final now = DateTime.now();
    final completedItems = source.items
        .map(
          (item) => markPendingAsPurchased && !item.isPurchased
              ? item.copyWith(isPurchased: true)
              : item.copyWith(),
        )
        .toList(growable: false);
    final completed = CompletedPurchase(
      id: uniqueId(),
      listId: source.id,
      listName: source.name,
      closedAt: now,
      items: completedItems,
      budget: source.budget,
      paymentBalances: source.paymentBalances
          .map((entry) => entry.copyWith())
          .toList(growable: false),
    );

    _history.add(completed);
    _trimHistory();
    _sortHistoryByClosedAt();

    final updatedList = source.copyWith(
      items: completedItems,
      isClosed: true,
      closedAt: now,
      updatedAt: now,
    );
    _lists[index] = updatedList;
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();

    await _persistAndNotify();
    await _syncReminderForList(updatedList);
    await _productCatalog.ingestFromLists([updatedList]);
    return updatedList.deepCopy();
  }

  Future<ShoppingListModel?> reopenList(String listId) async {
    final index = _lists.indexWhere((entry) => entry.id == listId);
    if (index < 0) {
      return null;
    }
    final source = _lists[index];
    if (!source.isClosed) {
      return source.deepCopy();
    }

    final updated = source.copyWith(
      isClosed: false,
      clearClosedAt: true,
      updatedAt: DateTime.now(),
    );
    _lists[index] = updated;
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _syncReminderForList(updated);
    return updated.deepCopy();
  }

  Future<void> deleteCompletedPurchase(String purchaseId) async {
    final before = _history.length;
    _history.removeWhere((entry) => entry.id == purchaseId);
    if (_history.length == before) {
      return;
    }
    await _persistAndNotify();
  }

  Future<void> clearPurchaseHistory() async {
    if (_history.isEmpty) {
      return;
    }
    _history.clear();
    await _persistAndNotify();
  }

  Future<void> deleteList(String listId) async {
    final before = _lists.length;
    _lists.removeWhere((entry) => entry.id == listId);
    final removed = _lists.length < before;
    if (!removed) {
      return;
    }
    _invalidateListSuggestionCache();
    await _reminderService.cancelForList(listId);
    await _persistAndNotify();
  }

  Future<void> deleteListsById(Set<String> listIds) async {
    if (listIds.isEmpty) {
      return;
    }
    _lists.removeWhere((entry) => listIds.contains(entry.id));
    _invalidateListSuggestionCache();

    for (final listId in listIds) {
      await _reminderService.cancelForList(listId);
    }
    await _persistAndNotify();
  }

  Future<void> clearAllLists() async {
    if (_lists.isEmpty) {
      return;
    }
    _lists.clear();
    _invalidateListSuggestionCache();
    await _reminderService.syncFromLists(
      const <ShoppingListModel>[],
      reset: true,
    );
    await _persistAndNotify();
  }

  Future<void> notifyBudgetNearLimit(
    ShoppingListModel list, {
    required double budgetUsageRatio,
  }) async {
    await _reminderService.notifyBudgetNearLimit(
      list,
      budgetUsageRatio: budgetUsageRatio,
    );
  }

  Future<void> notifySyncPending({
    required int pendingRecords,
    required bool hasNetworkConnection,
  }) async {
    await _reminderService.notifySyncPending(
      pendingRecords: pendingRecords,
      hasNetworkConnection: hasNetworkConnection,
    );
  }

  String exportBackupJson() {
    final payload = <String, dynamic>{
      'version': 3,
      'exportedAt': DateTime.now().toIso8601String(),
      'lists': _lists.map((list) => list.toJson()).toList(growable: false),
      'purchaseHistory': _history
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'catalog': _productCatalog
          .allProducts()
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
    return jsonEncode(payload);
  }

  List<ShoppingListModel>? tryParseBackup(String rawPayload) {
    try {
      return _decodeBackupLists(rawPayload);
    } catch (_) {
      return null;
    }
  }

  Future<BackupImportReport> importBackupJson(
    String rawPayload, {
    required bool replaceExisting,
  }) async {
    final decodedPayload = _decodeBackupPayload(rawPayload);
    final imported = decodedPayload.lists;
    final importedHistory = decodedPayload.history;
    final importedCatalog = decodedPayload.catalog;
    final normalized = _normalizeImportedLists(
      imported,
      existingIds: replaceExisting
          ? <String>{}
          : _lists.map((list) => list.id).toSet(),
    );
    final normalizedHistory = _normalizeImportedHistory(
      importedHistory,
      existingIds: replaceExisting
          ? <String>{}
          : _history.map((entry) => entry.id).toSet(),
    );

    if (replaceExisting) {
      _lists
        ..clear()
        ..addAll(normalized);
      _history
        ..clear()
        ..addAll(normalizedHistory);
    } else {
      _lists.addAll(normalized);
      _history.addAll(normalizedHistory);
    }

    if (replaceExisting) {
      await _productCatalog.replaceAllProducts(importedCatalog);
    } else if (importedCatalog.isNotEmpty) {
      final mergedCatalog = <CatalogProduct>[
        ..._productCatalog.allProducts(),
        ...importedCatalog,
      ];
      await _productCatalog.replaceAllProducts(mergedCatalog);
    }

    _trimHistory();
    _sortListsByUpdatedAt();
    _sortHistoryByClosedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _reminderService.syncFromLists(_lists, reset: true);
    await _productCatalog.ingestFromLists(normalized);

    return BackupImportReport(
      importedLists: normalized.length,
      replaced: replaceExisting,
    );
  }

  List<String> suggestProductNames({
    String query = '',
    String? currentListId,
    int limit = 12,
  }) {
    if (limit <= 0) {
      return const <String>[];
    }

    final normalizedQuery = normalizeQuery(query);
    _rebuildListSuggestionCacheIfNeeded();

    final blocked = <String>{};
    if (currentListId != null) {
      final currentList = findById(currentListId);
      if (currentList != null) {
        for (final item in currentList.items) {
          blocked.add(normalizeQuery(item.name));
        }
      }
    }

    final merged = <String>[];
    final seen = <String>{};

    bool pushName(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        return false;
      }
      final normalized = normalizeQuery(trimmed);
      if (normalized.isEmpty || blocked.contains(normalized)) {
        return false;
      }
      if (normalizedQuery.isNotEmpty && !normalized.contains(normalizedQuery)) {
        return false;
      }
      if (!seen.add(normalized)) {
        return false;
      }
      merged.add(trimmed);
      return merged.length >= limit;
    }

    final catalogSuggestions = _productCatalog.suggestNames(
      query: normalizedQuery,
      limit: max(limit * 2, 20),
    );
    for (final name in catalogSuggestions) {
      if (pushName(name)) {
        return List.unmodifiable(merged);
      }
    }

    for (final name in _cachedListSuggestions) {
      if (pushName(name)) {
        return List.unmodifiable(merged);
      }
    }

    return List.unmodifiable(merged);
  }

  Future<ProductLookupResult> lookupProductByBarcode(String rawBarcode) async {
    final barcode = sanitizeBarcode(rawBarcode);
    if (barcode == null) {
      return ProductLookupResult(
        source: ProductLookupSource.notFound,
        barcode: rawBarcode,
      );
    }

    ProductLookupResult? remoteResult;
    try {
      remoteResult = await _lookupService.lookupByBarcode(barcode);
    } catch (_) {
      remoteResult = null;
    }

    final localMatch = _productCatalog.findByBarcode(barcode);

    if (remoteResult != null && remoteResult.hasData) {
      final mergedRemoteResult = ProductLookupResult(
        source: remoteResult.source,
        barcode: barcode,
        name: remoteResult.name ?? localMatch?.name,
        category: remoteResult.category ?? localMatch?.category,
        unitPrice: remoteResult.unitPrice ?? localMatch?.unitPrice,
        priceHistory: remoteResult.priceHistory.isNotEmpty
            ? remoteResult.priceHistory
            : (localMatch?.priceHistory ?? const <PriceHistoryEntry>[]),
      );
      await _productCatalog.upsertFromLookupResult(mergedRemoteResult);
      return mergedRemoteResult;
    }

    if (localMatch != null) {
      return ProductLookupResult(
        source: ProductLookupSource.localCatalog,
        barcode: barcode,
        name: localMatch.name,
        category: localMatch.category,
        unitPrice: localMatch.unitPrice,
        priceHistory: localMatch.priceHistory,
      );
    }

    return ProductLookupResult(
      source: ProductLookupSource.notFound,
      barcode: barcode,
    );
  }

  Future<CatalogProduct?> lookupCatalogProductByName(String name) async {
    return _productCatalog.findByName(name);
  }

  Future<void> saveDraftToCatalog(ShoppingItemDraft draft) async {
    await _productCatalog.upsertFromDraft(draft);
    notifyListeners();
  }

  Future<void> replaceCatalogProducts(List<CatalogProduct> products) async {
    await _productCatalog.replaceAllProducts(products);
    notifyListeners();
  }

  void _sortListsByUpdatedAt() {
    _lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  void _sortHistoryByClosedAt() {
    _history.sort((a, b) => b.closedAt.compareTo(a.closedAt));
  }

  void _trimHistory() {
    const maxHistoryEntries = 600;
    if (_history.length <= maxHistoryEntries) {
      return;
    }
    _history
      ..sort((a, b) => b.closedAt.compareTo(a.closedAt))
      ..removeRange(maxHistoryEntries, _history.length);
  }

  void _invalidateListSuggestionCache() {
    _listSuggestionsDirty = true;
  }

  void _rebuildListSuggestionCacheIfNeeded() {
    if (!_listSuggestionsDirty) {
      return;
    }

    final stats = <String, _SuggestionStats>{};
    for (final list in _lists) {
      for (final item in list.items) {
        final normalized = normalizeQuery(item.name);
        if (normalized.isEmpty) {
          continue;
        }
        final existing = stats[normalized];
        if (existing == null) {
          stats[normalized] = _SuggestionStats(
            label: item.name.trim(),
            usageCount: 1,
            lastSeenAt: list.updatedAt,
          );
          continue;
        }
        stats[normalized] = existing.copyWith(
          usageCount: existing.usageCount + 1,
          lastSeenAt: list.updatedAt.isAfter(existing.lastSeenAt)
              ? list.updatedAt
              : existing.lastSeenAt,
        );
      }
    }

    final values = stats.values.toList(growable: false)
      ..sort((a, b) {
        final byCount = b.usageCount.compareTo(a.usageCount);
        if (byCount != 0) {
          return byCount;
        }
        return b.lastSeenAt.compareTo(a.lastSeenAt);
      });

    _cachedListSuggestions = List.unmodifiable(
      values.map((entry) => entry.label).toList(growable: false),
    );
    _listSuggestionsDirty = false;
  }

  List<ShoppingListModel> _decodeBackupLists(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is List) {
      return _parseLists(decoded);
    }
    if (decoded is Map<String, dynamic>) {
      final rawLists = decoded['lists'];
      if (rawLists is List) {
        return _parseLists(rawLists);
      }
    }
    throw const FormatException('Formato de backup invalido');
  }

  _DecodedBackupPayload _decodeBackupPayload(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is List) {
      return _DecodedBackupPayload(
        lists: _parseLists(decoded),
        history: const <CompletedPurchase>[],
        catalog: const <CatalogProduct>[],
      );
    }
    if (decoded is Map<String, dynamic>) {
      final rawLists = decoded['lists'];
      if (rawLists is! List) {
        throw const FormatException('Formato de backup invalido');
      }
      final rawHistory = decoded['purchaseHistory'];
      final rawCatalog = decoded['catalog'];
      return _DecodedBackupPayload(
        lists: _parseLists(rawLists),
        history: rawHistory is List ? _parseHistory(rawHistory) : const [],
        catalog: rawCatalog is List ? _parseCatalog(rawCatalog) : const [],
      );
    }
    throw const FormatException('Formato de backup invalido');
  }

  List<ShoppingListModel> _parseLists(List<dynamic> rawLists) {
    final parsed = <ShoppingListModel>[];
    for (final entry in rawLists) {
      if (entry is Map) {
        parsed.add(
          ShoppingListModel.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return parsed;
  }

  List<CompletedPurchase> _parseHistory(List<dynamic> rawHistory) {
    final parsed = <CompletedPurchase>[];
    for (final entry in rawHistory) {
      if (entry is Map) {
        parsed.add(
          CompletedPurchase.fromJson(Map<String, dynamic>.from(entry)),
        );
      }
    }
    return parsed;
  }

  List<CatalogProduct> _parseCatalog(List<dynamic> rawCatalog) {
    final parsed = <CatalogProduct>[];
    for (final entry in rawCatalog) {
      if (entry is Map) {
        parsed.add(CatalogProduct.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return parsed;
  }

  List<ShoppingListModel> _normalizeImportedLists(
    List<ShoppingListModel> imported, {
    required Set<String> existingIds,
  }) {
    final listIds = {...existingIds};
    final normalizedLists = <ShoppingListModel>[];

    for (final source in imported) {
      var listId = source.id;
      if (listIds.contains(listId)) {
        listId = uniqueId();
      }
      listIds.add(listId);

      final itemIds = <String>{};
      final normalizedItems = source.items
          .map((item) {
            var itemId = item.id;
            if (itemIds.contains(itemId)) {
              itemId = uniqueId();
            }
            itemIds.add(itemId);
            return item.copyWith(id: itemId);
          })
          .toList(growable: false);

      normalizedLists.add(
        source.copyWith(
          id: listId,
          updatedAt: DateTime.now(),
          items: normalizedItems,
        ),
      );
    }

    return normalizedLists;
  }

  List<CompletedPurchase> _normalizeImportedHistory(
    List<CompletedPurchase> imported, {
    required Set<String> existingIds,
  }) {
    final ids = {...existingIds};
    final normalized = <CompletedPurchase>[];

    for (final source in imported) {
      var id = source.id;
      if (ids.contains(id)) {
        id = uniqueId();
      }
      ids.add(id);
      normalized.add(
        source.copyWith(
          id: id,
          items: source.items
              .map((item) => item.copyWith(id: uniqueId()))
              .toList(growable: false),
        ),
      );
    }

    return normalized;
  }

  Future<void> _syncReminderForList(ShoppingListModel list) async {
    if (list.isClosed || list.reminder == null) {
      await _reminderService.cancelForList(list.id);
      return;
    }
    await _reminderService.scheduleForList(list);
  }

  Future<void> _persistAndNotify() async {
    await _storage.saveLists(_lists);
    await _historyStorage.saveHistory(_history);
    try {
      await _homeWidgetService.updateFromLists(_lists);
    } catch (_) {
      // Widget updates are optional and should not block the main flow.
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _productCatalog.dispose();
    super.dispose();
  }
}

class _SuggestionStats {
  const _SuggestionStats({
    required this.label,
    required this.usageCount,
    required this.lastSeenAt,
  });

  final String label;
  final int usageCount;
  final DateTime lastSeenAt;

  _SuggestionStats copyWith({
    String? label,
    int? usageCount,
    DateTime? lastSeenAt,
  }) {
    return _SuggestionStats(
      label: label ?? this.label,
      usageCount: usageCount ?? this.usageCount,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class _DecodedBackupPayload {
  const _DecodedBackupPayload({
    required this.lists,
    required this.history,
    required this.catalog,
  });

  final List<ShoppingListModel> lists;
  final List<CompletedPurchase> history;
  final List<CatalogProduct> catalog;
}
