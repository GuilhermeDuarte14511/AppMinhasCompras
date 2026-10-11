import 'package:flutter/material.dart';

import '../../application/purchase_checkout_review.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';

/// Preview of the items included in checkout, without changing the source list.
class CheckoutItemsSection extends StatelessWidget {
  const CheckoutItemsSection({
    super.key,
    required this.items,
    required this.review,
    required this.onEdit,
    this.pendingControl,
  });

  final List<ShoppingItem> items;
  final PurchaseCheckoutReview review;
  final ValueChanged<ShoppingItem> onEdit;
  final Widget? pendingControl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missingIds = review.missingPriceItems.map((item) => item.id).toSet();
    final excludedIds = review.pendingItems.map((item) => item.id).toSet();
    final summary =
        review.missingPriceItems.isNotEmpty && review.receiptTotalCents != null
        ? 'O valor final informado substitui a soma dos itens sem preço.'
        : review.missingPriceItems.isEmpty
        ? '${review.includedItemsCount} ${review.includedItemsCount == 1 ? 'item entra' : 'itens entram'} no fechamento.'
        : '${review.missingPriceItems.length} ${review.missingPriceItems.length == 1 ? 'item precisa' : 'itens precisam'} de preço.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ITENS',
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: scheme.surfaceContainerLowest,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pendingControl != null) ...[
                Material(
                  color: scheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    child: pendingControl,
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant),
              ],
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) Divider(height: 1, color: scheme.outlineVariant),
                _CheckoutItemRow(
                  item: items[index],
                  included: !excludedIds.contains(items[index].id),
                  missingPrice: missingIds.contains(items[index].id),
                  onEdit: () => onEdit(items[index]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          liveRegion: true,
          child: Text(
            summary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckoutItemRow extends StatelessWidget {
  const _CheckoutItemRow({
    required this.item,
    required this.included,
    required this.missingPrice,
    required this.onEdit,
  });

  final ShoppingItem item;
  final bool included;
  final bool missingPrice;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    included
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: included ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: included
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity} un × ${formatCurrency(item.unitPrice)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (item.quantity > 1) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Subtotal ${formatCurrency(item.subtotal)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                      if (!item.isPurchased || missingPrice) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (!item.isPurchased)
                              _ItemStatus(
                                label: included ? 'Será comprado' : 'Pendente',
                              ),
                            if (missingPrice)
                              _ItemStatus(label: 'Sem preço', error: true),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Corrigir ${item.name}',
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.onSurfaceVariant,
                minimumSize: const Size(64, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: theme.textTheme.labelSmall,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onEdit,
              child: const Text('Corrigir'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemStatus extends StatelessWidget {
  const _ItemStatus({required this.label, this.error = false});
  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: error ? scheme.error : scheme.outlineVariant),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: error ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          fontSize: 10,
        ),
      ),
    );
  }
}
