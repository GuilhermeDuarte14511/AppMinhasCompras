import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';
import '../theme/editorial_workspace_theme.dart';
import 'history_ledger_widgets.dart';

class CompletedPurchaseDetailsSheet extends StatelessWidget {
  const CompletedPurchaseDetailsSheet({super.key, required this.purchase});
  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        final items = [...purchase.items]
          ..sort((a, b) {
            if (a.isPurchased != b.isPurchased) return a.isPurchased ? -1 : 1;
            return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
          });
        return LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: constraints.maxHeight * .94,
            child: Material(
              color: colors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Detalhe da compra',
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Fechar detalhes',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    purchase.listName,
                                    style: theme.textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Fechada em ${formatDateTime(purchase.closedAt)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 24),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: colors.surfaceContainerLowest,
                                      border: Border.all(
                                        color: colors.outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Resumo da compra',
                                                style:
                                                    theme.textTheme.titleMedium,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colors.primaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Concluída',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onPrimaryContainer,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 24),
                                        HistoryTotalsRow(
                                          planned: purchase.totalValue,
                                          spent: purchase.spentValue,
                                        ),
                                        const Divider(height: 24),
                                        _PurchaseFact(
                                          label: 'Produtos',
                                          value: formatCountLabel(
                                            purchase.productsCount,
                                            'produto',
                                            'produtos',
                                          ),
                                        ),
                                        _PurchaseFact(
                                          label: 'Quantidade',
                                          value: formatUnitCount(
                                            purchase.totalItems,
                                          ),
                                        ),
                                        _PurchaseFact(
                                          label: 'Comprado',
                                          value: formatCurrency(
                                            purchase.purchasedValue,
                                          ),
                                        ),
                                        if (purchase.pendingProductsCount > 0)
                                          _PurchaseFact(
                                            label: 'Pendentes',
                                            value: formatCountLabel(
                                              purchase.pendingProductsCount,
                                              'produto',
                                              'produtos',
                                            ),
                                          ),
                                        if (purchase.hasBudget)
                                          _PurchaseFact(
                                            label: 'Orçamento',
                                            value: formatCurrency(
                                              purchase.budget!,
                                            ),
                                          ),
                                        if (purchase.hasPaymentBalances) ...[
                                          _PurchaseFact(
                                            label: 'Saldos',
                                            value: formatCurrency(
                                              purchase.paymentBalancesTotal,
                                            ),
                                          ),
                                          _PurchaseFact(
                                            label:
                                                purchase.uncoveredSpentAmount >
                                                    0
                                                ? 'Falta cobrir'
                                                : 'Coberto',
                                            value: formatCurrency(
                                              purchase.uncoveredSpentAmount > 0
                                                  ? purchase
                                                        .uncoveredSpentAmount
                                                  : purchase.coveredSpentAmount,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  if (purchase.hasPaymentBalances) ...[
                                    const SizedBox(height: 24),
                                    _PurchasePaymentLedger(purchase: purchase),
                                  ],
                                  const SizedBox(height: 28),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Itens da compra',
                                          style: theme.textTheme.titleMedium,
                                        ),
                                      ),
                                      Text(
                                        formatCountLabel(
                                          items.length,
                                          'item',
                                          'itens',
                                        ),
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  for (final item in items) ...[
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.name,
                                                  style: theme
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${item.category.label} · ${item.quantity} × ${formatCurrency(item.unitPrice)}',
                                                  style:
                                                      theme.textTheme.bodySmall,
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      item.isPurchased
                                                          ? Icons.check_rounded
                                                          : Icons
                                                                .pending_outlined,
                                                      size: 14,
                                                      color: item.isPurchased
                                                          ? colors.primary
                                                          : colors
                                                                .onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      item.isPurchased
                                                          ? 'Comprado'
                                                          : 'Pendente',
                                                      style: theme
                                                          .textTheme
                                                          .labelSmall,
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            formatCurrency(item.subtotal),
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _PurchaseFact extends StatelessWidget {
  const _PurchaseFact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _PurchasePaymentLedger extends StatelessWidget {
  const _PurchasePaymentLedger({required this.purchase});
  final CompletedPurchase purchase;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Como a compra foi paga', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Despesa considerada: ${formatCurrency(purchase.spentValue)}',
          style: theme.textTheme.bodySmall,
        ),
        const Divider(height: 16),
        for (final entry in purchase.paymentUsage.where(
          (e) => e.balance.value > 0,
        )) ...[
          Text(
            '${entry.balance.name} (${entry.balance.type.label})',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatCurrency(entry.consumed)} / ${formatCurrency(entry.balance.value)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (entry.consumed / entry.balance.value).clamp(0.0, 1.0),
            minHeight: 3,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          Text(
            entry.isExhausted
                ? 'Saldo esgotado.'
                : 'Restante: ${formatCurrency(entry.remaining)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: entry.isExhausted
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 24),
        ],
        if (purchase.uncoveredSpentAmount > 0)
          Text(
            'Ainda sem cobertura: ${formatCurrency(purchase.uncoveredSpentAmount)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
