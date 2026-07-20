import 'dart:async';

import 'package:flutter/material.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import '../domain/pantry.dart';
import 'dialogs_and_sheets.dart';
import 'extensions/classification_ui_extensions.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

extension PantryStockStatusUi on PantryStockStatus {
  String get label {
    return switch (this) {
      PantryStockStatus.inStock => 'Tenho',
      PantryStockStatus.runningLow => 'Está acabando',
      PantryStockStatus.outOfStock => 'Acabou',
    };
  }

  String get description {
    return switch (this) {
      PantryStockStatus.inStock => 'Ainda há produto em casa',
      PantryStockStatus.runningLow => 'Inclua na próxima compra',
      PantryStockStatus.outOfStock => 'Precisa comprar agora',
    };
  }

  IconData get icon {
    return switch (this) {
      PantryStockStatus.inStock => Icons.check_circle_outline_rounded,
      PantryStockStatus.runningLow => Icons.timelapse_rounded,
      PantryStockStatus.outOfStock => Icons.remove_shopping_cart_rounded,
    };
  }
}

class PantryPage extends StatefulWidget {
  const PantryPage({super.key, required this.store});

  final ShoppingListsStore store;

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  final TextEditingController _searchController = TextEditingController();
  PantryStockStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  List<PantryItem> _visibleItems(List<PantryItem> items) {
    final query = normalizeQuery(_searchController.text);
    final visible = items
        .where((item) {
          final matchesStatus =
              _statusFilter == null || item.status == _statusFilter;
          final searchable = normalizeQuery(
            '${item.name} ${item.category.label} ${item.barcode ?? ''}',
          );
          return matchesStatus && (query.isEmpty || searchable.contains(query));
        })
        .toList(growable: false);
    visible.sort((a, b) {
      final byStatus = b.status.index.compareTo(a.status.index);
      if (byStatus != 0) {
        return byStatus;
      }
      return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
    });
    return visible;
  }

  Future<void> _chooseStatus(PantryItem item) async {
    final selected = await showAppModalBottomSheet<PantryStockStatus>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _PantryStatusSheet(item: item),
    );
    if (selected == null || selected == item.status) {
      return;
    }
    await widget.store.setPantryStatus(item.id, selected);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: '${item.name}: ${selected.label.toLowerCase()}.',
      type: AppToastType.success,
    );
  }

  Future<void> _addFromCatalog() async {
    final selected = await showAppModalBottomSheet<CatalogProduct>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _PantryCatalogPicker(
        products: widget.store.catalogProducts,
        pantryItems: widget.store.pantryItems,
      ),
    );
    if (selected == null) {
      return;
    }
    await widget.store.addCatalogProductToPantry(selected);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: '${selected.name} foi adicionado à despensa.',
      type: AppToastType.success,
    );
  }

  Future<ShoppingListModel?> _selectTargetList() async {
    final openLists =
        widget.store.lists
            .where((list) => !list.isClosed)
            .toList(growable: false)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (openLists.length == 1) {
      return openLists.single;
    }
    if (openLists.isEmpty) {
      final name = await showListNameDialog(
        context,
        title: 'Criar lista para reposição',
        confirmLabel: 'Criar lista',
        initialValue: 'Reposição da despensa',
      );
      if (!mounted || name == null) {
        return null;
      }
      return widget.store.createList(name: name);
    }
    return showAppModalBottomSheet<ShoppingListModel>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => _OpenListPicker(lists: openLists),
    );
  }

  Future<void> _addToShoppingList(PantryItem item) async {
    final target = await _selectTargetList();
    if (!mounted || target == null) {
      return;
    }
    final result = await widget.store.addPantryItemToList(
      pantryItemId: item.id,
      listId: target.id,
    );
    if (!mounted || result == null) {
      return;
    }
    AppToast.show(
      context,
      message: result.merged
          ? '${item.name} já estava em ${target.name}; a quantidade foi aumentada.'
          : '${item.name} foi adicionado a ${target.name}.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _removeItem(PantryItem item) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover da despensa?'),
        content: Text(
          '${item.name} deixará de aparecer no acompanhamento de reposição.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await widget.store.removePantryItem(item.id);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: '${item.name} foi removido da despensa.',
      type: AppToastType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Despensa')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFromCatalog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar produto'),
      ),
      body: AppGradientScene(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: widget.store,
            builder: (context, _) {
              final items = widget.store.pantryItems;
              final visible = _visibleItems(items);
              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 780),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PantryOverview(
                                items: items,
                                selectedStatus: _statusFilter,
                                onStatusSelected: (status) {
                                  setState(() {
                                    _statusFilter = _statusFilter == status
                                        ? null
                                        : status;
                                  });
                                },
                              ),
                              const SizedBox(height: AppTokens.spaceMd),
                              TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  hintText: 'Buscar produto na despensa',
                                  suffixIcon:
                                      _searchController.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: 'Limpar busca',
                                          onPressed: _searchController.clear,
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                              const SizedBox(height: AppTokens.spaceMd),
                              _PantryResultsHeader(
                                visibleCount: visible.length,
                                totalCount: items.length,
                                hasFilter:
                                    _statusFilter != null ||
                                    _searchController.text.trim().isNotEmpty,
                                onClearFilters: () {
                                  _searchController.clear();
                                  setState(() {
                                    _statusFilter = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (visible.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _PantryEmptyState(
                        hasItems: items.isNotEmpty,
                        onAdd: _addFromCatalog,
                        onClearFilters: () {
                          _searchController.clear();
                          setState(() {
                            _statusFilter = null;
                          });
                        },
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppTokens.spaceSm),
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 780),
                              child: _PantryItemRow(
                                item: item,
                                onStatusTap: () => _chooseStatus(item),
                                onAddToList: item.needsRestock
                                    ? () => _addToShoppingList(item)
                                    : null,
                                onRemove: () => _removeItem(item),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PantryOverview extends StatelessWidget {
  const _PantryOverview({
    required this.items,
    required this.selectedStatus,
    required this.onStatusSelected,
  });

  final List<PantryItem> items;
  final PantryStockStatus? selectedStatus;
  final ValueChanged<PantryStockStatus> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final attentionCount = items.where((item) => item.needsRestock).length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: AppTokens.radius(AppTokens.radiusXl),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attentionCount == 0
                  ? 'Tudo em ordem'
                  : '$attentionCount para repor',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppTokens.spaceXs),
            Text(
              attentionCount == 0
                  ? 'Atualize o estado quando algum produto estiver acabando.'
                  : 'Revise o que está acabando ou acabou antes da próxima compra.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppTokens.spaceLg),
            Row(
              children: PantryStockStatus.values
                  .map((status) {
                    final count = items
                        .where((item) => item.status == status)
                        .length;
                    return Expanded(
                      child: _PantryStatusMetric(
                        status: status,
                        count: count,
                        selected: selectedStatus == status,
                        onTap: () => onStatusSelected(status),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryStatusMetric extends StatelessWidget {
  const _PantryStatusMetric({
    required this.status,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final PantryStockStatus status;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${status.label}: $count',
      child: InkWell(
        borderRadius: AppTokens.radius(AppTokens.radiusLg),
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppTokens.motionFast,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colorScheme.primaryContainer : Colors.transparent,
            borderRadius: AppTokens.radius(AppTokens.radiusLg),
          ),
          child: Column(
            children: [
              Icon(
                status.icon,
                size: 20,
                color: selected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantryResultsHeader extends StatelessWidget {
  const _PantryResultsHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.hasFilter,
    required this.onClearFilters,
  });

  final int visibleCount;
  final int totalCount;
  final bool hasFilter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            hasFilter
                ? '$visibleCount de ${formatCountLabel(totalCount, 'produto', 'produtos')}'
                : formatCountLabel(totalCount, 'produto', 'produtos'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (hasFilter)
          TextButton(
            onPressed: onClearFilters,
            child: const Text('Limpar filtros'),
          ),
      ],
    );
  }
}

class _PantryItemRow extends StatelessWidget {
  const _PantryItemRow({
    required this.item,
    required this.onStatusTap,
    required this.onAddToList,
    required this.onRemove,
  });

  final PantryItem item;
  final VoidCallback onStatusTap;
  final VoidCallback? onAddToList;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = <String>[
      item.category.label,
      if ((item.unitPrice ?? 0) > 0) formatCurrency(item.unitPrice!),
      if (item.lastPurchasedAt != null)
        'Comprado em ${formatShortDate(item.lastPurchasedAt!)}',
    ];
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppTokens.radius(AppTokens.radiusLg),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.6),
                borderRadius: AppTokens.radius(AppTokens.radiusMd),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  item.category.icon,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppTokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    details.join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTokens.spaceSm),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ActionChip(
                        avatar: Icon(item.status.icon, size: 17),
                        label: Text(item.status.label),
                        onPressed: onStatusTap,
                      ),
                      if (onAddToList != null)
                        TextButton.icon(
                          onPressed: onAddToList,
                          icon: const Icon(
                            Icons.playlist_add_rounded,
                            size: 19,
                          ),
                          label: const Text('Adicionar à lista'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'remove') {
                  onRemove();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'remove', child: Text('Remover')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryEmptyState extends StatelessWidget {
  const _PantryEmptyState({
    required this.hasItems,
    required this.onAdd,
    required this.onClearFilters,
  });

  final bool hasItems;
  final VoidCallback onAdd;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                hasItems ? Icons.search_off_rounded : Icons.kitchen_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: AppTokens.spaceLg),
              Text(
                hasItems
                    ? 'Nenhum produto encontrado'
                    : 'Sua despensa está vazia',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                hasItems
                    ? 'Limpe os filtros para ver todos os produtos.'
                    : 'Adicione produtos do catálogo ou finalize uma compra para começar o acompanhamento.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTokens.spaceLg),
              FilledButton.icon(
                onPressed: hasItems ? onClearFilters : onAdd,
                icon: Icon(
                  hasItems ? Icons.filter_alt_off_rounded : Icons.add_rounded,
                ),
                label: Text(hasItems ? 'Limpar filtros' : 'Adicionar produto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantryStatusSheet extends StatelessWidget {
  const _PantryStatusSheet({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Como está ${item.name}?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          for (final status in PantryStockStatus.values)
            ListTile(
              leading: Icon(status.icon),
              title: Text(status.label),
              subtitle: Text(status.description),
              trailing: item.status == status
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, status),
            ),
        ],
      ),
    );
  }
}

class _PantryCatalogPicker extends StatefulWidget {
  const _PantryCatalogPicker({
    required this.products,
    required this.pantryItems,
  });

  final List<CatalogProduct> products;
  final List<PantryItem> pantryItems;

  @override
  State<_PantryCatalogPicker> createState() => _PantryCatalogPickerState();
}

class _PantryCatalogPickerState extends State<_PantryCatalogPicker> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pantryCatalogIds = widget.pantryItems
        .map((item) => item.catalogProductId)
        .whereType<String>()
        .toSet();
    final pantryNames = widget.pantryItems
        .map((item) => normalizeQuery(item.name))
        .toSet();
    final query = normalizeQuery(_controller.text);
    final products =
        widget.products
            .where(
              (product) =>
                  !pantryCatalogIds.contains(product.id) &&
                  !pantryNames.contains(normalizeQuery(product.name)),
            )
            .where(
              (product) =>
                  query.isEmpty ||
                  normalizeQuery(
                    '${product.name} ${product.category.label} ${product.barcode ?? ''}',
                  ).contains(query),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => normalizeQuery(a.name).compareTo(normalizeQuery(b.name)),
          );

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Adicionar do catálogo',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar produto no catálogo',
              ),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            Expanded(
              child: products.isEmpty
                  ? Center(
                      child: Text(
                        widget.products.isEmpty
                            ? 'O catálogo ainda está vazio. Finalize uma compra para salvar produtos automaticamente.'
                            : 'Todos os produtos encontrados já estão na despensa.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return ListTile(
                          leading: Icon(product.category.icon),
                          title: Text(product.name),
                          subtitle: Text(
                            [
                              product.category.label,
                              if ((product.unitPrice ?? 0) > 0)
                                formatCurrency(product.unitPrice!),
                            ].join(' • '),
                          ),
                          trailing: const Icon(Icons.add_rounded),
                          onTap: () => Navigator.pop(context, product),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenListPicker extends StatelessWidget {
  const _OpenListPicker({required this.lists});

  final List<ShoppingListModel> lists;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Adicionar a qual lista?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          ...lists.map(
            (list) => ListTile(
              leading: const Icon(Icons.list_alt_rounded),
              title: Text(list.name),
              subtitle: Text(
                formatCountLabel(list.items.length, 'produto', 'produtos'),
              ),
              onTap: () => Navigator.pop(context, list),
            ),
          ),
        ],
      ),
    );
  }
}
