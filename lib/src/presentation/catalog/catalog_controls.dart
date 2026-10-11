import 'package:flutter/material.dart';

import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

enum CatalogSortOption { updatedAt, name, usage, price }

enum CatalogPriceFilter { all, withoutPrice }

class CatalogControls extends StatelessWidget {
  const CatalogControls({
    super.key,
    required this.controller,
    required this.products,
    required this.category,
    required this.sort,
    required this.priceFilter,
    required this.onlyWithBarcode,
    required this.hasFilters,
    required this.onCategory,
    required this.onSort,
    required this.onPrice,
    required this.onBarcode,
    required this.onClear,
    required this.onCreate,
    required this.onScan,
    required this.visibleCount,
    required this.batchMode,
  });
  final TextEditingController controller;
  final List<CatalogProduct> products;
  final ShoppingCategory? category;
  final CatalogSortOption sort;
  final CatalogPriceFilter priceFilter;
  final bool onlyWithBarcode, hasFilters, batchMode;
  final int visibleCount;
  final ValueChanged<ShoppingCategory?> onCategory;
  final ValueChanged<CatalogSortOption> onSort;
  final ValueChanged<CatalogPriceFilter> onPrice;
  final ValueChanged<bool> onBarcode;
  final VoidCallback onClear, onCreate, onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labels = {
      CatalogSortOption.updatedAt: 'Atualização',
      CatalogSortOption.name: 'Nome',
      CatalogSortOption.usage: 'Mais frequentes',
      CatalogSortOption.price: 'Preço',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!batchMode) ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Cadastrar produto'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onScan,
                    icon: const Icon(Icons.qr_code_scanner, size: 16),
                    label: const Text('Ler código de barras'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          TextField(
            controller: controller,
            style: theme.textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: 'Buscar por nome, categoria ou código...',
              prefixIcon: const Icon(Icons.search, size: 18),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close, size: 18),
                    ),
              filled: true,
              fillColor: colors.surfaceContainerLowest,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _categoryChip(context, null, 'Todos (${products.length})'),
                for (final value in ShoppingCategory.values)
                  _categoryChip(context, value, value.label),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                PopupMenuButton<CatalogSortOption>(
                  tooltip: 'Ordenar catálogo',
                  onSelected: onSort,
                  itemBuilder: (_) => [
                    for (final value in CatalogSortOption.values)
                      CheckedPopupMenuItem(
                        value: value,
                        checked: sort == value,
                        child: Text(labels[value]!),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.sort, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          labels[sort]!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                FilterChip(
                  label: const Text('Com código de barras'),
                  selected: onlyWithBarcode,
                  onSelected: onBarcode,
                  showCheckmark: false,
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Sem preço'),
                  selected: priceFilter == CatalogPriceFilter.withoutPrice,
                  onSelected: (selected) => onPrice(
                    selected
                        ? CatalogPriceFilter.withoutPrice
                        : CatalogPriceFilter.all,
                  ),
                  showCheckmark: false,
                ),
                if (hasFilters)
                  TextButton(
                    onPressed: onClear,
                    child: const Text('Limpar filtros'),
                  ),
              ],
            ),
          ),
          Text(
            '${formatCountLabel(visibleCount, 'produto', 'produtos')} ${hasFilters ? (visibleCount == 1 ? 'encontrado' : 'encontrados') : (visibleCount == 1 ? 'cadastrado' : 'cadastrados')}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(
    BuildContext context,
    ShoppingCategory? value,
    String label,
  ) {
    final selected = category == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: ValueKey('catalog_category_${value?.key ?? 'all'}'),
        selected: selected,
        showCheckmark: false,
        shape: const StadiumBorder(),
        selectedColor: const Color(0xFF365943),
        label: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: selected ? Colors.white : null,
          ),
        ),
        onSelected: (_) => onCategory(value),
      ),
    );
  }
}
