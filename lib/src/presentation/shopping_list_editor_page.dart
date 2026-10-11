import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/finance_integration.dart';
import '../application/finance_purchase_bridge.dart';
import '../application/ports.dart';
import '../application/fiscal_receipt_import.dart';
import '../application/shared_list_sync_policy.dart';
import '../application/store_and_services.dart';
import '../application/voice_shopping.dart';
import '../core/utils/format_utils.dart';
import '../data/finance_integration_dependencies.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'catalog_products_page.dart';
import 'dialogs_and_sheets.dart';
import 'dialogs/delete_item_dialog.dart';
import 'theme/editorial_workspace_theme.dart';
import 'market_mode_page.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor/shopping_list_editor_models.dart';
import 'shopping_list_editor/widgets/editor_chrome_widgets.dart';
import 'shopping_list_editor/widgets/list_editor_actions_sheet.dart';
import 'shopping_list_editor/widgets/item_actions_sheet.dart';
import 'shopping_list_editor/widgets/editor_empty_states.dart';
import 'shopping_list_editor/widgets/editor_item_card.dart';
import 'shopping_list_editor/widgets/editor_items_toolbar.dart';
import 'shopping_list_editor/widgets/editor_price_history_sheet.dart';
import 'shopping_list_editor/widgets/editor_editorial_summary.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class ShoppingListEditorPage extends StatefulWidget {
  const ShoppingListEditorPage({
    super.key,
    required this.store,
    required this.listId,
    this.sharedListsRepository,
    this.voiceRecognitionService,
    this.startVoiceCapture = false,
    this.startMarketMode = false,
    this.financeIntegrationRepository,
    this.initialSummaryExpanded,
  });

  final ShoppingListsStore store;
  final String listId;
  final SharedListsRepository? sharedListsRepository;
  final ShoppingVoiceRecognitionService? voiceRecognitionService;
  final bool startVoiceCapture;
  final bool startMarketMode;
  final FinanceIntegrationRepository? financeIntegrationRepository;
  final bool? initialSummaryExpanded;

  @override
  State<ShoppingListEditorPage> createState() => _ShoppingListEditorPageState();
}

class _ShoppingListEditorPageState extends State<ShoppingListEditorPage> {
  late ShoppingListModel _list;
  bool _notFound = false;
  ItemSortOption _sortOption = ItemSortOption.defaultOrder;
  late final TextEditingController _searchController;
  ShoppingCategory? _categoryFilter;
  bool _marketModeEnabled = false;
  String? _expandedItemId;
  EditorItemsVisibility _itemsVisibility = EditorItemsVisibility.pending;
  bool _didShowBudgetWarning = false;
  bool _didShowBudgetNearLimitWarning = false;
  SharedShoppingListSummary? _linkedSharedSummary;
  bool _checkedSharedLink = false;
  bool _redirectingToShared = false;
  bool _forceSharedView = false;
  bool _isSyncingToShared = false;
  StreamSubscription<SharedShoppingListSummary?>? _sharedListSub;
  StreamSubscription<List<SharedShoppingItem>>? _sharedItemsSub;
  SharedShoppingListSummary? _sharedLiveSummary;
  List<SharedShoppingItem>? _sharedLiveItems;
  DateTime? _lastSharedSyncAt;
  late final FinanceIntegrationRepository _financeIntegrationRepository;
  FinanceWorkspace? _financeWorkspace;
  String? _financeLoadError;
  Future<void>? _financeLoadFuture;

  String get _searchQuery => _searchController.text.trim();
  bool get _isSharedLocked => _linkedSharedSummary != null;
  bool get _isEditingLocked => _list.isClosed;
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _sortOption != ItemSortOption.defaultOrder ||
      _categoryFilter != null ||
      _marketModeEnabled ||
      _itemsVisibility != EditorItemsVisibility.pending;

  int get _pendingItemsCount =>
      _list.items.where((item) => !item.isPurchased).length;
  int get _purchasedItemsCount => _list.items.length - _pendingItemsCount;

  List<ShoppingItem> get _visibleItems {
    final normalizedQuery = normalizeQuery(_searchQuery);
    final sourceItems = [..._list.items];
    final filteredItems = sourceItems
        .where((item) {
          final matchesName = normalizedQuery.isEmpty
              ? true
              : normalizeQuery(item.name).contains(normalizedQuery);
          final matchesCategory = _categoryFilter == null
              ? true
              : item.category == _categoryFilter;
          final matchesVisibility = switch (_itemsVisibility) {
            EditorItemsVisibility.pending => !item.isPurchased,
            EditorItemsVisibility.all => true,
            EditorItemsVisibility.purchased => item.isPurchased,
          };
          return matchesName && matchesCategory && matchesVisibility;
        })
        .toList(growable: false);

    final originalIndexById = <String, int>{};
    for (var index = 0; index < _list.items.length; index++) {
      originalIndexById[_list.items[index].id] = index;
    }

    int fallback(ShoppingItem a, ShoppingItem b) {
      final left = originalIndexById[a.id] ?? 0;
      final right = originalIndexById[b.id] ?? 0;
      return left.compareTo(right);
    }

    filteredItems.sort((a, b) {
      if (_marketModeEnabled) {
        final byCategory = a.category.marketOrder.compareTo(
          b.category.marketOrder,
        );
        if (byCategory != 0) {
          return byCategory;
        }
        final byName = normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
        return byName != 0 ? byName : fallback(a, b);
      }

      switch (_sortOption) {
        case ItemSortOption.defaultOrder:
          return fallback(a, b);
        case ItemSortOption.nameAsc:
          final byName = normalizeQuery(
            a.name,
          ).compareTo(normalizeQuery(b.name));
          return byName != 0 ? byName : fallback(a, b);
        case ItemSortOption.nameDesc:
          final byName = normalizeQuery(
            b.name,
          ).compareTo(normalizeQuery(a.name));
          return byName != 0 ? byName : fallback(a, b);
        case ItemSortOption.valueAsc:
          final byValue = a.subtotal.compareTo(b.subtotal);
          return byValue != 0 ? byValue : fallback(a, b);
        case ItemSortOption.valueDesc:
          final byValue = b.subtotal.compareTo(a.subtotal);
          return byValue != 0 ? byValue : fallback(a, b);
      }
    });

    return filteredItems;
  }

  void _setItemsVisibility(EditorItemsVisibility visibility) {
    if (_itemsVisibility == visibility) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _itemsVisibility = visibility;
    });
  }

  bool _ensureEditable([String? message]) {
    if (_list.isClosed) {
      _showSnack(
        message ??
            'Esta lista está fechada. Reabra a lista para editar produtos.',
      );
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (widget.startMarketMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_openMarketShoppingMode());
      });
    }
    _financeIntegrationRepository =
        widget.financeIntegrationRepository ??
        createFinanceIntegrationRepository();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
    final fromStore = widget.store.findById(widget.listId);
    if (fromStore == null) {
      _notFound = true;
      _list = ShoppingListModel.empty(name: 'Lista removida');
      return;
    }
    _list = fromStore.deepCopy();
    _didShowBudgetWarning = _list.isOverBudget;
    _didShowBudgetNearLimitWarning = false;
    _resolveSharedLink();
    unawaited(_refreshFinanceCheckout());
    if (widget.startVoiceCapture && widget.voiceRecognitionService != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_openVoiceQuickAdd());
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    _sharedListSub?.cancel();
    _sharedItemsSub?.cancel();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _resolveSharedLink() async {
    if (_checkedSharedLink) {
      return;
    }
    _checkedSharedLink = true;
    final repository = widget.sharedListsRepository;
    if (repository == null) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }
    try {
      final shared = await repository.findSharedListBySource(
        ownerUid: uid,
        sourceLocalListId: _list.id,
      );
      if (!mounted || shared == null) {
        return;
      }
      setState(() {
        _linkedSharedSummary = shared;
      });
      _startSharedLiveSync(shared.id);
      _promptOpenSharedList(shared);
    } catch (error) {
      debugPrint(
        '[share_flow] resolveSharedLink failed kind=${error.runtimeType}',
      );
    }
  }

  void _startSharedLiveSync(String sharedListId) {
    final repository = widget.sharedListsRepository;
    if (repository == null) {
      return;
    }
    _sharedListSub?.cancel();
    _sharedItemsSub?.cancel();
    _sharedListSub = repository.watchSharedList(sharedListId).listen((summary) {
      _sharedLiveSummary = summary;
      _applySharedSnapshotToLocal();
    });
    _sharedItemsSub = repository.watchListItems(sharedListId).listen((items) {
      _sharedLiveItems = items;
      _applySharedSnapshotToLocal();
    });
  }

  void _applySharedSnapshotToLocal() {
    final summary = _sharedLiveSummary;
    final items = _sharedLiveItems;
    if (summary == null || items == null) {
      return;
    }
    final sourceLocalId = summary.sourceLocalListId?.trim() ?? '';
    final mirrorAction = resolveLinkedSharedSnapshotAction(
      sourceMatchesLocalList:
          sourceLocalId.isEmpty || sourceLocalId == _list.id,
      isSyncingToShared: _isSyncingToShared,
      localUpdatedAt: _list.updatedAt,
      sharedUpdatedAt: summary.updatedAt,
    );
    if (mirrorAction == SharedListMirrorAction.skip) {
      return;
    }
    final updated = ShoppingListModel(
      id: _list.id,
      name: summary.name,
      createdAt: _list.createdAt,
      updatedAt: summary.updatedAt,
      items: items
          .map((entry) => entry.toShoppingItem())
          .toList(growable: false),
      budget: summary.budget,
      reminder: summary.reminder,
      paymentBalances: summary.paymentBalances,
      isClosed: summary.isClosed,
      closedAt: summary.closedAt,
    );
    setState(() {
      _list = updated;
      _linkedSharedSummary = summary;
      _lastSharedSyncAt = DateTime.now();
    });
    unawaited(
      widget.store.upsertList(
        updated,
        ingestCatalog: widget.store.autoImportOwnedSharedCatalogs,
      ),
    );
  }

  void _promptOpenSharedList(SharedShoppingListSummary shared) {
    if (_redirectingToShared) {
      return;
    }
    _redirectingToShared = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      final shouldOpen = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Lista compartilhada detectada'),
          content: const Text(
            'Esta lista tem uma versão compartilhada. Para ver atualizações em '
            'tempo real, abra a lista compartilhada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Agora não'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abrir lista compartilhada'),
            ),
          ],
        ),
      );
      if (!mounted) {
        return;
      }
      if (shouldOpen == true) {
        _activateSharedView();
      } else {
        _redirectingToShared = false;
      }
    });
  }

  void _activateSharedView() {
    if (!mounted) {
      return;
    }
    setState(() {
      _forceSharedView = true;
    });
  }

  Future<void> _openSharedInviteSheetFromLocal() async {
    final repository = widget.sharedListsRepository;
    final shared = _linkedSharedSummary;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (repository == null || shared == null || uid.isEmpty) {
      return;
    }
    await showSharedInviteSheet(
      context: context,
      repository: repository,
      listId: shared.id,
      currentUid: uid,
      onOpenSharedList: _openLinkedSharedList,
    );
  }

  Future<void> _openLinkedSharedList() async {
    _activateSharedView();
  }

  Future<void> _syncLinkedSharedNow({bool showSnack = false}) async {
    final repository = widget.sharedListsRepository;
    final shared = _linkedSharedSummary;
    if (repository == null || shared == null) {
      if (showSnack) {
        _showSnack('Nenhuma lista compartilhada para sincronizar.');
      }
      return;
    }
    final sourceLocalId = shared.sourceLocalListId?.trim() ?? '';
    if (sourceLocalId.isNotEmpty && sourceLocalId != _list.id) {
      if (showSnack) {
        _showSnack('Esta lista não corresponde ao compartilhamento vinculado.');
      }
      return;
    }
    try {
      final latest = await repository.fetchSharedList(shared.id);
      if (latest == null) {
        if (showSnack) {
          _showSnack('Lista compartilhada não encontrada.');
        }
        return;
      }
      final items = await repository.fetchListItems(shared.id);
      final existing = widget.store.findById(_list.id);
      final mirrored = ShoppingListModel(
        id: _list.id,
        name: latest.name,
        createdAt: existing?.createdAt ?? _list.createdAt,
        updatedAt: latest.updatedAt,
        items: items
            .map((entry) => entry.toShoppingItem())
            .toList(growable: false),
        budget: latest.budget,
        reminder: latest.reminder,
        paymentBalances: latest.paymentBalances,
        isClosed: latest.isClosed,
        closedAt: latest.closedAt,
      );
      await widget.store.upsertList(
        mirrored,
        ingestCatalog: widget.store.autoImportOwnedSharedCatalogs,
      );
      if (mounted) {
        setState(() {
          _list = mirrored;
          _linkedSharedSummary = latest;
          _lastSharedSyncAt = DateTime.now();
        });
      }
      if (showSnack) {
        HapticFeedback.mediumImpact();
        _showSnack(
          'Listas compartilhadas sincronizadas.',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (showSnack) {
        _showSnack(
          'Não foi possível sincronizar. Verifique sua conexão e tente novamente.',
        );
      }
    }
  }

  Future<void> _syncLocalChangesToShared(
    ShoppingListModel updated, {
    bool showSnack = false,
    bool throwOnError = false,
  }) async {
    final repository = widget.sharedListsRepository;
    final shared = _linkedSharedSummary;
    if (repository == null || shared == null) {
      if (throwOnError) {
        throw StateError('Lista compartilhada indisponível.');
      }
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      if (throwOnError) {
        throw StateError('Entre na sua conta para sincronizar.');
      }
      return;
    }
    final sourceLocalId = shared.sourceLocalListId?.trim() ?? '';
    if (sourceLocalId.isNotEmpty && sourceLocalId != updated.id) {
      if (throwOnError) {
        throw StateError(
          'A lista local não corresponde à lista compartilhada.',
        );
      }
      return;
    }
    if (_isSyncingToShared) {
      if (throwOnError) {
        throw StateError('A sincronização da lista ainda está em andamento.');
      }
      return;
    }
    _isSyncingToShared = true;
    try {
      await repository.syncLocalListToShared(
        localList: updated,
        sharedList: shared,
        updatedBy: uid,
      );
      final latest = await repository.fetchSharedList(shared.id);
      if (mounted && latest != null) {
        setState(() {
          _linkedSharedSummary = latest;
          _lastSharedSyncAt = DateTime.now();
        });
      }
      if (showSnack) {
        HapticFeedback.mediumImpact();
        _showSnack(
          'Listas compartilhadas sincronizadas.',
          type: AppToastType.success,
        );
      }
    } catch (error) {
      if (showSnack) {
        _showSnack(
          'Não foi possível sincronizar. Verifique sua conexão e tente novamente.',
        );
      }
      if (throwOnError) {
        rethrow;
      }
    } finally {
      _isSyncingToShared = false;
    }
  }

  void _updateList(
    ShoppingListModel updated, {
    String? message,
    AppToastType messageType = AppToastType.success,
  }) {
    final normalized = updated.copyWith(updatedAt: DateTime.now());
    setState(() {
      _list = normalized;
    });
    _maybeWarnBudgetExceeded(normalized);
    unawaited(widget.store.upsertList(_list));
    unawaited(_syncLocalChangesToShared(normalized));
    if (message != null) {
      HapticFeedback.mediumImpact();
      _showSnack(message, type: messageType);
    }
  }

  Future<void> _renameList() async {
    if (!_ensureEditable()) {
      return;
    }
    final newName = await showListNameDialog(
      context,
      title: 'Renomear lista',
      confirmLabel: 'Salvar',
      initialValue: _list.name,
    );

    if (!mounted || newName == null) {
      return;
    }

    _updateList(
      _list.copyWith(name: newName),
      message: 'Nome da lista atualizado.',
    );
  }

  Future<void> _openItemForm({ShoppingItem? existing}) async {
    if (!_ensureEditable()) {
      return;
    }
    final blockedNames = _list.items
        .where((item) => existing == null || item.id != existing.id)
        .map((item) => normalizeQuery(item.name))
        .toSet();

    if (existing == null) {
      final drafts = await showShoppingItemsEditorSheet(
        context,
        blockedNormalizedNames: blockedNames,
        catalogProducts: widget.store.catalogProducts,
        onLookupBarcode: widget.store.lookupProductByBarcode,
        onLookupCatalogByName: widget.store.lookupCatalogProductByName,
      );

      if (!mounted || drafts == null || drafts.isEmpty) {
        return;
      }

      final items = [..._list.items];
      for (final draft in drafts) {
        items.add(_shoppingItemFromDraft(draft));
        unawaited(widget.store.saveDraftToCatalog(draft));
      }

      _updateList(
        _list.copyWith(items: items),
        message: drafts.length == 1
            ? 'Produto adicionado.'
            : '${drafts.length} produtos adicionados.',
      );
      return;
    }

    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: existing,
      blockedNormalizedNames: blockedNames,
      catalogProducts: widget.store.catalogProducts,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );

    if (!mounted || draft == null) {
      return;
    }

    final items = [..._list.items];
    final index = items.indexWhere((item) => item.id == existing.id);
    if (index != -1) {
      final history = [...existing.priceHistory];
      if (history.isEmpty) {
        history.add(
          PriceHistoryEntry(
            price: existing.unitPrice,
            recordedAt: DateTime.now(),
          ),
        );
      }
      final shouldAddHistory =
          history.isEmpty ||
          (history.last.price - draft.unitPrice).abs() > 0.0001;
      if (shouldAddHistory) {
        history.add(
          PriceHistoryEntry(price: draft.unitPrice, recordedAt: DateTime.now()),
        );
      }

      items[index] = existing.copyWith(
        name: draft.name,
        quantity: draft.quantity,
        unitPrice: draft.unitPrice,
        barcode: draft.barcode,
        category: draft.category,
        isPurchased: draft.isPurchased,
        priceHistory: history,
      );
    }

    _updateList(_list.copyWith(items: items), message: 'Produto atualizado.');
    unawaited(widget.store.saveDraftToCatalog(draft));
  }

  Future<void> _openVoiceQuickAdd() async {
    if (!_ensureEditable()) {
      return;
    }
    final voiceService = widget.voiceRecognitionService;
    if (voiceService == null) {
      _showSnack(
        'A adição por voz não está disponível neste dispositivo.',
        type: AppToastType.warning,
      );
      return;
    }

    final drafts = await showVoiceQuickAddSheet(
      context,
      voiceRecognitionService: voiceService,
      catalogProducts: widget.store.catalogProducts,
      currentItems: _list.items,
    );
    if (!mounted || drafts == null || drafts.isEmpty) {
      return;
    }

    final result = const VoiceDraftListMerger().merge(
      _list.items,
      drafts,
      recordedAt: DateTime.now(),
    );
    for (final draft in drafts) {
      unawaited(widget.store.saveDraftToCatalog(draft));
    }
    _updateList(
      _list.copyWith(items: result.items),
      message: _voiceMergeMessage(result),
    );
  }

  String _voiceMergeMessage(VoiceDraftMergeResult result) {
    if (result.mergedCount == 0) {
      return result.createdCount == 1
          ? 'Produto adicionado por voz.'
          : '${result.createdCount} produtos adicionados por voz.';
    }
    if (result.createdCount == 0) {
      return result.mergedCount == 1
          ? 'Quantidade atualizada por voz.'
          : '${result.mergedCount} quantidades atualizadas por voz.';
    }
    return '${result.createdCount} adicionados e '
        '${result.mergedCount} quantidades atualizadas.';
  }

  ShoppingItem _shoppingItemFromDraft(ShoppingItemDraft draft) {
    return ShoppingItem(
      id: uniqueId(),
      name: draft.name,
      quantity: draft.quantity,
      unitPrice: draft.unitPrice,
      barcode: draft.barcode,
      category: draft.category,
      isPurchased: draft.isPurchased,
      priceHistory: draft.unitPrice > 0
          ? [
              PriceHistoryEntry(
                price: draft.unitPrice,
                recordedAt: DateTime.now(),
              ),
            ]
          : const <PriceHistoryEntry>[],
    );
  }

  Future<void> _importFromFiscalReceipt() async {
    if (!_ensureEditable()) {
      return;
    }

    final submission = await showFiscalReceiptImportSheet(
      context,
      currentItems: _list.items,
      catalogProducts: widget.store.catalogProducts,
    );
    if (!mounted || submission == null || submission.items.isEmpty) {
      return;
    }

    FiscalReceiptImportTransaction? transaction;
    CompletedPurchase? sharedPurchase;
    try {
      transaction = await widget.store.applyFiscalReceiptReview(
        _list.id,
        submission,
      );
      if (transaction == null) {
        throw StateError('A lista não está mais disponível.');
      }

      final shared = _linkedSharedSummary;
      if (shared != null) {
        final repository = widget.sharedListsRepository;
        final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
        if (repository == null || uid.isEmpty) {
          throw StateError(
            'Entre na sua conta para atualizar a lista compartilhada.',
          );
        }

        final listToSync = submission.finalizePurchase
            ? transaction.appliedList.copyWith(
                isClosed: false,
                clearClosedAt: true,
              )
            : transaction.appliedList;
        await _syncLocalChangesToShared(listToSync, throwOnError: true);
        if (submission.finalizePurchase) {
          sharedPurchase = await repository.finalizeSharedList(
            listId: shared.id,
            updatedBy: uid,
            markPendingAsPurchased: false,
          );
        }
      }
    } catch (error) {
      final applied = transaction;
      if (applied != null) {
        await _rollbackFailedFiscalReceiptImport(applied);
      }
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível aplicar o cupom. Revise os dados e tente novamente.',
        type: AppToastType.error,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _list = transaction!.appliedList.deepCopy();
      _didShowBudgetWarning = _list.isOverBudget;
      _didShowBudgetNearLimitWarning = false;
    });
    _maybeWarnBudgetExceeded(_list);
    HapticFeedback.mediumImpact();

    final appliedTransaction = transaction;
    final sharedHistoryId = sharedPurchase?.id;
    _showSnack(
      submission.finalizePurchase
          ? 'Compra confirmada. Histórico e preços atualizados.'
          : 'Cupom aplicado. Itens e preços atualizados.',
      type: AppToastType.success,
      duration: const Duration(seconds: 8),
      actionLabel: 'Desfazer',
      onAction: () => unawaited(
        _undoFiscalReceiptImport(
          appliedTransaction,
          sharedHistoryId: sharedHistoryId,
        ),
      ),
    );
  }

  Future<void> _rollbackFailedFiscalReceiptImport(
    FiscalReceiptImportTransaction transaction,
  ) async {
    try {
      final restored = await widget.store.undoFiscalReceiptImport(transaction);
      final shared = _linkedSharedSummary;
      final repository = widget.sharedListsRepository;
      final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
      if (restored != null &&
          shared != null &&
          repository != null &&
          uid.isNotEmpty) {
        await repository.syncLocalListToShared(
          localList: restored,
          sharedList: shared,
          updatedBy: uid,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Falha ao restaurar importação de cupom',
        name: 'fiscal_receipt_import',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _undoFiscalReceiptImport(
    FiscalReceiptImportTransaction transaction, {
    String? sharedHistoryId,
  }) async {
    final shared = _linkedSharedSummary;
    final repository = widget.sharedListsRepository;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final shouldUndoShared =
        shared != null &&
        repository != null &&
        uid.isNotEmpty &&
        sharedHistoryId != null;

    try {
      if (shouldUndoShared) {
        await repository.undoSharedFinalization(
          listId: shared.id,
          historyId: sharedHistoryId,
          updatedBy: uid,
        );
      }

      final restored = await widget.store.undoFiscalReceiptImport(transaction);
      if (restored == null) {
        throw StateError('A lista não está mais disponível.');
      }

      if (shared != null && repository != null && uid.isNotEmpty) {
        await repository.syncLocalListToShared(
          localList: restored,
          sharedList: shared,
          updatedBy: uid,
        );
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _list = restored.deepCopy();
        _didShowBudgetWarning = _list.isOverBudget;
        _didShowBudgetNearLimitWarning = false;
      });
      _showSnack(
        'Importação desfeita. A lista, o histórico e os preços foram restaurados.',
        type: AppToastType.success,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Falha ao desfazer importação de cupom',
        name: 'fiscal_receipt_import',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível desfazer porque a lista mudou ou está sem conexão.',
        type: AppToastType.error,
      );
    }
  }

  void _togglePurchased(ShoppingItem item, bool? value) {
    if (!_ensureEditable()) {
      return;
    }
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }

    final items = [..._list.items];
    items[index] = item.copyWith(isPurchased: value ?? false);
    _updateList(_list.copyWith(items: items));
    HapticFeedback.selectionClick();
    _showSnack(
      (value ?? false) ? 'Item comprado.' : 'Item pendente.',
      type: AppToastType.success,
      duration: const Duration(milliseconds: 900),
    );
  }

  void _changeQuantity(ShoppingItem item, int delta) {
    if (!_ensureEditable()) {
      return;
    }
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }

    final items = [..._list.items];
    items[index] = item.copyWith(quantity: max(1, item.quantity + delta));
    _updateList(_list.copyWith(items: items));
  }

  String _buildDuplicateName(String baseName) {
    final existingNames = _list.items
        .map((entry) => normalizeQuery(entry.name))
        .toSet();
    var candidate = '$baseName (cópia)';
    var counter = 2;
    while (existingNames.contains(normalizeQuery(candidate))) {
      candidate = '$baseName (cópia $counter)';
      counter++;
    }
    return candidate;
  }

  void _duplicateItem(ShoppingItem item) {
    if (!_ensureEditable()) {
      return;
    }
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final duplicate = item.copyWith(
      id: uniqueId(),
      name: _buildDuplicateName(item.name),
      isPurchased: false,
    );
    final items = [..._list.items];
    items.insert(index + 1, duplicate);
    _updateList(
      _list.copyWith(items: items),
      message: '"${item.name}" duplicado.',
    );
  }

  Future<void> _showSwipeQuickActions(ShoppingItem item) async {
    FocusScope.of(context).unfocus();
    final action = await showItemActionsSheet(context, item: item);

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ItemAction.edit:
        await _openItemForm(existing: item);
        return;
      case ItemAction.duplicate:
        _duplicateItem(item);
        return;
      case ItemAction.delete:
        await _deleteItem(item);
        return;
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    if (!_ensureEditable()) {
      return;
    }
    final shouldDelete = await showDeleteItemDialog(context, item: item);

    if (!mounted || shouldDelete != true) {
      return;
    }

    final items = [..._list.items]..removeWhere((entry) => entry.id == item.id);
    _updateList(
      _list.copyWith(items: items),
      message: '"${item.name}" removido.',
    );
  }

  Future<void> _showPriceHistory(ShoppingItem item) async {
    FocusScope.of(context).unfocus();
    await showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .85,
          ),
          child: EditorPriceHistorySheet(item: item),
        );
      },
    );
  }

  Future<void> _clearPurchased() async {
    if (!_ensureEditable()) {
      return;
    }
    if (_list.purchasedItemsCount == 0) {
      return;
    }

    final shouldClear = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar comprados?'),
        content: const Text('Essa ação remove apenas os itens comprados.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    final removedCount = _list.purchasedItemsCount;
    final remaining = _list.items
        .where((item) => !item.isPurchased)
        .toList(growable: false);
    _updateList(
      _list.copyWith(items: remaining),
      message: removedCount == 1
          ? '1 item removido.'
          : '$removedCount itens removidos.',
    );
  }

  void _showSnack(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void _logShare(String message) {
    debugPrint('[share_flow] $message');
    developer.log(message, name: 'share_flow');
  }

  void _maybeWarnBudgetExceeded(ShoppingListModel updatedList) {
    if (updatedList.hasBudget) {
      final budget = updatedList.budget ?? 0;
      if (budget > 0) {
        final usageRatio = (updatedList.totalValue / budget).clamp(0.0, 1.5);
        final isNearLimit = usageRatio >= 0.85 && usageRatio < 1.0;
        if (isNearLimit && !_didShowBudgetNearLimitWarning) {
          _didShowBudgetNearLimitWarning = true;
          _showSnack(
            'Orçamento em 85% ou mais. Restante: ${formatCurrency(updatedList.budgetRemaining)}.',
          );
          unawaited(
            widget.store.notifyBudgetNearLimit(
              updatedList,
              budgetUsageRatio: usageRatio,
            ),
          );
        } else if (usageRatio < 0.8) {
          _didShowBudgetNearLimitWarning = false;
        }
      }
    } else {
      _didShowBudgetNearLimitWarning = false;
    }

    if (updatedList.isOverBudget && !_didShowBudgetWarning) {
      _didShowBudgetWarning = true;
      _showSnack(
        'Orçamento excedido em ${formatCurrency(updatedList.overBudgetAmount)}.',
      );
      return;
    }

    if (!updatedList.isOverBudget) {
      _didShowBudgetWarning = false;
    }
  }

  Future<void> _openBudgetEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final result = await showBudgetEditorDialog(
      context,
      initialValue: _list.budget,
      initialPaymentBalances: _list.paymentBalances,
      financeRepository: _financeIntegrationRepository,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.clear) {
      _updateList(
        _list.copyWith(clearBudget: true),
        message: 'Orçamento removido.',
      );
      return;
    }

    final value = result.value;
    if (value == null || value <= 0) {
      return;
    }

    _updateList(
      _list.copyWith(budget: value, paymentBalances: result.paymentBalances),
      message: 'Orçamento atualizado.',
    );
  }

  Future<void> _openPaymentBalancesEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final previousBalancesTotal = _list.paymentBalancesTotal;
    final previousBudget = _list.budget;
    final result = await showPaymentBalancesEditorDialog(
      context,
      initialValues: _list.paymentBalances,
      financeRepository: _financeIntegrationRepository,
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.clear || (result.value?.isEmpty ?? true)) {
      _updateList(
        _list.copyWith(clearPaymentBalances: true),
        message: 'Saldos removidos.',
      );
      return;
    }

    final updatedBalances = result.value ?? const <PaymentBalance>[];
    final updatedBalancesTotal = updatedBalances.fold<double>(
      0,
      (total, entry) => total + entry.amount,
    );
    final delta = updatedBalancesTotal - previousBalancesTotal;
    final double nextBudget = previousBudget == null
        ? updatedBalancesTotal
        : max<double>(0, previousBudget + delta);

    _updateList(
      _list.copyWith(paymentBalances: updatedBalances, budget: nextBudget),
      message:
          'Saldos atualizados. Orçamento ajustado para ${formatCurrency(nextBudget)}.',
    );
  }

  Future<void> _openReminderEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final result = await showReminderEditorDialog(
      context,
      initialValue: _list.reminder,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.clear || result.value == null) {
      _updateList(
        _list.copyWith(clearReminder: true),
        message: 'Lembrete removido.',
      );
      return;
    }

    final reminder = result.value!;
    _updateList(
      _list.copyWith(reminder: reminder),
      message: 'Lembrete ativo: ${formatDateTime(reminder.scheduledAt)}.',
    );
  }

  Future<void> _shareListWithCode() async {
    _logShare('share clicked items=${_list.items.length}');
    final repository = widget.sharedListsRepository;
    if (repository == null) {
      _logShare('share repository is null');
      _showSnack('Compartilhamento indisponível neste modo.');
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      _logShare('share blocked: uid vazio');
      _showSnack('Faça login para compartilhar a lista.');
      return;
    }
    try {
      _logShare('createOrGetSharedListFromLocal started');
      final sharedList = await repository.createOrGetSharedListFromLocal(
        localList: _list,
        ownerUid: uid,
      );
      _logShare('createOrGetSharedListFromLocal completed');
      if (sharedList.inviteCode == null || sharedList.inviteCode!.isEmpty) {
        _logShare('invite vazio, gerando novo código...');
        await repository.generateInviteCode(
          listId: sharedList.id,
          requesterUid: uid,
        );
        _logShare('generateInviteCode ok');
      }
      if (!mounted) {
        _logShare('share flow aborted: widget unmounted');
        return;
      }
      if (mounted) {
        setState(() {
          _linkedSharedSummary = sharedList;
        });
      }
      _startSharedLiveSync(sharedList.id);
      await showSharedInviteSheet(
        context: context,
        repository: repository,
        listId: sharedList.id,
        currentUid: uid,
        onOpenSharedList: () async {
          _logShare('open shared list');
          await Navigator.push<void>(
            context,
            buildAppPageRoute(
              builder: (_) => SharedListEditorPage(
                repository: repository,
                store: widget.store,
                listId: sharedList.id,
              ),
            ),
          );
        },
      );
      if (!mounted) {
        return;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is FirebaseException) {
        _logShare('share failed kind=FirebaseException:${error.code}');
      } else {
        _logShare('share failed kind=${error.runtimeType}');
      }
      _showSnack('Não foi possível compartilhar a lista. Tente novamente.');
    }
  }

  Future<void> _openMarketShoppingMode() async {
    if (!_ensureEditable()) {
      return;
    }
    if (_list.items.isEmpty) {
      _showSnack('Adicione produtos antes de abrir o modo compra.');
      return;
    }

    final updated = await Navigator.push<ShoppingListModel>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingMarketModePage(
          initialList: _list,
          financeRepository: _financeIntegrationRepository,
          onSave: (updated) async {
            await widget.store.upsertList(updated);
            if (!mounted) return;
            setState(() => _list = updated);
            unawaited(_syncLocalChangesToShared(updated));
          },
        ),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    setState(() => _list = updated);
    _maybeWarnBudgetExceeded(updated);
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => PurchaseHistoryPage(
          store: widget.store,
          financeRepository: _financeIntegrationRepository,
        ),
      ),
    );
  }

  Future<void> _openCatalogPage() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => CatalogProductsPage(store: widget.store),
      ),
    );
  }

  Future<void> _reopenListForEditing() async {
    if (_linkedSharedSummary != null) {
      final repository = widget.sharedListsRepository;
      final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
      if (repository == null || uid.isEmpty) {
        _showSnack('Não foi possível reabrir no modo compartilhado.');
        return;
      }
      try {
        await repository.reopenSharedList(
          listId: _linkedSharedSummary!.id,
          updatedBy: uid,
        );
        await _syncLinkedSharedNow(showSnack: true);
      } catch (error) {
        _showSnack('Não foi possível reabrir a lista. Tente novamente.');
      }
      return;
    }
    final updated = await widget.store.reopenList(_list.id);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _list = updated.deepCopy();
      _didShowBudgetWarning = _list.isOverBudget;
      _didShowBudgetNearLimitWarning = false;
    });
    _showSnack('Lista reaberta. Edições liberadas.');
  }

  bool _finalizingPurchase = false;
  Future<void> _finalizePurchase() async {
    if (_finalizingPurchase) return;
    _finalizingPurchase = true;
    try {
      await _performFinalizePurchase();
    } catch (_) {
      _showSnack(
        'Não foi possível concluir o fechamento. Confira o histórico antes de tentar novamente.',
      );
    } finally {
      _finalizingPurchase = false;
    }
  }

  Future<void> _performFinalizePurchase() async {
    if (_list.isClosed) {
      _showSnack('A lista já está fechada. Toque em reabrir para editar.');
      return;
    }
    if (_list.items.isEmpty) {
      _showSnack('Adicione itens antes de fechar a compra.');
      return;
    }

    unawaited(
      showAppDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Expanded(child: Text('Consultando cartões do Finanças…')),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      await _refreshFinanceCheckout().timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _financeLoadError =
          'A consulta aos cartões demorou mais que o esperado. Tente fechar novamente para atualizar.';
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;
    final checkout = await showPurchaseCheckoutDialog(
      context,
      list: _list,
      financeWorkspace: _financeWorkspace,
      financeLoadError: _financeLoadError,
    );
    if (!mounted || checkout == null) {
      return;
    }

    await _persistCheckoutCorrections(checkout.reviewedItems);
    if (!mounted) return;

    final financeIntent = checkout.sendToFinance
        ? FinanceCheckoutIntent(
            connectionId: await _financeIntegrationRepository.connectionId(),
            allocations: checkout.financeAllocations,
            categoryId: checkout.financeCategoryId,
          )
        : null;

    if (_linkedSharedSummary != null) {
      final repository = widget.sharedListsRepository;
      final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
      if (repository == null || uid.isEmpty) {
        _showSnack('Não foi possível fechar no modo compartilhado.');
        return;
      }
      try {
        await _syncLocalChangesToShared(_list);
        final localFinalized = await widget.store.finalizeList(
          _list.id,
          markPendingAsPurchased: checkout.markPendingAsPurchased,
          financeIntent: financeIntent,
          finalTotalCents: checkout.finalTotalCents,
        );
        if (mounted && localFinalized != null) {
          setState(() {
            _list = localFinalized.deepCopy();
            _didShowBudgetWarning = _list.isOverBudget;
            _didShowBudgetNearLimitWarning = false;
          });
        }
        await repository.finalizeSharedList(
          listId: _linkedSharedSummary!.id,
          updatedBy: uid,
          markPendingAsPurchased: checkout.markPendingAsPurchased,
          finalTotalCents: checkout.finalTotalCents,
        );
        await _syncLinkedSharedNow(showSnack: true);
        final financeMessage = await _submitCompletedPurchase(checkout);
        if (!mounted) return;
        await showPurchaseCompletionDialog(
          context,
          financeMessage:
              financeMessage ??
              'Compra fechada e salva no histórico compartilhado.',
        );
      } catch (error) {
        _showSnack('Não foi possível fechar a lista. Tente novamente.');
      }
      return;
    }

    final didFinalize =
        await widget.store.finalizeList(
          _list.id,
          markPendingAsPurchased: checkout.markPendingAsPurchased,
          financeIntent: financeIntent,
          finalTotalCents: checkout.finalTotalCents,
        ) !=
        null;
    if (!mounted || !didFinalize) {
      return;
    }
    final financeMessage = await _submitCompletedPurchase(checkout);
    if (!mounted) return;
    await showPurchaseCompletionDialog(
      context,
      financeMessage:
          financeMessage ?? 'Compra fechada e salva no histórico mensal.',
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _refreshFinanceCheckout() {
    final active = _financeLoadFuture;
    if (active != null) return active;
    final future = _loadFinanceCheckout();
    _financeLoadFuture = future;
    future.whenComplete(() {
      if (identical(_financeLoadFuture, future)) {
        _financeLoadFuture = null;
      }
    });
    return future;
  }

  Future<void> _persistCheckoutCorrections(
    List<ShoppingItem> reviewedItems,
  ) async {
    if (reviewedItems.isEmpty || !_checkoutItemsChanged(reviewedItems)) return;
    final corrected = _list.copyWith(
      items: reviewedItems,
      updatedAt: DateTime.now(),
    );
    await widget.store.upsertList(corrected);
    if (!mounted) return;
    setState(() => _list = corrected.deepCopy());
  }

  bool _checkoutItemsChanged(List<ShoppingItem> reviewedItems) {
    if (reviewedItems.length != _list.items.length) return true;
    for (var index = 0; index < reviewedItems.length; index++) {
      final before = _list.items[index];
      final after = reviewedItems[index];
      if (before.id != after.id ||
          before.quantity != after.quantity ||
          before.unitPrice != after.unitPrice ||
          before.isPurchased != after.isPurchased) {
        return true;
      }
    }
    return false;
  }

  Future<void> _loadFinanceCheckout() async {
    try {
      if (!await _financeIntegrationRepository.isConnected()) {
        _financeWorkspace = null;
        _financeLoadError = null;
        return;
      }
      final workspace = await _financeIntegrationRepository.loadWorkspace();
      _financeWorkspace = workspace;
      _financeLoadError = null;
    } on FinanceIntegrationException catch (error) {
      _financeWorkspace = null;
      _financeLoadError = error.message;
    } catch (_) {
      _financeWorkspace = null;
      _financeLoadError = 'O Minhas Finanças está indisponível agora.';
    }
  }

  Future<String?> _submitCompletedPurchase(
    PurchaseCheckoutResult checkout,
  ) async {
    CompletedPurchase? completed;
    for (final candidate in widget.store.purchaseHistory) {
      if (candidate.listId == _list.id) {
        completed = candidate;
        break;
      }
    }
    if (completed == null || completed.spentValue <= 0) {
      return 'Compra fechada, mas o total precisa ser maior que zero para lançar no Finanças.';
    }
    final intent = completed.financeIntent;
    if (intent == null) return null;
    try {
      await _financeIntegrationRepository.submitPurchasePlan(
        buildFinancePurchasePlan(
          purchase: completed,
          allocations: intent.allocations,
          categoryId: intent.categoryId,
        ),
      );
      final records =
          (await _financeIntegrationRepository.purchaseSyncHistory())
              .where((r) => r.purchaseId == completed!.id)
              .toList();
      final synced = records
          .where((r) => r.status == FinanceSyncStatus.synced)
          .length;
      if (synced != records.length) {
        return synced > 0
            ? 'Compra fechada. $synced de ${records.length} pagamentos sincronizados. Confira o histórico.'
            : 'Compra fechada. O envio ao Finanças está pendente; confira o histórico.';
      }
      return 'Compra fechada e lançada no Minhas Finanças.';
    } on FinanceIntegrationException catch (error) {
      return 'Compra fechada, mas não foi lançada no Finanças: ${error.message}';
    } catch (_) {
      return 'Compra fechada, mas não foi possível lançar no Minhas Finanças.';
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _sortOption = ItemSortOption.defaultOrder;
      _categoryFilter = null;
      _marketModeEnabled = false;
      _itemsVisibility = EditorItemsVisibility.pending;
    });
  }

  void _handleAppBarMenuAction(ListEditorMenuAction action) {
    switch (action) {
      case ListEditorMenuAction.reopenList:
        _reopenListForEditing();
        return;
      case ListEditorMenuAction.openSharedList:
        _openLinkedSharedList();
        return;
      case ListEditorMenuAction.syncSharedNow:
        unawaited(_syncLocalChangesToShared(_list));
        _syncLinkedSharedNow(showSnack: true);
        return;
      case ListEditorMenuAction.shareList:
        _shareListWithCode();
        return;
      case ListEditorMenuAction.importFiscalReceipt:
        _importFromFiscalReceipt();
        return;
      case ListEditorMenuAction.finalizePurchase:
        _finalizePurchase();
        return;
      case ListEditorMenuAction.openMarketMode:
        _openMarketShoppingMode();
        return;
      case ListEditorMenuAction.openCatalog:
        _openCatalogPage();
        return;
      case ListEditorMenuAction.viewHistory:
        _openPurchaseHistory();
        return;
      case ListEditorMenuAction.editReminder:
        _openReminderEditor();
        return;
      case ListEditorMenuAction.editBudget:
        _openBudgetEditor();
        return;
      case ListEditorMenuAction.editPaymentBalances:
        _openPaymentBalancesEditor();
        return;
      case ListEditorMenuAction.toggleMarketOrdering:
        setState(() {
          _marketModeEnabled = !_marketModeEnabled;
        });
        return;
      case ListEditorMenuAction.renameList:
        _renameList();
        return;
      case ListEditorMenuAction.clearPurchased:
        _clearPurchased();
        return;
    }
  }

  Future<void> _showListActionsSheet() async {
    FocusScope.of(context).unfocus();
    final selected = await showAppModalBottomSheet<ListEditorMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: editorialWorkspaceTheme(
        Theme.of(context),
      ).colorScheme.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        return Theme(
          data: editorialWorkspaceTheme(Theme.of(context)),
          child: ListEditorActionsSheet(
            isClosed: _list.isClosed,
            isSharedLocked: _isSharedLocked,
            hasReminder: _list.reminder != null,
            hasPurchasedItems: _list.purchasedItemsCount > 0,
            marketOrderingEnabled: _marketModeEnabled,
          ),
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    _handleAppBarMenuAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lista não encontrada')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
        ),
      );
    }

    final visibleItems = _visibleItems;
    final linkedShared = _linkedSharedSummary;
    final sharedRepository = widget.sharedListsRepository;

    if (_forceSharedView && linkedShared != null && sharedRepository != null) {
      return SharedListEditorPage(
        repository: sharedRepository,
        store: widget.store,
        listId: linkedShared.id,
      );
    }

    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${formatItemCount(_list.items.length)}${_list.isClosed ? ' · Fechada' : ''}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Compartilhar lista',
                onPressed: _shareListWithCode,
                icon: const Icon(Icons.person_add_outlined, size: 20),
              ),
              IconButton(
                tooltip: 'Ações da lista',
                onPressed: _showListActionsSheet,
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
          bottomNavigationBar: _isEditingLocked
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey('editor_add_item'),
                            onPressed: _openItemForm,
                            icon: const Icon(
                              Icons.add_shopping_cart_rounded,
                              size: 18,
                            ),
                            label: const Text('Adicionar item'),
                          ),
                        ),
                        if (widget.voiceRecognitionService != null)
                          IconButton(
                            tooltip: 'Adicionar produtos por voz',
                            onPressed: _openVoiceQuickAdd,
                            icon: const Icon(Icons.mic_outlined),
                          ),
                        IconButton(
                          tooltip: 'Importar cupom fiscal',
                          onPressed: _importFromFiscalReceipt,
                          icon: const Icon(Icons.receipt_long_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          if (linkedShared != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                              child: Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    14,
                                    12,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.group_work_rounded),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Lista compartilhada detectada',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Abra a versão compartilhada para ver '
                                              'atualizações em tempo real.',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                            const SizedBox(height: 10),
                                            EditorSyncStatusPill(
                                              isSyncing: _isSyncingToShared,
                                              lastSyncAt: _lastSharedSyncAt,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          FilledButton.tonal(
                                            onPressed: _openLinkedSharedList,
                                            child: const Text('Abrir'),
                                          ),
                                          TextButton(
                                            onPressed:
                                                _openSharedInviteSheetFromLocal,
                                            child: const Text('Gerenciar'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          EditorEditorialSummary(
                            list: _list,
                            initialExpanded:
                                widget.initialSummaryExpanded ?? _list.isClosed,
                            onBudget: _isEditingLocked
                                ? () => _ensureEditable()
                                : _openBudgetEditor,
                            onReminder: _isEditingLocked
                                ? () => _ensureEditable()
                                : _openReminderEditor,
                            onBalances: _isEditingLocked
                                ? () => _ensureEditable()
                                : _openPaymentBalancesEditor,
                            onMarket: _openMarketShoppingMode,
                            onCheckout: _finalizePurchase,
                            onReopen: _list.isClosed
                                ? _reopenListForEditing
                                : null,
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: ItemsToolsBar(
                              controller: _searchController,
                              selectedSort: _sortOption,
                              selectedCategory: _categoryFilter,
                              visibilityFilter: _itemsVisibility,
                              marketModeEnabled: _marketModeEnabled,
                              visibleCount: visibleItems.length,
                              totalCount: _list.items.length,
                              pendingCount: _pendingItemsCount,
                              purchasedCount: _purchasedItemsCount,
                              hasActiveFilters: _hasActiveFilters,
                              onSortChanged: (value) {
                                setState(() {
                                  _sortOption = value;
                                });
                              },
                              onCategoryChanged: (value) {
                                setState(() {
                                  _categoryFilter = value;
                                });
                              },
                              onVisibilityChanged: _setItemsVisibility,
                              onClearFilters: _clearFilters,
                            ),
                          ),
                          if (_itemsVisibility ==
                                  EditorItemsVisibility.pending &&
                              _purchasedItemsCount > 0)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              child: EditorInlineInfoBanner(
                                icon: Icons.visibility_outlined,
                                message: _purchasedItemsCount == 1
                                    ? '1 item comprado oculto para deixar a lista mais objetiva.'
                                    : '$_purchasedItemsCount itens comprados ocultos para deixar a lista mais objetiva.',
                                actionLabel: 'Ver',
                                onAction: () => _setItemsVisibility(
                                  EditorItemsVisibility.purchased,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_list.items.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptyItemsState(),
                      )
                    else if (visibleItems.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: EmptySearchState(
                          query: _searchQuery,
                          visibilityFilter: _itemsVisibility,
                          onClearFilters: _clearFilters,
                          onShowPending: () => _setItemsVisibility(
                            EditorItemsVisibility.pending,
                          ),
                          onShowPurchased: () => _setItemsVisibility(
                            EditorItemsVisibility.purchased,
                          ),
                          onShowAll: () =>
                              _setItemsVisibility(EditorItemsVisibility.all),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        sliver: SliverList.separated(
                          key: ValueKey(
                            '${_list.id}-${_sortOption.name}-$_marketModeEnabled-${_categoryFilter?.key ?? 'all'}',
                          ),
                          itemCount: visibleItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox.shrink(),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return EditorEntryAnimation(
                              key: ValueKey(item.id),
                              delay: Duration(
                                milliseconds: min(160, index * 24),
                              ),
                              child: Dismissible(
                                key: ValueKey('list_item_${item.id}'),
                                direction: _isEditingLocked
                                    ? DismissDirection.none
                                    : DismissDirection.horizontal,
                                confirmDismiss: (direction) async {
                                  if (_isEditingLocked) {
                                    return false;
                                  }
                                  if (direction ==
                                      DismissDirection.startToEnd) {
                                    _togglePurchased(item, !item.isPurchased);
                                    return false;
                                  }
                                  if (direction ==
                                      DismissDirection.endToStart) {
                                    await _showSwipeQuickActions(item);
                                    return false;
                                  }
                                  return false;
                                },
                                background: EditorMarketSwipeBackground(
                                  icon: item.isPurchased
                                      ? Icons.undo_rounded
                                      : Icons.check_rounded,
                                  label: item.isPurchased
                                      ? 'Marcar pendente'
                                      : 'Marcar comprado',
                                  alignRight: false,
                                ),
                                secondaryBackground:
                                    const EditorMarketSwipeBackground(
                                      icon: Icons.bolt_rounded,
                                      label: 'Ações rápidas',
                                      alignRight: true,
                                    ),
                                child: EditorShoppingItemCard(
                                  item: item,
                                  readOnly: _isEditingLocked,
                                  expanded: _expandedItemId == item.id,
                                  onToggleExpanded: () {
                                    setState(() {
                                      _expandedItemId =
                                          _expandedItemId == item.id
                                          ? null
                                          : item.id;
                                    });
                                  },
                                  onPurchasedChanged: (value) =>
                                      _togglePurchased(item, value),
                                  onIncrement: () => _changeQuantity(item, 1),
                                  onDecrement: () => _changeQuantity(item, -1),
                                  onEdit: () => _openItemForm(existing: item),
                                  onViewHistory: () => _showPriceHistory(item),
                                  onDelete: () => _deleteItem(item),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
