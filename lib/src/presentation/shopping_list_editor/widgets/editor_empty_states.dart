import 'dart:math';

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
                    if (visibilityFilter != EditorItemsVisibility.pending)
                      OutlinedButton.icon(
                        onPressed: onShowPending,
                        icon: const Icon(Icons.pending_actions_rounded),
                        label: const Text('Ver pendentes'),
                      ),
                    if (visibilityFilter != EditorItemsVisibility.purchased)
                      OutlinedButton.icon(
                        onPressed: onShowPurchased,
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Ver comprados'),
                      ),
                    if (visibilityFilter != EditorItemsVisibility.all)
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

class EmptyItemsState extends StatelessWidget {
  const EmptyItemsState({super.key});

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
