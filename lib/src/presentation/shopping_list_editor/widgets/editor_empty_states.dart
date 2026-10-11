import 'package:flutter/material.dart';

import '../shopping_list_editor_models.dart';

class EmptySearchState extends StatelessWidget {
  const EmptySearchState({
    super.key,
    required this.query,
    required this.visibilityFilter,
    required this.onClearFilters,
    required this.onShowPending,
    required this.onShowPurchased,
    required this.onShowAll,
  });

  final String query;
  final EditorItemsVisibility visibilityFilter;
  final VoidCallback onClearFilters;
  final VoidCallback onShowPending;
  final VoidCallback onShowPurchased;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('empty-search-results'),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.search_off_outlined, size: 32),
        const SizedBox(height: 12),
        Text(
          'Nenhum produto encontrado',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          query.isEmpty
              ? 'Nenhum item neste filtro.'
              : 'Nenhum item corresponde a "$query".',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onClearFilters,
          child: const Text('Limpar filtros'),
        ),
        Wrap(
          spacing: 8,
          alignment: WrapAlignment.center,
          children: [
            if (visibilityFilter != EditorItemsVisibility.pending)
              TextButton(
                onPressed: onShowPending,
                child: const Text('Ver pendentes'),
              ),
            if (visibilityFilter != EditorItemsVisibility.purchased)
              TextButton(
                onPressed: onShowPurchased,
                child: const Text('Ver comprados'),
              ),
            if (visibilityFilter != EditorItemsVisibility.all)
              TextButton(onPressed: onShowAll, child: const Text('Ver todos')),
          ],
        ),
      ],
    ),
  );
}

class EmptyItemsState extends StatelessWidget {
  const EmptyItemsState({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('empty-items'),
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.shopping_cart_outlined, size: 32),
        const SizedBox(height: 12),
        Text(
          'Esta lista está vazia',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Use o botão "Adicionar item" para incluir o primeiro produto.',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
