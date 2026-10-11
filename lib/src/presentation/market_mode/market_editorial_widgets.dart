import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class MarketEditorialSummary extends StatelessWidget {
  const MarketEditorialSummary({
    super.key,
    required this.list,
    required this.completion,
    required this.pendingProductsCount,
    required this.purchasedProductsCount,
    required this.pendingUnits,
    required this.pendingValue,
  });
  final ShoppingListModel list;
  final double completion, pendingValue;
  final int pendingProductsCount, purchasedProductsCount, pendingUnits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final picked = list.items
        .where((item) => item.isPurchased)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
    Widget amount(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            letterSpacing: .5,
          ),
        ),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontSize: 17)),
      ],
    );
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('Progresso da compra', style: theme.textTheme.bodySmall),
                Text(
                  '$purchasedProductsCount de ${list.items.length} itens comprados (${(completion * 100).round()}%)',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: completion,
              minHeight: 4,
              backgroundColor: colors.outlineVariant,
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
              children: [
                amount('VALOR PEGO', formatCurrency(picked)),
                amount('FALTA PEGAR', formatCurrency(pendingValue)),
                amount(
                  'TETO ORÇADO',
                  list.hasBudget
                      ? formatCurrency(list.budget!)
                      : 'Não definido',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$pendingProductsCount pendentes · $purchasedProductsCount pegos · $pendingUnits unidades restantes',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
            if (list.isOverBudget)
              Text(
                'Acima do orçamento: ${formatCurrency(list.overBudgetAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
              ),
          ],
        ),
      ),
    );
  }
}

class MarketEditorialItemRow extends StatelessWidget {
  const MarketEditorialItemRow({
    super.key,
    required this.item,
    required this.onTogglePurchased,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEditPrice,
  });
  final ShoppingItem item;
  final VoidCallback onTogglePurchased, onIncrement, onDecrement, onEditPrice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: item.isPurchased ? colors.surfaceContainerLow : colors.surface,
      child: InkWell(
        onTap: onTogglePurchased,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: item.isPurchased
                    ? 'Marcar como pendente'
                    : 'Marcar como pego',
                child: Checkbox(
                  key: ValueKey('market_toggle_${item.id}'),
                  value: item.isPurchased,
                  semanticLabel:
                      '${item.isPurchased ? 'Marcar pendente' : 'Marcar pego'}: ${item.name}',
                  onChanged: (_) => onTogglePurchased(),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        decoration: item.isPurchased
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.category.label,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                    Tooltip(
                      message: 'Editar preço de ${item.name}',
                      child: TextButton(
                        onPressed: onEditPrice,
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Text(
                          '${formatCurrency(item.unitPrice)} / un.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCurrency(item.subtotal),
                    style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Diminuir quantidade',
                          onPressed: item.quantity > 1 ? onDecrement : null,
                          icon: const Icon(Icons.remove_rounded, size: 14),
                        ),
                        Text(
                          '${item.quantity}',
                          style: theme.textTheme.bodySmall,
                        ),
                        IconButton(
                          tooltip: 'Aumentar quantidade',
                          onPressed: onIncrement,
                          icon: const Icon(Icons.add_rounded, size: 14),
                        ),
                      ],
                    ),
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
