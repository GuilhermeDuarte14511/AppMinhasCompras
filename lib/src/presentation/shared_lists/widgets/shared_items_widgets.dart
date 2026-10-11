import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/remote/shared_lists_repository.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';
import '../shared_list_editor_models.dart';

class SharedItemsToolbar extends StatelessWidget {
  const SharedItemsToolbar({
    super.key,
    required this.controller,
    required this.selectedFilter,
    required this.totalCount,
    required this.pendingCount,
    required this.purchasedCount,
    required this.matchingCount,
    required this.onFilterSelected,
  });

  final TextEditingController controller;
  final SharedItemsFilter selectedFilter;
  final int totalCount;
  final int pendingCount;
  final int purchasedCount;
  final int matchingCount;
  final ValueChanged<SharedItemsFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchIsActive = matchingCount != totalCount;
    final filterEntries =
        <({String label, int count, SharedItemsFilter value})>[
          (
            label: 'Pendentes',
            count: pendingCount,
            value: SharedItemsFilter.pending,
          ),
          (label: 'Todos', count: totalCount, value: SharedItemsFilter.all),
          (
            label: 'Comprados',
            count: purchasedCount,
            value: SharedItemsFilter.purchased,
          ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.bodySmall,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, size: 18),
            hintText: 'Buscar item por nome...',
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Limpar busca',
                    onPressed: controller.clear,
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in filterEntries)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    selected: selectedFilter == filter.value,
                    showCheckmark: false,
                    label: Text('${filter.label} ${filter.count}'),
                    onSelected: (_) => onFilterSelected(filter.value),
                  ),
                ),
            ],
          ),
        ),
        if (searchIsActive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${formatCountLabel(matchingCount, 'resultado', 'resultados')} na busca atual.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class SharedItemsHintCard extends StatelessWidget {
  const SharedItemsHintCard({
    super.key,
    required this.hiddenCount,
    required this.onPressed,
  });

  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hiddenCount == 1
                    ? '1 item já pego está oculto para deixar a lista mais prática.'
                    : '$hiddenCount itens já pegos estão ocultos para deixar a lista mais prática.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onPressed, child: const Text('Ver')),
          ],
        ),
      ),
    );
  }
}

class SharedItemsEmptyState extends StatelessWidget {
  const SharedItemsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.54),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 32, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (primaryActionLabel != null &&
                      onPrimaryAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: onPrimaryAction,
                      child: Text(primaryActionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SharedItemCard extends StatelessWidget {
  const SharedItemCard({
    super.key,
    required this.item,
    required this.onPurchasedChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
    this.enabled = true,
  });
  final SharedShoppingItem item;
  final ValueChanged<bool?> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: 'Item ${item.name}',
      value: item.isPurchased ? 'Pego' : 'Pendente',
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: item.isPurchased,
                  onChanged: enabled ? onPurchasedChanged : null,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    formatCurrency(item.subtotal),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SharedQuantityStepper(
                    quantity: item.quantity,
                    onIncrement: enabled ? onIncrement : null,
                    onDecrement: enabled ? onDecrement : null,
                  ),
                  PopupMenuButton<String>(
                    enabled: enabled,
                    tooltip: 'Mais ações do item',
                    onSelected: (action) =>
                        action == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar item')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir item'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SharedQuantityStepper extends StatelessWidget {
  const SharedQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir',
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$quantity',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Aumentar',
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
