import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

import '../domain/classifications.dart';
import '../domain/pantry.dart';
import 'fiscal_receipt_import.dart';
import 'pantry_inventory_policy.dart';
import 'ports.dart';

class ShoppingListsStore extends ChangeNotifier {
  ShoppingListsStore(
    this._storage, {
    required ShoppingReminderService reminderService,
    required ProductCatalogGateway productCatalog,
    required PurchaseHistoryStorage historyStorage,
    PantryStorage? pantryStorage,
    required ProductLookupService lookupService,
    required ShoppingHomeWidgetService homeWidgetService,
    SharedCatalogImportPreferences? sharedCatalogImportPreferences,
  }) : _reminderService = reminderService,
       _productCatalog = productCatalog,
       _historyStorage = historyStorage,
       _pantryStorage = pantryStorage ?? _InMemoryPantryStorage(),
       _lookupService = lookupService,
       _homeWidgetService = homeWidgetService,
       _sharedCatalogImportPreferences =
           sharedCatalogImportPreferences ??
           _InMemorySharedCatalogImportPreferences();

  final ShoppingListsStorage _storage;
  final ShoppingReminderService _reminderService;
  final ProductCatalogGateway _productCatalog;
  final PurchaseHistoryStorage _historyStorage;
  final PantryStorage _pantryStorage;
  final ProductLookupService _lookupService;
  final ShoppingHomeWidgetService _homeWidgetService;
  final SharedCatalogImportPreferences _sharedCatalogImportPreferences;

  final List<ShoppingListModel> _lists = <ShoppingListModel>[];
  final List<CompletedPurchase> _history = <CompletedPurchase>[];
  final List<PantryItem> _pantry = <PantryItem>[];
  static const PantryInventoryPolicy _pantryPolicy = PantryInventoryPolicy();
  final Set<String> _sharedCatalogImportListIds = <String>{};
  bool _isLoading = true;
  bool _loaded = false;
  bool _autoImportOwnedSharedCatalogs = true;
  bool _autoImportAllSharedCatalogs = false;
  bool _listSuggestionsDirty = true;
  List<String> _cachedListSuggestions = const <String>[];

  bool get isLoading => _isLoading;

  List<ShoppingListModel> get lists => List.unmodifiable(_lists);
  List<ShoppingListModel> get listsByCreatedAt {
    return List<ShoppingListModel>.unmodifiable(
      List<ShoppingListModel>.of(_lists)..sort(_compareListsByCreatedAtDesc),
    );
  }

  List<CompletedPurchase> get purchaseHistory => List.unmodifiable(_history);
  List<CatalogProduct> get catalogProducts => _productCatalog.allProducts();
  List<PantryItem> get pantryItems => List.unmodifiable(_pantry);
  int get pantryNeedsRestockCount =>
      _pantry.where((item) => item.needsRestock).length;

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
      final loadedPantry = await _pantryStorage.loadItems();
      _lists
        ..clear()
        ..addAll(loadedLists);
      _history
        ..clear()
        ..addAll(loadedHistory);
      _pantry
        ..clear()
        ..addAll(loadedPantry);
      _sortListsByUpdatedAt();
      _sortHistoryByClosedAt();
      _sortPantry();
      await _productCatalog.load();
      _autoImportOwnedSharedCatalogs = await _sharedCatalogImportPreferences
          .loadAutoImportOwnedSharedLists();
      _autoImportAllSharedCatalogs = await _sharedCatalogImportPreferences
          .loadAutoImportAllSharedLists();
      _sharedCatalogImportListIds
        ..clear()
        ..addAll(
          await _sharedCatalogImportPreferences.loadEnabledSharedListIds(),
        );
      await _productCatalog.ingestFromLists(_lists);
      await _reminderService.syncFromLists(_lists, reset: true);
      await _homeWidgetService.updateSnapshot(
        lists: _lists,
        pantryItems: _pantry,
      );
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

  Future<ShoppingListModel> createListFromDrafts({
    required String name,
    required List<ShoppingItemDraft> drafts,
  }) async {
    final trimmedName = name.trim();
    final now = DateTime.now();
    final created = ShoppingListModel(
      id: uniqueId(),
      name: trimmedName,
      createdAt: now,
      updatedAt: now,
      items: drafts
          .where((draft) => draft.name.trim().isNotEmpty)
          .map(
            (draft) => ShoppingItem(
              id: uniqueId(),
              name: draft.name.trim(),
              quantity: max(1, draft.quantity),
              unitPrice: max(0, draft.unitPrice),
              category: draft.category,
              barcode: draft.barcode,
              priceHistory: draft.unitPrice > 0
                  ? <PriceHistoryEntry>[
                      PriceHistoryEntry(
                        price: draft.unitPrice,
                        recordedAt: now,
                      ),
                    ]
                  : const <PriceHistoryEntry>[],
            ),
          )
          .toList(growable: false),
    );

    _lists.insert(0, created);
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _productCatalog.ingestFromLists([created]);
    return created;
  }

  Future<void> upsertList(
    ShoppingListModel list, {
    bool ingestCatalog = true,
  }) async {
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
    if (ingestCatalog) {
      await _productCatalog.ingestFromLists([list]);
    }
  }

  Future<PantryItem> addCatalogProductToPantry(
    CatalogProduct product, {
    PantryStockStatus status = PantryStockStatus.inStock,
  }) async {
    final updated = _pantryPolicy.addCatalogProduct(
      current: _pantry,
      product: product,
      status: status,
      updatedAt: DateTime.now(),
      createId: uniqueId,
    );
    _pantry
      ..clear()
      ..addAll(updated);
    await _persistAndNotify();
    return _pantry.firstWhere(
      (item) => item.catalogProductId == product.id,
      orElse: () => _pantry.firstWhere(
        (item) => normalizeQuery(item.name) == normalizeQuery(product.name),
      ),
    );
  }

  Future<void> setPantryStatus(
    String pantryItemId,
    PantryStockStatus status,
  ) async {
    final index = _pantry.indexWhere((item) => item.id == pantryItemId);
    if (index < 0 || _pantry[index].status == status) {
      return;
    }
    _pantry[index] = _pantry[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    _sortPantry();
    await _persistAndNotify();
  }

  Future<void> removePantryItem(String pantryItemId) async {
    final before = _pantry.length;
    _pantry.removeWhere((item) => item.id == pantryItemId);
    if (_pantry.length == before) {
      return;
    }
    await _persistAndNotify();
  }

  Future<PantryListAddResult?> addPantryItemToList({
    required String pantryItemId,
    required String listId,
  }) async {
    final pantryItem = _pantry
        .where((item) => item.id == pantryItemId)
        .firstOrNull;
    final listIndex = _lists.indexWhere(
      (list) => list.id == listId && !list.isClosed,
    );
    if (pantryItem == null || listIndex < 0) {
      return null;
    }

    final source = _lists[listIndex];
    final draft = _pantryPolicy.toShoppingDraft(pantryItem);
    final barcode = sanitizeBarcode(draft.barcode);
    final normalizedName = normalizeQuery(draft.name);
    var merged = false;
    final items = source.items.map((item) => item.copyWith()).toList();
    final existingIndex = items.indexWhere(
      (item) =>
          (barcode != null && sanitizeBarcode(item.barcode) == barcode) ||
          normalizeQuery(item.name) == normalizedName,
    );
    final now = DateTime.now();
    if (existingIndex >= 0) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + draft.quantity,
        unitPrice: existing.unitPrice > 0
            ? existing.unitPrice
            : draft.unitPrice,
        barcode: existing.barcode ?? draft.barcode,
        category: existing.category == ShoppingCategory.other
            ? draft.category
            : existing.category,
      );
      merged = true;
    } else {
      items.add(
        ShoppingItem(
          id: uniqueId(),
          name: draft.name,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          barcode: draft.barcode,
          category: draft.category,
          priceHistory: draft.unitPrice > 0
              ? <PriceHistoryEntry>[
                  PriceHistoryEntry(price: draft.unitPrice, recordedAt: now),
                ]
              : const <PriceHistoryEntry>[],
        ),
      );
    }

    final updated = source.copyWith(items: items, updatedAt: now);
    _lists[listIndex] = updated;
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();
    await _persistAndNotify();
    await _productCatalog.ingestFromLists([updated]);
    return PantryListAddResult(list: updated.deepCopy(), merged: merged);
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
    _replenishPantryFromCompletedItems(completedItems, purchasedAt: now);
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();

    await _persistAndNotify();
    await _syncReminderForList(updatedList);
    await _productCatalog.ingestFromLists([updatedList]);
    return updatedList.deepCopy();
  }

  Future<FiscalReceiptImportTransaction?> applyFiscalReceiptReview(
    String listId,
    FiscalReceiptReviewSubmission submission,
  ) async {
    final index = _lists.indexWhere((entry) => entry.id == listId);
    if (index < 0) {
      return null;
    }

    final source = _lists[index];
    final beforeList = source.deepCopy();
    final catalogBefore = _productCatalog.allProducts();
    final historyBefore = _copyPurchaseHistory(_history);
    final pantryBefore = _copyPantry(_pantry);
    final now = DateTime.now();
    final plan = const FiscalReceiptImportPlanner().createPlan(
      source: source,
      submission: submission,
      recordedAt: now,
      createId: uniqueId,
    );
    final completedPurchaseId = submission.finalizePurchase ? uniqueId() : null;

    _lists[index] = plan.updatedList;
    if (completedPurchaseId != null) {
      _history.add(
        CompletedPurchase(
          id: completedPurchaseId,
          listId: plan.updatedList.id,
          listName: plan.updatedList.name,
          closedAt: now,
          items: plan.updatedList.items
              .map((item) => item.copyWith())
              .toList(growable: false),
          budget: plan.updatedList.budget,
          paymentBalances: plan.updatedList.paymentBalances
              .map((entry) => entry.copyWith())
              .toList(growable: false),
        ),
      );
      _trimHistory();
      _sortHistoryByClosedAt();
      _replenishPantryFromCompletedItems(
        plan.updatedList.items,
        purchasedAt: now,
      );
    }
    _sortListsByUpdatedAt();
    _invalidateListSuggestionCache();

    try {
      await _persistAndNotify();
      await _syncReminderForList(plan.updatedList);
      for (final draft in plan.appliedDrafts) {
        await _productCatalog.upsertFromDraft(draft);
      }
      notifyListeners();
    } catch (_) {
      await _restoreFiscalReceiptState(
        list: beforeList,
        catalog: catalogBefore,
        history: historyBefore,
        pantry: pantryBefore,
      );
      rethrow;
    }

    return FiscalReceiptImportTransaction(
      beforeList: beforeList,
      appliedList: plan.updatedList.deepCopy(),
      catalogBefore: catalogBefore,
      historyBefore: historyBefore,
      pantryBefore: pantryBefore,
      addedCount: plan.addedCount,
      updatedCount: plan.updatedCount,
      completedPurchaseId: completedPurchaseId,
    );
  }

  Future<ShoppingListModel?> undoFiscalReceiptImport(
    FiscalReceiptImportTransaction transaction,
  ) async {
    final index = _lists.indexWhere(
      (entry) => entry.id == transaction.appliedList.id,
    );
    if (index < 0) {
      return null;
    }
    final current = _lists[index];
    if (current.updatedAt != transaction.appliedList.updatedAt ||
        current.isClosed != transaction.appliedList.isClosed) {
      throw StateError(
        'A lista mudou depois da importação e não pode ser restaurada.',
      );
    }

    final currentList = current.deepCopy();
    final currentCatalog = _productCatalog.allProducts();
    final currentHistory = _copyPurchaseHistory(_history);
    final currentPantry = _copyPantry(_pantry);

    _lists[index] = transaction.beforeList.deepCopy();
    _history
      ..clear()
      ..addAll(_copyPurchaseHistory(transaction.historyBefore));
    _pantry
      ..clear()
      ..addAll(_copyPantry(transaction.pantryBefore));
    _sortListsByUpdatedAt();
    _sortHistoryByClosedAt();
    _invalidateListSuggestionCache();

    try {
      await _productCatalog.replaceAllProducts(transaction.catalogBefore);
      await _persistAndNotify();
      await _syncReminderForList(transaction.beforeList);
    } catch (_) {
      _lists[index] = currentList;
      _history
        ..clear()
        ..addAll(currentHistory);
      _pantry
        ..clear()
        ..addAll(currentPantry);
      await _productCatalog.replaceAllProducts(currentCatalog);
      await _persistAndNotify();
      await _syncReminderForList(currentList);
      rethrow;
    }
    return transaction.beforeList.deepCopy();
  }

  Future<void> _restoreFiscalReceiptState({
    required ShoppingListModel list,
    required List<CatalogProduct> catalog,
    required List<CompletedPurchase> history,
    required List<PantryItem> pantry,
  }) async {
    final index = _lists.indexWhere((entry) => entry.id == list.id);
    if (index >= 0) {
      _lists[index] = list.deepCopy();
    }
    _history
      ..clear()
      ..addAll(_copyPurchaseHistory(history));
    _pantry
      ..clear()
      ..addAll(_copyPantry(pantry));
    _sortListsByUpdatedAt();
    _sortHistoryByClosedAt();
    _invalidateListSuggestionCache();
    await _productCatalog.replaceAllProducts(catalog);
    await _persistAndNotify();
    await _syncReminderForList(list);
  }

  List<CompletedPurchase> _copyPurchaseHistory(
    Iterable<CompletedPurchase> source,
  ) {
    return source
        .map(
          (entry) => entry.copyWith(
            items: entry.items
                .map((item) => item.copyWith())
                .toList(growable: false),
            paymentBalances: entry.paymentBalances
                .map((balance) => balance.copyWith())
                .toList(growable: false),
          ),
        )
        .toList(growable: false);
  }

  List<PantryItem> _copyPantry(Iterable<PantryItem> source) {
    return source.map((item) => item.copyWith()).toList(growable: false);
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

  Future<void> clearAllLocalData() async {
    _lists.clear();
    _history.clear();
    _pantry.clear();
    _invalidateListSuggestionCache();
    await _productCatalog.replaceAllProducts(const <CatalogProduct>[]);
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

  Future<void> syncExternalReminder(ShoppingListModel list) async {
    await _reminderService.scheduleForList(list);
  }

  String exportBackupJson() {
    final payload = <String, dynamic>{
      'version': 4,
      'exportedAt': DateTime.now().toIso8601String(),
      'lists': _lists.map((list) => list.toJson()).toList(growable: false),
      'purchaseHistory': _history
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'catalog': _productCatalog
          .allProducts()
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'pantry': _pantry.map((entry) => entry.toJson()).toList(growable: false),
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
    final importedPantry = decodedPayload.pantry;
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
    final normalizedPantry = _normalizeImportedPantry(
      importedPantry,
      existingIds: replaceExisting
          ? <String>{}
          : _pantry.map((entry) => entry.id).toSet(),
    );

    if (replaceExisting) {
      _lists
        ..clear()
        ..addAll(normalized);
      _history
        ..clear()
        ..addAll(normalizedHistory);
      _pantry
        ..clear()
        ..addAll(normalizedPantry);
    } else {
      _lists.addAll(normalized);
      _history.addAll(normalizedHistory);
      _pantry.addAll(normalizedPantry);
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
    _sortPantry();
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

  bool get autoImportOwnedSharedCatalogs => _autoImportOwnedSharedCatalogs;
  bool get autoImportAllSharedCatalogs => _autoImportAllSharedCatalogs;
  Set<String> get sharedCatalogImportListIds =>
      Set.unmodifiable(_sharedCatalogImportListIds);

  bool isSharedCatalogImportEnabled(String sharedListId) {
    final trimmedId = sharedListId.trim();
    if (trimmedId.isEmpty) {
      return false;
    }
    return _autoImportAllSharedCatalogs ||
        _sharedCatalogImportListIds.contains(trimmedId);
  }

  Future<void> setSharedCatalogImportEnabled(
    String sharedListId, {
    required bool enabled,
    bool enableForFutureLists = false,
  }) async {
    final trimmedId = sharedListId.trim();
    if (trimmedId.isEmpty) {
      return;
    }
    if (enabled) {
      _sharedCatalogImportListIds.add(trimmedId);
    } else {
      _sharedCatalogImportListIds.remove(trimmedId);
    }
    if (enableForFutureLists) {
      _autoImportAllSharedCatalogs = enabled;
      await _sharedCatalogImportPreferences.saveAutoImportAllSharedLists(
        enabled,
      );
    }
    await _sharedCatalogImportPreferences.saveEnabledSharedListIds(
      _sharedCatalogImportListIds,
    );
    notifyListeners();
  }

  Future<void> setAutoImportOwnedSharedCatalogs(bool enabled) async {
    if (_autoImportOwnedSharedCatalogs == enabled) {
      return;
    }
    _autoImportOwnedSharedCatalogs = enabled;
    await _sharedCatalogImportPreferences.saveAutoImportOwnedSharedLists(
      enabled,
    );
    notifyListeners();
  }

  Future<void> applySharedCatalogImportSettings({
    required bool autoImportOwnedSharedCatalogs,
    required bool autoImportAllSharedCatalogs,
    required Set<String> enabledSharedListIds,
  }) async {
    _autoImportOwnedSharedCatalogs = autoImportOwnedSharedCatalogs;
    _autoImportAllSharedCatalogs = autoImportAllSharedCatalogs;
    _sharedCatalogImportListIds
      ..clear()
      ..addAll(
        enabledSharedListIds
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty),
      );
    await _sharedCatalogImportPreferences.saveAutoImportOwnedSharedLists(
      _autoImportOwnedSharedCatalogs,
    );
    await _sharedCatalogImportPreferences.saveAutoImportAllSharedLists(
      _autoImportAllSharedCatalogs,
    );
    await _sharedCatalogImportPreferences.saveEnabledSharedListIds(
      _sharedCatalogImportListIds,
    );
    notifyListeners();
  }

  Future<SharedCatalogImportResult> importSharedListItemsToCatalog(
    ShoppingListModel list,
  ) async {
    final seenNames = _productCatalog
        .allProducts()
        .map((product) => normalizeQuery(product.name))
        .where((name) => name.isNotEmpty)
        .toSet();
    final seenBarcodes = _productCatalog
        .allProducts()
        .map((product) => sanitizeBarcode(product.barcode))
        .whereType<String>()
        .toSet();

    var createdCount = 0;
    var mergedCount = 0;
    var skippedCount = 0;
    for (final item in list.items) {
      final normalizedName = normalizeQuery(item.name);
      if (normalizedName.isEmpty) {
        skippedCount++;
        continue;
      }
      final barcode = sanitizeBarcode(item.barcode);
      final hasMatch =
          (barcode != null && seenBarcodes.contains(barcode)) ||
          seenNames.contains(normalizedName);
      if (hasMatch) {
        mergedCount++;
      } else {
        createdCount++;
      }
      seenNames.add(normalizedName);
      if (barcode != null) {
        seenBarcodes.add(barcode);
      }
    }

    if (createdCount + mergedCount > 0) {
      await _productCatalog.ingestFromLists([list]);
      notifyListeners();
    }
    return SharedCatalogImportResult(
      createdCount: createdCount,
      mergedCount: mergedCount,
      skippedCount: skippedCount,
    );
  }

  Future<void> replaceCatalogProducts(List<CatalogProduct> products) async {
    await _productCatalog.replaceAllProducts(products);
    notifyListeners();
  }

  List<ReplenishmentSuggestion> suggestReplenishmentItems({
    DateTime? referenceDate,
    int limit = 20,
  }) {
    if (limit <= 0) {
      return const <ReplenishmentSuggestion>[];
    }

    final resolvedReferenceDate = referenceDate ?? DateTime.now();
    final targetMonth = DateTime(
      resolvedReferenceDate.year,
      resolvedReferenceDate.month - 1,
    );
    final stats = <String, _ReplenishmentSuggestionStats>{};

    for (final purchase in _history) {
      for (final item in _itemsRelevantForReplenishment(purchase)) {
        final normalizedName = normalizeQuery(item.name);
        if (normalizedName.isEmpty) {
          continue;
        }

        final catalogMatch =
            _productCatalog.findByBarcode(item.barcode) ??
            _productCatalog.findByName(item.name);
        final resolvedPrice = _resolveReplenishmentUnitPrice(
          item: item,
          catalogMatch: catalogMatch,
        );
        final resolvedCategory = item.category != ShoppingCategory.other
            ? item.category
            : (catalogMatch?.category ?? ShoppingCategory.other);
        final existing = stats[normalizedName];
        if (existing == null) {
          stats[normalizedName] = _ReplenishmentSuggestionStats(
            name: item.name.trim(),
            category: resolvedCategory,
            quantity: max(1, item.quantity),
            unitPrice: resolvedPrice,
            lastPurchasedAt: purchase.closedAt,
            occurrences: 1,
            appearedInTargetMonth:
                purchase.closedAt.year == targetMonth.year &&
                purchase.closedAt.month == targetMonth.month,
            usageCount: catalogMatch?.usageCount ?? 0,
            barcode: item.barcode ?? catalogMatch?.barcode,
          );
          continue;
        }

        stats[normalizedName] = existing.copyWith(
          name: _preferredSuggestionLabel(existing.name, item.name),
          category: existing.category == ShoppingCategory.other
              ? resolvedCategory
              : existing.category,
          quantity: existing.quantity + max(1, item.quantity),
          unitPrice:
              purchase.closedAt.isAfter(existing.lastPurchasedAt) &&
                  resolvedPrice > 0
              ? resolvedPrice
              : existing.unitPrice,
          lastPurchasedAt: purchase.closedAt.isAfter(existing.lastPurchasedAt)
              ? purchase.closedAt
              : existing.lastPurchasedAt,
          occurrences: existing.occurrences + 1,
          appearedInTargetMonth:
              existing.appearedInTargetMonth ||
              (purchase.closedAt.year == targetMonth.year &&
                  purchase.closedAt.month == targetMonth.month),
          usageCount: max(existing.usageCount, catalogMatch?.usageCount ?? 0),
          barcode: existing.barcode ?? item.barcode ?? catalogMatch?.barcode,
        );
      }
    }

    if (stats.isNotEmpty) {
      final suggestions =
          stats.values
              .where(
                (entry) => entry.occurrences > 1 || entry.appearedInTargetMonth,
              )
              .map(
                (entry) => ReplenishmentSuggestion(
                  name: entry.name,
                  category: entry.category,
                  suggestedQuantity: entry.averageQuantity,
                  suggestedUnitPrice: entry.unitPrice,
                  lastPurchasedAt: entry.lastPurchasedAt,
                  occurrences: entry.occurrences,
                  usageCount: entry.usageCount,
                  source: entry.occurrences > 1
                      ? ReplenishmentSuggestionSource.recurring
                      : ReplenishmentSuggestionSource.lastMonth,
                  barcode: entry.barcode,
                ),
              )
              .toList(growable: false)
            ..sort((a, b) {
              final byRecurring = _sourcePriority(
                a.source,
              ).compareTo(_sourcePriority(b.source));
              if (byRecurring != 0) {
                return byRecurring;
              }
              final byOccurrences = b.occurrences.compareTo(a.occurrences);
              if (byOccurrences != 0) {
                return byOccurrences;
              }
              final byDate = b.lastPurchasedAt.compareTo(a.lastPurchasedAt);
              if (byDate != 0) {
                return byDate;
              }
              final byUsage = b.usageCount.compareTo(a.usageCount);
              if (byUsage != 0) {
                return byUsage;
              }
              final byQuantity = b.suggestedQuantity.compareTo(
                a.suggestedQuantity,
              );
              if (byQuantity != 0) {
                return byQuantity;
              }
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
      if (suggestions.isNotEmpty) {
        return List.unmodifiable(
          suggestions.take(limit).toList(growable: false),
        );
      }
    }

    final fallback = _productCatalog.allProducts().toList(growable: false)
      ..sort((a, b) {
        final byUsage = b.usageCount.compareTo(a.usageCount);
        if (byUsage != 0) {
          return byUsage;
        }
        final byDate = b.updatedAt.compareTo(a.updatedAt);
        if (byDate != 0) {
          return byDate;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return List.unmodifiable(
      fallback
          .where((product) => product.name.trim().isNotEmpty)
          .take(limit)
          .map(
            (product) => ReplenishmentSuggestion(
              name: product.name.trim(),
              category: product.category,
              suggestedQuantity: 1,
              suggestedUnitPrice: product.unitPrice ?? 0,
              lastPurchasedAt: product.updatedAt,
              occurrences: max(1, product.usageCount),
              usageCount: product.usageCount,
              source: ReplenishmentSuggestionSource.catalogFallback,
              barcode: product.barcode,
            ),
          )
          .toList(growable: false),
    );
  }

  void _sortListsByUpdatedAt() {
    _lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  int _compareListsByCreatedAtDesc(
    ShoppingListModel left,
    ShoppingListModel right,
  ) {
    final byCreatedAt = right.createdAt.compareTo(left.createdAt);
    if (byCreatedAt != 0) {
      return byCreatedAt;
    }
    return right.updatedAt.compareTo(left.updatedAt);
  }

  void _sortHistoryByClosedAt() {
    _history.sort((a, b) => b.closedAt.compareTo(a.closedAt));
  }

  void _sortPantry() {
    _pantry.sort((a, b) {
      final byStatus = b.status.index.compareTo(a.status.index);
      if (byStatus != 0) {
        return byStatus;
      }
      return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
    });
  }

  void _replenishPantryFromCompletedItems(
    Iterable<ShoppingItem> completedItems, {
    required DateTime purchasedAt,
  }) {
    final copiedItems = List<ShoppingItem>.from(completedItems);
    final purchased = copiedItems.where((item) => item.isPurchased).toList();
    final relevant = purchased.isNotEmpty ? purchased : copiedItems;
    final updated = _pantryPolicy.replenishFromPurchase(
      current: _pantry,
      purchasedItems: relevant,
      catalogProducts: _productCatalog.allProducts(),
      purchasedAt: purchasedAt,
      createId: uniqueId,
    );
    _pantry
      ..clear()
      ..addAll(updated);
    _sortPantry();
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

  Iterable<ShoppingItem> _itemsRelevantForReplenishment(
    CompletedPurchase purchase,
  ) {
    final purchasedItems = purchase.items.where((item) => item.isPurchased);
    if (purchasedItems.isNotEmpty) {
      return purchasedItems;
    }
    return purchase.items;
  }

  double _resolveReplenishmentUnitPrice({
    required ShoppingItem item,
    required CatalogProduct? catalogMatch,
  }) {
    final catalogHistory =
        catalogMatch?.priceHistory ?? const <PriceHistoryEntry>[];
    if (catalogHistory.isNotEmpty) {
      return max(0, catalogHistory.last.price);
    }
    final itemHistory = item.priceHistory;
    if (itemHistory.isNotEmpty) {
      return max(0, itemHistory.last.price);
    }
    return max(
      0,
      item.unitPrice > 0 ? item.unitPrice : (catalogMatch?.unitPrice ?? 0),
    );
  }

  String _preferredSuggestionLabel(String current, String incoming) {
    final trimmedCurrent = current.trim();
    final trimmedIncoming = incoming.trim();
    if (trimmedCurrent.isEmpty) {
      return trimmedIncoming;
    }
    if (trimmedIncoming.isEmpty) {
      return trimmedCurrent;
    }
    return trimmedIncoming.length > trimmedCurrent.length
        ? trimmedIncoming
        : trimmedCurrent;
  }

  int _sourcePriority(ReplenishmentSuggestionSource source) {
    switch (source) {
      case ReplenishmentSuggestionSource.recurring:
        return 0;
      case ReplenishmentSuggestionSource.lastMonth:
        return 1;
      case ReplenishmentSuggestionSource.catalogFallback:
        return 2;
    }
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
    throw const FormatException('Formato de backup inválido');
  }

  _DecodedBackupPayload _decodeBackupPayload(String rawPayload) {
    final decoded = jsonDecode(rawPayload);
    if (decoded is List) {
      return _DecodedBackupPayload(
        lists: _parseLists(decoded),
        history: const <CompletedPurchase>[],
        catalog: const <CatalogProduct>[],
        pantry: const <PantryItem>[],
      );
    }
    if (decoded is Map<String, dynamic>) {
      final rawLists = decoded['lists'];
      if (rawLists is! List) {
        throw const FormatException('Formato de backup inválido');
      }
      final rawHistory = decoded['purchaseHistory'];
      final rawCatalog = decoded['catalog'];
      final rawPantry = decoded['pantry'];
      return _DecodedBackupPayload(
        lists: _parseLists(rawLists),
        history: rawHistory is List ? _parseHistory(rawHistory) : const [],
        catalog: rawCatalog is List ? _parseCatalog(rawCatalog) : const [],
        pantry: rawPantry is List ? _parsePantry(rawPantry) : const [],
      );
    }
    throw const FormatException('Formato de backup inválido');
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

  List<PantryItem> _parsePantry(List<dynamic> rawPantry) {
    return rawPantry
        .whereType<Map>()
        .map((entry) => PantryItem.fromJson(Map<String, dynamic>.from(entry)))
        .where((item) => item.name.trim().isNotEmpty)
        .toList(growable: false);
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

  List<PantryItem> _normalizeImportedPantry(
    List<PantryItem> imported, {
    required Set<String> existingIds,
  }) {
    final ids = {...existingIds};
    final normalized = <PantryItem>[];
    for (final source in imported) {
      var id = source.id;
      if (id.trim().isEmpty || ids.contains(id)) {
        id = uniqueId();
      }
      ids.add(id);
      normalized.add(source.copyWith(id: id));
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
    await _pantryStorage.saveItems(_pantry);
    try {
      await _homeWidgetService.updateSnapshot(
        lists: _lists,
        pantryItems: _pantry,
      );
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
    required this.pantry,
  });

  final List<ShoppingListModel> lists;
  final List<CompletedPurchase> history;
  final List<CatalogProduct> catalog;
  final List<PantryItem> pantry;
}

class PantryListAddResult {
  const PantryListAddResult({required this.list, required this.merged});

  final ShoppingListModel list;
  final bool merged;
}

class SharedCatalogImportResult {
  const SharedCatalogImportResult({
    required this.createdCount,
    required this.mergedCount,
    required this.skippedCount,
  });

  final int createdCount;
  final int mergedCount;
  final int skippedCount;

  int get changedCount => createdCount + mergedCount;
}

class _InMemorySharedCatalogImportPreferences
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

class _InMemoryPantryStorage implements PantryStorage {
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

class _ReplenishmentSuggestionStats {
  const _ReplenishmentSuggestionStats({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unitPrice,
    required this.lastPurchasedAt,
    required this.occurrences,
    required this.appearedInTargetMonth,
    required this.usageCount,
    this.barcode,
  });

  final String name;
  final ShoppingCategory category;
  final int quantity;
  final double unitPrice;
  final DateTime lastPurchasedAt;
  final int occurrences;
  final bool appearedInTargetMonth;
  final int usageCount;
  final String? barcode;

  int get averageQuantity => max(1, (quantity / occurrences).round());

  _ReplenishmentSuggestionStats copyWith({
    String? name,
    ShoppingCategory? category,
    int? quantity,
    double? unitPrice,
    DateTime? lastPurchasedAt,
    int? occurrences,
    bool? appearedInTargetMonth,
    int? usageCount,
    String? barcode,
  }) {
    return _ReplenishmentSuggestionStats(
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      lastPurchasedAt: lastPurchasedAt ?? this.lastPurchasedAt,
      occurrences: occurrences ?? this.occurrences,
      appearedInTargetMonth:
          appearedInTargetMonth ?? this.appearedInTargetMonth,
      usageCount: usageCount ?? this.usageCount,
      barcode: barcode ?? this.barcode,
    );
  }
}
