import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'catalog_products_page.dart';
import 'dialogs_and_sheets.dart';
import 'extensions/classification_ui_extensions.dart';
import 'launch.dart';
import 'market_mode_page.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor/widgets/editor_chrome_widgets.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

enum _ListEditorMenuAction {
  reopenList,
  openSharedList,
  syncSharedNow,
  shareList,
  importFiscalReceipt,
  finalizePurchase,
  openMarketMode,
  openCatalog,
  viewHistory,
  editReminder,
  editBudget,
  editPaymentBalances,
  toggleMarketOrdering,
  renameList,
  clearPurchased,
}

enum _ListItemSwipeQuickAction { edit, duplicate, delete }

class _ListEditorActionsSheet extends StatelessWidget {
  const _ListEditorActionsSheet({
    required this.isClosed,
    required this.isSharedLocked,
    required this.hasReminder,
    required this.hasPurchasedItems,
    required this.marketOrderingEnabled,
  });

  final bool isClosed;
  final bool isSharedLocked;
  final bool hasReminder;
  final bool hasPurchasedItems;
  final bool marketOrderingEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final quickActions = isClosed
        ? const <_ListEditorMenuAction>[_ListEditorMenuAction.reopenList]
        : <_ListEditorMenuAction>[
            _ListEditorMenuAction.finalizePurchase,
            _ListEditorMenuAction.importFiscalReceipt,
            _ListEditorMenuAction.openMarketMode,
            if (isSharedLocked) _ListEditorMenuAction.syncSharedNow,
          ];
    final purchaseActions = <_ListEditorMenuAction>[
      if (!isClosed) ...[
        _ListEditorMenuAction.importFiscalReceipt,
        _ListEditorMenuAction.finalizePurchase,
        _ListEditorMenuAction.openMarketMode,
        _ListEditorMenuAction.openCatalog,
        if (hasPurchasedItems) _ListEditorMenuAction.clearPurchased,
      ],
      if (isClosed) _ListEditorMenuAction.reopenList,
      if (isClosed) _ListEditorMenuAction.openCatalog,
      if (isSharedLocked) _ListEditorMenuAction.openSharedList,
      if (isSharedLocked) _ListEditorMenuAction.syncSharedNow,
      _ListEditorMenuAction.shareList,
      _ListEditorMenuAction.viewHistory,
    ];
    final settingsActions = isClosed
        ? const <_ListEditorMenuAction>[]
        : <_ListEditorMenuAction>[
            _ListEditorMenuAction.editReminder,
            _ListEditorMenuAction.editBudget,
            _ListEditorMenuAction.editPaymentBalances,
            _ListEditorMenuAction.toggleMarketOrdering,
            _ListEditorMenuAction.renameList,
          ];

    _ListEditorActionMeta resolveMeta(_ListEditorMenuAction action) {
      switch (action) {
        case _ListEditorMenuAction.reopenList:
          return _ListEditorActionMeta(
            label: 'Reabrir lista',
            shortLabel: 'Reabrir',
            icon: Icons.lock_open_rounded,
            color: const Color(0xFF1E88E5),
          );
        case _ListEditorMenuAction.openSharedList:
          return _ListEditorActionMeta(
            label: 'Abrir lista compartilhada',
            shortLabel: 'Abrir compartilhada',
            icon: Icons.group_work_rounded,
            color: const Color(0xFF00796B),
          );
        case _ListEditorMenuAction.syncSharedNow:
          return _ListEditorActionMeta(
            label: 'Sincronizar agora',
            shortLabel: 'Sincronizar',
            icon: Icons.sync_rounded,
            color: const Color(0xFF00838F),
          );
        case _ListEditorMenuAction.shareList:
          return _ListEditorActionMeta(
            label: 'Gerar código de compartilhamento',
            shortLabel: 'Compartilhar',
            icon: Icons.qr_code_rounded,
            color: const Color(0xFF1565C0),
          );
        case _ListEditorMenuAction.importFiscalReceipt:
          return _ListEditorActionMeta(
            label: 'Importar cupom fiscal',
            shortLabel: 'Cupom',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF57C00),
          );
        case _ListEditorMenuAction.finalizePurchase:
          return _ListEditorActionMeta(
            label: 'Fechar compra',
            shortLabel: 'Fechar',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF2E7D32),
          );
        case _ListEditorMenuAction.openMarketMode:
          return _ListEditorActionMeta(
            label: 'Abrir modo compra',
            shortLabel: 'Modo compra',
            icon: Icons.shopping_cart_checkout_rounded,
            color: const Color(0xFFF97316),
          );
        case _ListEditorMenuAction.openCatalog:
          return _ListEditorActionMeta(
            label: 'Abrir catálogo de produtos',
            shortLabel: 'Catálogo',
            icon: Icons.local_offer_rounded,
            color: const Color(0xFF0277BD),
          );
        case _ListEditorMenuAction.viewHistory:
          return _ListEditorActionMeta(
            label: 'Histórico mensal',
            shortLabel: 'Histórico',
            icon: Icons.event_note_rounded,
            color: const Color(0xFF6D4C41),
          );
        case _ListEditorMenuAction.editReminder:
          return _ListEditorActionMeta(
            label: 'Configurar lembrete',
            shortLabel: hasReminder ? 'Lembrete Ativo' : 'Lembrete Inativo',
            icon: hasReminder
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: const Color(0xFF8E24AA),
          );
        case _ListEditorMenuAction.editBudget:
          return _ListEditorActionMeta(
            label: 'Definir orçamento',
            shortLabel: 'Orçamento',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF3949AB),
          );
        case _ListEditorMenuAction.editPaymentBalances:
          return _ListEditorActionMeta(
            label: 'Configurar saldos',
            shortLabel: 'Saldos',
            icon: Icons.payments_rounded,
            color: const Color(0xFF00838F),
          );
        case _ListEditorMenuAction.toggleMarketOrdering:
          return _ListEditorActionMeta(
            label: marketOrderingEnabled
                ? 'Desativar ordem de mercado'
                : 'Ativar ordem de mercado',
            shortLabel: marketOrderingEnabled ? 'Ordem off' : 'Ordem on',
            icon: marketOrderingEnabled
                ? Icons.storefront_rounded
                : Icons.storefront_outlined,
            color: const Color(0xFF5E35B1),
          );
        case _ListEditorMenuAction.renameList:
          return _ListEditorActionMeta(
            label: 'Renomear lista',
            shortLabel: 'Renomear',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF546E7A),
          );
        case _ListEditorMenuAction.clearPurchased:
          return _ListEditorActionMeta(
            label: 'Limpar comprados',
            shortLabel: 'Limpar',
            icon: Icons.cleaning_services_rounded,
            color: const Color(0xFFC62828),
          );
      }
    }

    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.88, 700),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
        children: [
          Text(
            'Ações da lista',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Tudo em um único menu, com atalhos para as ações principais.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ações rápidas',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickActions
                .map((action) {
                  final meta = resolveMeta(action);
                  return _ListEditorQuickActionCard(
                    meta: meta,
                    onTap: () => Navigator.pop(context, action),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _ListEditorActionSection(
            title: 'Compra',
            actions: purchaseActions,
            resolveMeta: resolveMeta,
            onTap: (action) => Navigator.pop(context, action),
          ),
          if (settingsActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ListEditorActionSection(
              title: 'Configurações',
              actions: settingsActions,
              resolveMeta: resolveMeta,
              onTap: (action) => Navigator.pop(context, action),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListEditorActionSection extends StatelessWidget {
  const _ListEditorActionSection({
    required this.title,
    required this.actions,
    required this.resolveMeta,
    required this.onTap,
  });

  final String title;
  final List<_ListEditorMenuAction> actions;
  final _ListEditorActionMeta Function(_ListEditorMenuAction action)
  resolveMeta;
  final ValueChanged<_ListEditorMenuAction> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.72),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _ListEditorActionTile(
                  meta: resolveMeta(actions[i]),
                  onTap: () => onTap(actions[i]),
                ),
                if (i < actions.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 12,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ListEditorActionTile extends StatelessWidget {
  const _ListEditorActionTile({required this.meta, required this.onTap});

  final _ListEditorActionMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(meta.icon, color: meta.color, size: 18),
        ),
      ),
      title: Text(meta.label),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ListEditorQuickActionCard extends StatelessWidget {
  const _ListEditorQuickActionCard({required this.meta, required this.onTap});

  final _ListEditorActionMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 128),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: meta.color.withValues(alpha: 0.12),
              border: Border.all(color: meta.color.withValues(alpha: 0.26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(meta.icon, color: meta.color),
                const SizedBox(height: 6),
                Text(
                  meta.shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListEditorActionMeta {
  const _ListEditorActionMeta({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
}

class ShoppingListEditorPage extends StatefulWidget {
  const ShoppingListEditorPage({
    super.key,
    required this.store,
    required this.listId,
    this.sharedListsRepository,
  });

  final ShoppingListsStore store;
  final String listId;
  final SharedListsRepository? sharedListsRepository;

  @override
  State<ShoppingListEditorPage> createState() => _ShoppingListEditorPageState();
}

enum _EditorItemsVisibility { pending, all, purchased }

class _ShoppingListEditorPageState extends State<ShoppingListEditorPage> {
  late ShoppingListModel _list;
  bool _notFound = false;
  ItemSortOption _sortOption = ItemSortOption.defaultOrder;
  late final TextEditingController _searchController;
  ShoppingCategory? _categoryFilter;
  bool _marketModeEnabled = false;
  bool _summaryCollapsed = true;
  _EditorItemsVisibility _itemsVisibility = _EditorItemsVisibility.pending;
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

  String get _searchQuery => _searchController.text.trim();
  bool get _isSharedLocked => _linkedSharedSummary != null;
  bool get _isEditingLocked => _list.isClosed;
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _sortOption != ItemSortOption.defaultOrder ||
      _categoryFilter != null ||
      _marketModeEnabled ||
      _itemsVisibility != _EditorItemsVisibility.pending;

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
            _EditorItemsVisibility.pending => !item.isPurchased,
            _EditorItemsVisibility.all => true,
            _EditorItemsVisibility.purchased => item.isPurchased,
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

  void _setItemsVisibility(_EditorItemsVisibility visibility) {
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
      debugPrint('[share_flow] resolveSharedLink error=$error');
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
    if (sourceLocalId.isNotEmpty && sourceLocalId != _list.id) {
      return;
    }
    if (_isSyncingToShared) {
      return;
    }
    if (_list.updatedAt.isAfter(summary.updatedAt)) {
      unawaited(_syncLocalChangesToShared(_list));
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
    unawaited(widget.store.upsertList(updated));
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
      await widget.store.upsertList(mirrored);
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
  }) async {
    final repository = widget.sharedListsRepository;
    final shared = _linkedSharedSummary;
    if (repository == null || shared == null) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      return;
    }
    final sourceLocalId = shared.sourceLocalListId?.trim() ?? '';
    if (sourceLocalId.isNotEmpty && sourceLocalId != updated.id) {
      return;
    }
    if (_isSyncingToShared) {
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

  ShoppingItem _shoppingItemFromDraft(ShoppingItemDraft draft) {
    return ShoppingItem(
      id: uniqueId(),
      name: draft.name,
      quantity: draft.quantity,
      unitPrice: draft.unitPrice,
      barcode: draft.barcode,
      category: draft.category,
      isPurchased: draft.isPurchased,
      priceHistory: [
        PriceHistoryEntry(price: draft.unitPrice, recordedAt: DateTime.now()),
      ],
    );
  }

  Future<void> _importFromFiscalReceipt() async {
    if (!_ensureEditable()) {
      return;
    }

    final drafts = await showFiscalReceiptImportSheet(context);
    if (!mounted || drafts == null || drafts.isEmpty) {
      return;
    }

    final items = [..._list.items];
    var addedCount = 0;
    var mergedCount = 0;

    for (final draft in drafts) {
      final normalizedDraftName = normalizeQuery(draft.name);
      if (normalizedDraftName.isEmpty) {
        continue;
      }

      final index = items.indexWhere(
        (item) => normalizeQuery(item.name) == normalizedDraftName,
      );
      if (index == -1) {
        items.add(
          ShoppingItem(
            id: uniqueId(),
            name: draft.name,
            quantity: draft.quantity,
            unitPrice: draft.unitPrice,
            category: draft.category,
            priceHistory: [
              PriceHistoryEntry(
                price: draft.unitPrice,
                recordedAt: DateTime.now(),
              ),
            ],
          ),
        );
        addedCount++;
      } else {
        final existing = items[index];
        final history = [...existing.priceHistory];
        if (history.isEmpty) {
          history.add(
            PriceHistoryEntry(
              price: existing.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }
        if ((history.last.price - draft.unitPrice).abs() > 0.0001) {
          history.add(
            PriceHistoryEntry(
              price: draft.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }
        items[index] = existing.copyWith(
          quantity: existing.quantity + draft.quantity,
          unitPrice: draft.unitPrice,
          category: draft.category,
          priceHistory: history,
        );
        mergedCount++;
      }

      unawaited(widget.store.saveDraftToCatalog(draft));
    }

    if (addedCount == 0 && mergedCount == 0) {
      _showSnack('Nenhum item válido foi extraído do cupom.');
      return;
    }

    _updateList(
      _list.copyWith(items: items),
      message:
          'Cupom importado: ${formatCountLabel(addedCount, 'novo', 'novos')}, ${formatCountLabel(mergedCount, 'atualizado', 'atualizados')}.',
    );
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
    final action = await showAppModalBottomSheet<_ListItemSwipeQuickAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Editar item'),
                  onTap: () =>
                      Navigator.pop(context, _ListItemSwipeQuickAction.edit),
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Duplicar item'),
                  onTap: () => Navigator.pop(
                    context,
                    _ListItemSwipeQuickAction.duplicate,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('Excluir item'),
                  onTap: () =>
                      Navigator.pop(context, _ListItemSwipeQuickAction.delete),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _ListItemSwipeQuickAction.edit:
        await _openItemForm(existing: item);
        return;
      case _ListItemSwipeQuickAction.duplicate:
        _duplicateItem(item);
        return;
      case _ListItemSwipeQuickAction.delete:
        await _deleteItem(item);
        return;
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    if (!_ensureEditable()) {
      return;
    }
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text('Deseja remover "${item.name}" da lista?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

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
    await showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return _PriceHistorySheet(item: item);
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
  }) {
    AppToast.show(context, message: message, type: type, duration: duration);
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
      _list.copyWith(budget: value),
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
    _logShare(
      'click share listId=${_list.id} name="${_list.name}" items=${_list.items.length}',
    );
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
      _logShare('createOrGetSharedListFromLocal start uid=$uid');
      final sharedList = await repository.createOrGetSharedListFromLocal(
        localList: _list,
        ownerUid: uid,
      );
      _logShare(
        'createOrGetSharedListFromLocal ok sharedId=${sharedList.id} invite=${sharedList.inviteCode ?? '-'}',
      );
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
          _logShare('open shared list id=${sharedList.id}');
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
        _logShare('share error FirebaseException');
        developer.log(
          'FirebaseException while sharing list.',
          name: 'share_flow',
          error: error,
        );
      } else {
        _logShare('share error');
        developer.log(
          'Unexpected error while sharing list.',
          name: 'share_flow',
          error: error,
        );
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
        builder: (_) => ShoppingMarketModePage(initialList: _list),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    _updateList(updated, message: 'Modo compra atualizado com sucesso.');
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
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

  Future<void> _finalizePurchase() async {
    if (_list.isClosed) {
      _showSnack('A lista já está fechada. Toque em reabrir para editar.');
      return;
    }
    if (_list.items.isEmpty) {
      _showSnack('Adicione itens antes de fechar a compra.');
      return;
    }

    final checkout = await showPurchaseCheckoutDialog(context, list: _list);
    if (!mounted || checkout == null) {
      return;
    }

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
        );
        await _syncLinkedSharedNow(showSnack: true);
        _showSnack('Compra fechada e salva no histórico compartilhado.');
      } catch (error) {
        _showSnack('Não foi possível fechar a lista. Tente novamente.');
      }
      return;
    }

    final didFinalize =
        await widget.store.finalizeList(
          _list.id,
          markPendingAsPurchased: checkout.markPendingAsPurchased,
        ) !=
        null;
    if (!mounted || !didFinalize) {
      return;
    }
    _showSnack('Compra fechada e salva no histórico mensal.');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _sortOption = ItemSortOption.defaultOrder;
      _categoryFilter = null;
      _marketModeEnabled = false;
      _itemsVisibility = _EditorItemsVisibility.pending;
    });
  }

  void _handleAppBarMenuAction(_ListEditorMenuAction action) {
    switch (action) {
      case _ListEditorMenuAction.reopenList:
        _reopenListForEditing();
        return;
      case _ListEditorMenuAction.openSharedList:
        _openLinkedSharedList();
        return;
      case _ListEditorMenuAction.syncSharedNow:
        unawaited(_syncLocalChangesToShared(_list));
        _syncLinkedSharedNow(showSnack: true);
        return;
      case _ListEditorMenuAction.shareList:
        _shareListWithCode();
        return;
      case _ListEditorMenuAction.importFiscalReceipt:
        _importFromFiscalReceipt();
        return;
      case _ListEditorMenuAction.finalizePurchase:
        _finalizePurchase();
        return;
      case _ListEditorMenuAction.openMarketMode:
        _openMarketShoppingMode();
        return;
      case _ListEditorMenuAction.openCatalog:
        _openCatalogPage();
        return;
      case _ListEditorMenuAction.viewHistory:
        _openPurchaseHistory();
        return;
      case _ListEditorMenuAction.editReminder:
        _openReminderEditor();
        return;
      case _ListEditorMenuAction.editBudget:
        _openBudgetEditor();
        return;
      case _ListEditorMenuAction.editPaymentBalances:
        _openPaymentBalancesEditor();
        return;
      case _ListEditorMenuAction.toggleMarketOrdering:
        setState(() {
          _marketModeEnabled = !_marketModeEnabled;
        });
        return;
      case _ListEditorMenuAction.renameList:
        _renameList();
        return;
      case _ListEditorMenuAction.clearPurchased:
        _clearPurchased();
        return;
    }
  }

  Future<void> _showListActionsSheet() async {
    final selected = await showAppModalBottomSheet<_ListEditorMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return _ListEditorActionsSheet(
          isClosed: _list.isClosed,
          isSharedLocked: _isSharedLocked,
          hasReminder: _list.reminder != null,
          hasPurchasedItems: _list.purchasedItemsCount > 0,
          marketOrderingEnabled: _marketModeEnabled,
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          IconButton(
            tooltip: 'Ações da lista',
            onPressed: _showListActionsSheet,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      floatingActionButton: _isEditingLocked
          ? null
          : FloatingActionButton.extended(
              onPressed: _openItemForm,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Adicionar item'),
            ),
      body: AppGradientScene(
        child: SafeArea(
          child: Column(
            children: [
              if (linkedShared != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Card(
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.group_work_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lista compartilhada detectada',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Abra a versão compartilhada para ver '
                                  'atualizações em tempo real.',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
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
                                onPressed: _openSharedInviteSheetFromLocal,
                                child: const Text('Gerenciar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: _ListSummaryPanel(
                  list: _list,
                  collapsed: _summaryCollapsed,
                  onBudgetTap: _isEditingLocked
                      ? () => _ensureEditable()
                      : _openBudgetEditor,
                  onReminderTap: _isEditingLocked
                      ? () => _ensureEditable()
                      : _openReminderEditor,
                  onPaymentBalancesTap: _isEditingLocked
                      ? () => _ensureEditable()
                      : _openPaymentBalancesEditor,
                  onReopenTap: _list.isClosed ? _reopenListForEditing : null,
                  onToggleCollapsed: () {
                    setState(() {
                      _summaryCollapsed = !_summaryCollapsed;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _ItemsToolsBar(
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
              if (_itemsVisibility == _EditorItemsVisibility.pending &&
                  _purchasedItemsCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: EditorInlineInfoBanner(
                    icon: Icons.visibility_outlined,
                    message: _purchasedItemsCount == 1
                        ? '1 item comprado oculto para deixar a lista mais objetiva.'
                        : '$_purchasedItemsCount itens comprados ocultos para deixar a lista mais objetiva.',
                    actionLabel: 'Ver',
                    onAction: () =>
                        _setItemsVisibility(_EditorItemsVisibility.purchased),
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _list.items.isEmpty
                      ? const _EmptyItemsState()
                      : visibleItems.isEmpty
                      ? _EmptySearchState(
                          query: _searchQuery,
                          visibilityFilter: _itemsVisibility,
                          onClearFilters: _clearFilters,
                          onShowPending: () => _setItemsVisibility(
                            _EditorItemsVisibility.pending,
                          ),
                          onShowPurchased: () => _setItemsVisibility(
                            _EditorItemsVisibility.purchased,
                          ),
                          onShowAll: () =>
                              _setItemsVisibility(_EditorItemsVisibility.all),
                        )
                      : ListView.separated(
                          key: ValueKey(
                            '${_list.id}-${_sortOption.name}-$_marketModeEnabled-${_categoryFilter?.key ?? 'all'}',
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: visibleItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
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
                                child: _ShoppingItemCard(
                                  item: item,
                                  readOnly: _isEditingLocked,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListSummaryPanel extends StatelessWidget {
  const _ListSummaryPanel({
    required this.list,
    required this.collapsed,
    required this.onBudgetTap,
    required this.onReminderTap,
    required this.onPaymentBalancesTap,
    required this.onToggleCollapsed,
    this.onReopenTap,
  });

  final ShoppingListModel list;
  final bool collapsed;
  final VoidCallback onBudgetTap;
  final VoidCallback onReminderTap;
  final VoidCallback onPaymentBalancesTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onReopenTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final purchasedCount = list.purchasedItemsCount;
    final pendingCount = max(0, list.items.length - purchasedCount);
    final compactSummary =
        '${list.totalItems} itens • ${formatCurrency(list.totalValue)}';
    final statusParts = <String>[
      '$pendingCount pendentes',
      '$purchasedCount comprados',
      if (list.hasBudget)
        list.isOverBudget
            ? 'Excesso ${formatCurrency(list.overBudgetAmount)}'
            : 'Saldo ${formatCurrency(max(0, list.budgetRemaining))}',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
          width: AppTokens.cardBorderWidth,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: !collapsed,
            label: 'Resumo da lista',
            hint: collapsed
                ? 'Toque para expandir o resumo'
                : 'Toque para recolher o resumo',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleCollapsed();
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  collapsed ? AppTokens.spaceMd : AppTokens.spaceSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo da lista',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            compactSummary,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusParts.join(' • '),
                            maxLines: collapsed ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              collapsed ? 'Abrir' : 'Fechar',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              duration: _editorAdaptiveMotionDuration(
                                context,
                                AppTokens.motionMedium,
                              ),
                              turns: collapsed ? 0 : 0.5,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: _editorAdaptiveMotionDuration(
                context,
                AppTokens.motionMedium,
              ),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: collapsed ? 0 : 1,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  0,
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (list.isClosed) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Compra fechada. Reabra para editar itens.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (onReopenTap != null)
                                TextButton(
                                  onPressed: onReopenTap,
                                  child: const Text('Reabrir'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Valor, quantidade e status atualizados em tempo real.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EditorMetricTag(
                          icon: Icons.attach_money_rounded,
                          label: 'Total',
                          value: formatCurrency(list.totalValue),
                        ),
                        _EditorMetricTag(
                          icon: Icons.inventory_2_rounded,
                          label: 'Itens',
                          value: '',
                        ),
                        _EditorMetricTag(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pendentes',
                          value: formatCurrency(list.pendingValue),
                        ),
                        _EditorMetricTag(
                          icon: Icons.check_circle_rounded,
                          label: 'Comprados',
                          value: '',
                        ),
                        _EditorMetricTag(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Orçamento disponível',
                          value: list.hasBudget
                              ? formatCurrency(max(0, list.budgetRemaining))
                              : 'Não definido',
                          onTap: onBudgetTap,
                        ),
                        _EditorMetricTag(
                          icon: Icons.payments_rounded,
                          label: 'Saldos',
                          value: list.hasPaymentBalances
                              ? formatCurrency(list.paymentBalancesTotal)
                              : 'Não definido',
                          onTap: onPaymentBalancesTap,
                        ),
                        _EditorMetricTag(
                          icon: list.reminder == null
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_active_rounded,
                          label: 'Lembrete',
                          value: list.reminder == null
                              ? 'Desligado'
                              : formatDateTime(list.reminder!.scheduledAt),
                          onTap: onReminderTap,
                        ),
                        if (list.hasBudget)
                          _EditorMetricTag(
                            icon: list.isOverBudget
                                ? Icons.warning_amber_rounded
                                : Icons.savings_rounded,
                            label: list.isOverBudget ? 'Excesso' : 'Saldo',
                            value: list.isOverBudget
                                ? formatCurrency(list.overBudgetAmount)
                                : formatCurrency(list.budgetRemaining),
                          ),
                        if (list.hasPaymentBalances)
                          _EditorMetricTag(
                            icon: list.uncoveredAmount > 0
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_rounded,
                            label: list.uncoveredAmount > 0
                                ? 'Falta pagar'
                                : 'Coberto',
                            value: list.uncoveredAmount > 0
                                ? formatCurrency(list.uncoveredAmount)
                                : formatCurrency(list.coveredAmount),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EditorQuickSummaryActionChip(
                          icon: Icons.account_balance_wallet_rounded,
                          label: list.hasBudget
                              ? 'Editar orçamento'
                              : 'Definir orçamento',
                          onTap: onBudgetTap,
                        ),
                        _EditorQuickSummaryActionChip(
                          icon: Icons.payments_rounded,
                          label: list.hasPaymentBalances
                              ? 'Editar saldos'
                              : 'Definir saldos',
                          onTap: onPaymentBalancesTap,
                        ),
                        _EditorQuickSummaryActionChip(
                          icon: list.reminder == null
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_active_rounded,
                          label: list.reminder == null
                              ? 'Definir lembrete'
                              : 'Editar lembrete',
                          onTap: onReminderTap,
                        ),
                      ],
                    ),
                    if (list.hasPaymentBalances) ...[
                      const SizedBox(height: 12),
                      _PaymentBalancesUsagePanel(list: list),
                    ],
                    if (list.isOverBudget) ...[
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Valor total acima do orçamento por .',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditorMetricTag extends StatelessWidget {
  const _EditorMetricTag({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = _editorAdaptiveMotionDuration(
      context,
      AppTokens.motionMedium,
    );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: AnimatedSwitcher(
          duration: motionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: ConstrainedBox(
            key: ValueKey('$label|$value'),
            constraints: const BoxConstraints(maxWidth: 260),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17),
                const SizedBox(width: 7),
                Flexible(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: '$label: '),
                        TextSpan(
                          text: value,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        onTap: () {
          Feedback.forTap(context);
          onTap?.call();
        },
        child: content,
      ),
    );
  }
}

class _EditorQuickSummaryActionChip extends StatelessWidget {
  const _EditorQuickSummaryActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          Feedback.forTap(context);
          onTap();
        },
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class _PaymentBalancesUsagePanel extends StatelessWidget {
  const _PaymentBalancesUsagePanel({required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = list.paymentUsage
        .where((entry) => entry.balance.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surface.withValues(alpha: 0.68),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consumo por prioridade',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final progress = entry.balance.value <= 0
                  ? 0.0
                  : (entry.consumed / entry.balance.value)
                        .clamp(0.0, 1.0)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.balance.name} (${entry.balance.type.label})',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${formatCurrency(entry.consumed)} / ${formatCurrency(entry.balance.value)}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isExhausted
                          ? 'Saldo esgotado.'
                          : 'Restante: ${formatCurrency(entry.remaining)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.isExhausted
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (list.uncoveredAmount > 0)
              Text(
                'Total sem cobertura de saldo: ${formatCurrency(list.uncoveredAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemsToolsBar extends StatelessWidget {
  const _ItemsToolsBar({
    required this.controller,
    required this.selectedSort,
    required this.selectedCategory,
    required this.visibilityFilter,
    required this.marketModeEnabled,
    required this.visibleCount,
    required this.totalCount,
    required this.pendingCount,
    required this.purchasedCount,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onCategoryChanged,
    required this.onVisibilityChanged,
    required this.onClearFilters,
  });

  final TextEditingController controller;
  final ItemSortOption selectedSort;
  final ShoppingCategory? selectedCategory;
  final _EditorItemsVisibility visibilityFilter;
  final bool marketModeEnabled;
  final int visibleCount;
  final int totalCount;
  final int pendingCount;
  final int purchasedCount;
  final bool hasActiveFilters;
  final ValueChanged<ItemSortOption> onSortChanged;
  final ValueChanged<ShoppingCategory?> onCategoryChanged;
  final ValueChanged<_EditorItemsVisibility> onVisibilityChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Buscar produto',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: controller.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<ItemSortOption>(
                  tooltip: 'Ordenar itens',
                  onSelected: onSortChanged,
                  itemBuilder: (context) {
                    return [
                      for (final option in ItemSortOption.values)
                        CheckedPopupMenuItem<ItemSortOption>(
                          value: option,
                          checked: option == selectedSort,
                          child: Text(option.label),
                        ),
                    ];
                  },
                  child: _SortTag(option: selectedSort),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter
                    in <
                      ({String label, int count, _EditorItemsVisibility value})
                    >[
                      (
                        label: 'Pendentes',
                        count: pendingCount,
                        value: _EditorItemsVisibility.pending,
                      ),
                      (
                        label: 'Todos',
                        count: totalCount,
                        value: _EditorItemsVisibility.all,
                      ),
                      (
                        label: 'Comprados',
                        count: purchasedCount,
                        value: _EditorItemsVisibility.purchased,
                      ),
                    ])
                  ChoiceChip(
                    selected: visibilityFilter == filter.value,
                    showCheckmark: false,
                    label: Text('${filter.label} ${filter.count}'),
                    avatar: Icon(switch (filter.value) {
                      _EditorItemsVisibility.pending =>
                        Icons.pending_actions_rounded,
                      _EditorItemsVisibility.all =>
                        Icons.format_list_bulleted_rounded,
                      _EditorItemsVisibility.purchased =>
                        Icons.check_circle_rounded,
                    }, size: 16),
                    onSelected: (_) => onVisibilityChanged(filter.value),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CategoryFilterChip(
                  selectedCategory: selectedCategory,
                  onSelected: onCategoryChanged,
                ),
                if (marketModeEnabled)
                  Chip(
                    avatar: const Icon(Icons.storefront_rounded, size: 18),
                    label: const Text('Modo compra ativo'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '$visibleCount de ${formatItemCount(totalCount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasActiveFilters)
                  TextButton.icon(
                    onPressed: onClearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded),
                    label: const Text('Limpar'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.selectedCategory,
    required this.onSelected,
  });

  static const String _allCategoriesMenuValue = '__all_categories__';

  final ShoppingCategory? selectedCategory;
  final ValueChanged<ShoppingCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filtrar categoria',
      onSelected: (value) {
        if (value == _allCategoriesMenuValue) {
          onSelected(null);
          return;
        }
        for (final category in ShoppingCategory.values) {
          if (category.key == value) {
            onSelected(category);
            return;
          }
        }
      },
      itemBuilder: (context) {
        return [
          CheckedPopupMenuItem<String>(
            value: _allCategoriesMenuValue,
            checked: selectedCategory == null,
            child: const Text('Todas as categorias'),
          ),
          ...ShoppingCategory.values.map(
            (category) => CheckedPopupMenuItem<String>(
              value: category.key,
              checked: selectedCategory == category,
              child: Row(
                children: [
                  Icon(category.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(category.label),
                ],
              ),
            ),
          ),
        ];
      },
      child: Chip(
        avatar: Icon(
          selectedCategory?.icon ?? Icons.category_rounded,
          size: 18,
        ),
        label: Text(
          selectedCategory == null
              ? 'Categoria: todas'
              : 'Categoria: ${selectedCategory!.label}',
        ),
      ),
    );
  }
}

class _SortTag extends StatelessWidget {
  const _SortTag({required this.option});

  final ItemSortOption option;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 18),
            const SizedBox(width: 6),
            Text(option.shortLabel),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

enum _ShoppingItemCardAction { delete }

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    this.readOnly = false,
    required this.onPurchasedChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onViewHistory,
    required this.onDelete,
  });

  final ShoppingItem item;
  final bool readOnly;
  final ValueChanged<bool?> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPurchased = item.isPurchased;
    final statusLabel = isPurchased ? 'Comprado' : 'Pendente';
    final barcodeLabel = item.barcode?.trim();
    final metaLabel = '$statusLabel • ${item.category.label}';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: _editorAdaptiveMotionDuration(context, AppTokens.motionFast),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: isPurchased
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surface,
          border: Border.all(
            color: isPurchased
                ? colorScheme.primary.withValues(alpha: 0.45)
                : colorScheme.outlineVariant.withValues(alpha: 0.56),
          ),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: isPurchased,
                  onChanged: readOnly ? null : onPurchasedChanged,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Opacity(
                    opacity: isPurchased ? 0.7 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: isPurchased
                                ? TextDecoration.lineThrough
                                : null,
                            decorationThickness: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$metaLabel • ${item.quantity} x ${formatCurrency(item.unitPrice)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (barcodeLabel != null &&
                            barcodeLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            barcodeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Subtotal',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      formatCurrency(item.subtotal),
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.52),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: readOnly
                              ? null
                              : (item.quantity > 1 ? onDecrement : null),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 24),
                          child: Text(
                            '${item.quantity}',
                            textAlign: TextAlign.center,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: readOnly ? null : onIncrement,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                Icon(
                  isPurchased
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: isPurchased
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 5),
                Text(
                  statusLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!readOnly)
                  IconButton(
                    tooltip: 'Editar',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_rounded),
                  ),
                IconButton(
                  tooltip: 'Histórico de preço',
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.query_stats_rounded),
                ),
                if (!readOnly)
                  PopupMenuButton<_ShoppingItemCardAction>(
                    tooltip: 'Mais ações',
                    onSelected: (action) {
                      if (action == _ShoppingItemCardAction.delete) {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) =>
                        const <PopupMenuEntry<_ShoppingItemCardAction>>[
                          PopupMenuItem<_ShoppingItemCardAction>(
                            value: _ShoppingItemCardAction.delete,
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, size: 18),
                                SizedBox(width: 10),
                                Text('Excluir item'),
                              ],
                            ),
                          ),
                        ],
                    icon: const Icon(Icons.more_horiz_rounded),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceHistorySheet extends StatelessWidget {
  const _PriceHistorySheet({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final history = [...item.priceHistory]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
      children: [
        Text(
          'Histórico de preços',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          item.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const ListTile(title: Text('Sem histórico registrado ainda.'))
        else
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final previous = index + 1 < history.length
                ? history[index + 1]
                : null;
            final delta = previous == null
                ? null
                : record.price - previous.price;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EditorContentPanel(
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatCurrency(record.price),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(record.recordedAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      delta == null
                          ? 'Inicial'
                          : '${delta >= 0 ? '+' : '-'} ${formatCurrency(delta.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: delta == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : delta > 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.query,
    required this.visibilityFilter,
    required this.onClearFilters,
    required this.onShowPending,
    required this.onShowPurchased,
    required this.onShowAll,
  });

  final String query;
  final _EditorItemsVisibility visibilityFilter;
  final VoidCallback onClearFilters;
  final VoidCallback onShowPending;
  final VoidCallback onShowPurchased;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      key: const ValueKey('empty-search-results'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max(0, constraints.maxHeight - 48),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 80,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhum produto encontrado',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum item corresponde a "$query".',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Limpar filtros'),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    if (visibilityFilter != _EditorItemsVisibility.pending)
                      OutlinedButton.icon(
                        onPressed: onShowPending,
                        icon: const Icon(Icons.pending_actions_rounded),
                        label: const Text('Ver pendentes'),
                      ),
                    if (visibilityFilter != _EditorItemsVisibility.purchased)
                      OutlinedButton.icon(
                        onPressed: onShowPurchased,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Ver comprados'),
                      ),
                    if (visibilityFilter != _EditorItemsVisibility.all)
                      OutlinedButton.icon(
                        onPressed: onShowAll,
                        icon: const Icon(Icons.format_list_bulleted_rounded),
                        label: const Text('Ver todos'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      key: const ValueKey('empty-items'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max(0, constraints.maxHeight - 52),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 92,
                    color: colorScheme.primary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Esta lista está vazia',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Adicione o primeiro produto e acompanhe subtotal e total automáticos.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Use o botão "Adicionar item" para incluir o primeiro produto.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Duration _editorAdaptiveMotionDuration(
  BuildContext context,
  Duration fallback,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}
