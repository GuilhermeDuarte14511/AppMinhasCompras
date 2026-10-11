import 'package:flutter/material.dart';

import '../../../domain/classifications.dart';
import '../../extensions/classification_ui_extensions.dart';
import '../shopping_list_editor_models.dart';

class ItemsToolsBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: 'Filtrar nesta lista...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter
                    in <
                      ({String label, int count, EditorItemsVisibility value})
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
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: ValueKey('editor_filter_${filter.value.name}'),
                      label: Text(
                        '${filter.label} (${filter.count})',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: visibilityFilter == filter.value
                              ? Colors.white
                              : colors.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                      selected: visibilityFilter == filter.value,
                      showCheckmark: false,
                      shape: const StadiumBorder(),
                      selectedColor: const Color(0xFF365943),
                      backgroundColor: colors.surfaceContainerLow,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => onVisibilityChanged(filter.value),
                    ),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  tooltip: 'Filtrar categoria',
                  onSelected: (value) => onCategoryChanged(
                    ShoppingCategory.values
                        .where((entry) => entry.key == value)
                        .firstOrNull,
                  ),
                  itemBuilder: (_) => [
                    CheckedPopupMenuItem(
                      value: 'all',
                      checked: selectedCategory == null,
                      child: const Text('Todas as categorias'),
                    ),
                    for (final category in ShoppingCategory.values)
                      CheckedPopupMenuItem(
                        value: category.key,
                        checked: selectedCategory == category,
                        child: Text(category.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.category_outlined, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedCategory?.label ?? 'Todas as categorias',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: PopupMenuButton<ItemSortOption>(
                  tooltip: 'Ordenar itens',
                  onSelected: onSortChanged,
                  itemBuilder: (_) => [
                    for (final option in ItemSortOption.values)
                      CheckedPopupMenuItem(
                        value: option,
                        checked: option == selectedSort,
                        child: Text(option.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(selectedSort.icon, size: 14),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedSort.shortLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (marketModeEnabled)
            Text(
              'Ordenação de mercado ativa',
              style: theme.textTheme.bodySmall,
            ),
          if (hasActiveFilters)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onClearFilters,
                child: const Text('Limpar filtros'),
              ),
            ),
        ],
      ),
    );
  }
}
