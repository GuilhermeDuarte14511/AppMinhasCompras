import 'package:flutter/material.dart';

import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../extensions/classification_ui_extensions.dart';
import '../../theme/app_tokens.dart';
import '../shopping_list_editor_models.dart';

class ItemsToolsBar extends StatefulWidget {
  const ItemsToolsBar({
    super.key,
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
  final EditorItemsVisibility visibilityFilter;
  final bool marketModeEnabled;
  final int visibleCount;
  final int totalCount;
  final int pendingCount;
  final int purchasedCount;
  final bool hasActiveFilters;
  final ValueChanged<ItemSortOption> onSortChanged;
  final ValueChanged<ShoppingCategory?> onCategoryChanged;
  final ValueChanged<EditorItemsVisibility> onVisibilityChanged;
  final VoidCallback onClearFilters;

  @override
  State<ItemsToolsBar> createState() => _ItemsToolsBarState();
}

class _ItemsToolsBarState extends State<ItemsToolsBar> {
  bool _isExpanded = false;

  TextEditingController get controller => widget.controller;
  ItemSortOption get selectedSort => widget.selectedSort;
  ShoppingCategory? get selectedCategory => widget.selectedCategory;
  EditorItemsVisibility get visibilityFilter => widget.visibilityFilter;
  bool get marketModeEnabled => widget.marketModeEnabled;
  int get visibleCount => widget.visibleCount;
  int get totalCount => widget.totalCount;
  int get pendingCount => widget.pendingCount;
  int get purchasedCount => widget.purchasedCount;
  bool get hasActiveFilters => widget.hasActiveFilters;
  ValueChanged<ItemSortOption> get onSortChanged => widget.onSortChanged;
  ValueChanged<ShoppingCategory?> get onCategoryChanged =>
      widget.onCategoryChanged;
  ValueChanged<EditorItemsVisibility> get onVisibilityChanged =>
      widget.onVisibilityChanged;
  VoidCallback get onClearFilters => widget.onClearFilters;

  @override
  void initState() {
    super.initState();
    controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ItemsToolsBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == controller) {
      return;
    }
    oldWidget.controller.removeListener(_handleControllerChanged);
    controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

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
            _CollapsedToolsHeader(
              key: const ValueKey('items_tools_compact'),
              expanded: _isExpanded,
              visibilityLabel: _visibilityLabel(visibilityFilter),
              visibilityCount: _visibilityCount(visibilityFilter),
              visibleCount: visibleCount,
              totalCount: totalCount,
              searchQuery: controller.text.trim(),
              hasActiveFilters: hasActiveFilters,
              onToggle: _toggleExpanded,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _isExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 20),
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
                                  ({
                                    String label,
                                    int count,
                                    EditorItemsVisibility value,
                                  })
                                >[
                                  (
                                    label: 'Pendentes',
                                    count: pendingCount,
                                    value: EditorItemsVisibility.pending,
                                  ),
                                  (
                                    label: 'Todos',
                                    count: totalCount,
                                    value: EditorItemsVisibility.all,
                                  ),
                                  (
                                    label: 'Comprados',
                                    count: purchasedCount,
                                    value: EditorItemsVisibility.purchased,
                                  ),
                                ])
                              ChoiceChip(
                                selected: visibilityFilter == filter.value,
                                showCheckmark: false,
                                label: Text('${filter.label} ${filter.count}'),
                                avatar: Icon(
                                  _visibilityIcon(filter.value),
                                  size: 16,
                                ),
                                onSelected: (_) =>
                                    onVisibilityChanged(filter.value),
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
                                avatar: const Icon(
                                  Icons.storefront_rounded,
                                  size: 18,
                                ),
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
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
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _visibilityLabel(EditorItemsVisibility filter) {
    return switch (filter) {
      EditorItemsVisibility.pending => 'Pendentes',
      EditorItemsVisibility.all => 'Todos',
      EditorItemsVisibility.purchased => 'Comprados',
    };
  }

  int _visibilityCount(EditorItemsVisibility filter) {
    return switch (filter) {
      EditorItemsVisibility.pending => pendingCount,
      EditorItemsVisibility.all => totalCount,
      EditorItemsVisibility.purchased => purchasedCount,
    };
  }

  IconData _visibilityIcon(EditorItemsVisibility filter) {
    return switch (filter) {
      EditorItemsVisibility.pending => Icons.pending_actions_rounded,
      EditorItemsVisibility.all => Icons.format_list_bulleted_rounded,
      EditorItemsVisibility.purchased => Icons.check_circle_rounded,
    };
  }
}

class _CollapsedToolsHeader extends StatelessWidget {
  const _CollapsedToolsHeader({
    super.key,
    required this.expanded,
    required this.visibilityLabel,
    required this.visibilityCount,
    required this.visibleCount,
    required this.totalCount,
    required this.searchQuery,
    required this.hasActiveFilters,
    required this.onToggle,
  });

  final bool expanded;
  final String visibilityLabel;
  final int visibilityCount;
  final int visibleCount;
  final int totalCount;
  final String searchQuery;
  final bool hasActiveFilters;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tooltip = expanded
        ? 'Recolher busca e filtros'
        : 'Expandir busca e filtros';

    return Semantics(
      button: true,
      expanded: expanded,
      label: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: hasActiveFilters
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    hasActiveFilters
                        ? Icons.filter_alt_rounded
                        : Icons.tune_rounded,
                    size: 20,
                    color: hasActiveFilters
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$visibilityLabel $visibilityCount',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '$visibleCount de ${formatItemCount(totalCount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    if (searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Busca: $searchQuery',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: tooltip,
                onPressed: onToggle,
                icon: AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
              ),
            ],
          ),
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
