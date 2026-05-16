import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';

enum _EditorShoppingItemCardAction { delete }

Duration _itemCardMotionDuration(BuildContext context, Duration fallback) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class EditorShoppingItemCard extends StatelessWidget {
  const EditorShoppingItemCard({
    super.key,
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
        duration: _itemCardMotionDuration(context, AppTokens.motionFast),
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
                  PopupMenuButton<_EditorShoppingItemCardAction>(
                    tooltip: 'Mais ações',
                    onSelected: (action) {
                      if (action == _EditorShoppingItemCardAction.delete) {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) =>
                        const <PopupMenuEntry<_EditorShoppingItemCardAction>>[
                          PopupMenuItem<_EditorShoppingItemCardAction>(
                            value: _EditorShoppingItemCardAction.delete,
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
