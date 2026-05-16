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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar item por nome...',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in filterEntries)
                  ChoiceChip(
                    selected: selectedFilter == filter.value,
                    showCheckmark: false,
                    label: Text('${filter.label} ${filter.count}'),
                    avatar: Icon(_filterIcon(filter.value), size: 16),
                    onSelected: (_) => onFilterSelected(filter.value),
                  ),
              ],
            ),
            if (searchIsActive) ...[
              const SizedBox(height: 8),
              Text(
                '${formatCountLabel(matchingCount, 'resultado', 'resultados')} na busca atual.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _filterIcon(SharedItemsFilter filter) {
    return switch (filter) {
      SharedItemsFilter.pending => Icons.pending_actions_rounded,
      SharedItemsFilter.all => Icons.format_list_bulleted_rounded,
      SharedItemsFilter.purchased => Icons.check_circle_rounded,
    };
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
            Icon(Icons.visibility_outlined, color: colorScheme.secondary),
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
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
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
  });

  final SharedShoppingItem item;
  final ValueChanged<bool?> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cardColor = item.isPurchased
        ? colorScheme.surfaceContainerLow.withValues(alpha: 0.95)
        : colorScheme.surface;

    return Semantics(
      container: true,
      label: 'Item ${item.name}',
      value: item.isPurchased ? 'Pego' : 'Pendente',
      child: Card(
        elevation: 0,
        color: cardColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Checkbox(
                      value: item.isPurchased,
                      onChanged: onPurchasedChanged,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              decoration: item.isPurchased
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              decoration: item.isPurchased
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações do item',
                    onSelected: (action) {
                      if (action == 'edit') {
                        onEdit();
                        return;
                      }
                      if (action == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar item')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir item'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SharedItemInfoChip(
                    icon: item.isPurchased
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    label: item.isPurchased ? 'Pego' : 'Pendente',
                    emphasized: item.isPurchased,
                  ),
                  SharedItemInfoChip(
                    icon: Icons.receipt_long_rounded,
                    label: formatCurrency(item.subtotal),
                  ),
                  SharedQuantityStepper(
                    quantity: item.quantity,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SharedItemInfoChip extends StatelessWidget {
  const SharedItemInfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = emphasized
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final foregroundColor = emphasized
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
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
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
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
