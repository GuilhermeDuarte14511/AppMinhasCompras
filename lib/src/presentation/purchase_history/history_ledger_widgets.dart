import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';

class HistoryTotalsRow extends StatelessWidget {
  const HistoryTotalsRow({
    super.key,
    required this.planned,
    required this.spent,
  });
  final double planned;
  final double spent;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: 16,
        runSpacing: 12,
        children: [
          for (final entry in [
            ('TOTAL PLANEJADO', planned),
            ('TOTAL PAGO', spent),
          ])
            SizedBox(
              width: (constraints.maxWidth - 16) / 2,
              child: Column(
                crossAxisAlignment: entry.$1 == 'TOTAL PAGO'
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(entry.$1, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  Text(
                    formatCurrency(entry.$2),
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class HistoryMonthHeader extends StatelessWidget {
  const HistoryMonthHeader({
    super.key,
    required this.label,
    required this.purchases,
  });
  final String label;
  final List<CompletedPurchase> purchases;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
              Text(
                formatCountLabel(purchases.length, 'fechamento', 'fechamentos'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const Divider(height: 20),
          HistoryTotalsRow(
            planned: purchases.fold(0, (sum, p) => sum + p.totalValue),
            spent: purchases.fold(0, (sum, p) => sum + p.spentValue),
          ),
        ],
      ),
    );
  }
}

class PurchaseHistoryRow extends StatelessWidget {
  const PurchaseHistoryRow({
    super.key,
    required this.purchase,
    required this.financePanel,
    required this.onDetails,
    required this.onDelete,
  });
  final CompletedPurchase purchase;
  final Widget financePanel;
  final VoidCallback onDetails;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      child: InkWell(
        onTap: onDetails,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
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
                  Expanded(
                    child: Text(
                      purchase.listName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCurrency(purchase.spentValue),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Fechada em ${formatDateTime(purchase.closedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                formatCountLabel(
                  purchase.purchasedProductsCount,
                  'produto comprado',
                  'produtos comprados',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Planejado: ${formatCurrency(purchase.totalValue)} · Comprado: ${formatCurrency(purchase.purchasedValue)}',
                style: theme.textTheme.bodySmall,
              ),
              if (purchase.finalTotalCents != null)
                Text(
                  'Valor final pago: ${formatCurrency(purchase.spentValue)}',
                  style: theme.textTheme.bodySmall,
                ),
              financePanel,
              if (purchase.hasPaymentBalances)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    purchase.uncoveredSpentAmount > 0
                        ? 'Falta cobrir: ${formatCurrency(purchase.uncoveredSpentAmount)}'
                        : 'Despesa coberta pelos saldos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: purchase.uncoveredSpentAmount > 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Ver detalhes',
                      onPressed: onDetails,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Excluir fechamento',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
