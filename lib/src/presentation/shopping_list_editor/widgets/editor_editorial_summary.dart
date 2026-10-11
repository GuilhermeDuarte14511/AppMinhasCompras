import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import 'editor_summary_widgets.dart';

class EditorEditorialSummary extends StatefulWidget {
  const EditorEditorialSummary({
    super.key,
    required this.list,
    required this.onBudget,
    required this.onReminder,
    required this.onBalances,
    required this.onMarket,
    required this.onCheckout,
    this.onReopen,
    this.initialExpanded = false,
  });

  final ShoppingListModel list;
  final VoidCallback onBudget, onReminder, onBalances, onMarket, onCheckout;
  final VoidCallback? onReopen;
  final bool initialExpanded;

  @override
  State<EditorEditorialSummary> createState() => _EditorEditorialSummaryState();
}

class _EditorEditorialSummaryState extends State<EditorEditorialSummary> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  void _toggleExpanded() {
    HapticFeedback.selectionClick();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final list = widget.list;
    final bought = list.purchasedItemsCount;
    final count = list.items.length;
    final progress = count == 0 ? 0.0 : bought / count;

    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final motionDuration = disableMotion
        ? Duration.zero
        : const Duration(milliseconds: 240);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.65),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Botão colapsável estilizado como card dropdown interativo
          Semantics(
            button: true,
            toggled: _isExpanded,
            label: 'Resumo da compra',
            hint: _isExpanded
                ? 'Toque para recolher detalhes'
                : 'Toque para expandir detalhes',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('editor_summary_toggle'),
                onTap: _toggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(
                    children: [
                      // Total da compra
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Total da compra:',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 11,
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (list.isClosed) ...[
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.lock_outline,
                                    size: 12,
                                    color: colors.primary,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                formatCurrency(list.totalValue),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Total disponível (baseado no orçamento)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Total disponível:',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: list.hasBudget
                                  ? Text(
                                      list.isOverBudget
                                          ? 'Excesso ${formatCurrency(list.overBudgetAmount)}'
                                          : formatCurrency(
                                              list.budgetRemaining,
                                            ),
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: list.isOverBudget
                                                ? colors.error
                                                : colors.primary,
                                          ),
                                    )
                                  : Text(
                                      'Sem orçamento',
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSurfaceVariant,
                                          ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Indicador tipo botão/pill (Ver mais / Recolher)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isExpanded ? 'Recolher' : 'Ver mais',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              duration: motionDuration,
                              curve: Curves.easeOutCubic,
                              turns: _isExpanded ? 0.5 : 0.0,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colors.onSurfaceVariant,
                                size: 16,
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
          ),

          // Seção expandida (Total Calculado, Teto Orçado, Modo compra, Consumo, etc.)
          ClipRect(
            child: AnimatedAlign(
              duration: motionDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: _isExpanded ? 1.0 : 0.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Divider(
                      height: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL CALCULADO',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  letterSpacing: .8,
                                ),
                              ),
                              Text(
                                formatCurrency(list.totalValue),
                                style: theme.textTheme.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: InkWell(
                            onTap: widget.onBudget,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'TETO ORÇADO',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    letterSpacing: .8,
                                  ),
                                ),
                                Text(
                                  list.hasBudget
                                      ? formatCurrency(list.budget!)
                                      : 'Definir orçamento',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (list.hasBudget)
                                  Text(
                                    'Disponível: ${formatCurrency(list.budgetRemaining)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: colors.primary,
                      backgroundColor: colors.outlineVariant,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${formatCountLabel(count - bought, 'pendente', 'pendentes')} · ${formatCountLabel(bought, 'comprado', 'comprados')} (${list.totalItems} un.)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}% do total',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (list.isOverBudget)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Excesso: ${formatCurrency(list.overBudgetAmount)} — valor acima do orçamento.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (list.isClosed)
                      OutlinedButton.icon(
                        onPressed: widget.onReopen,
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Reabrir lista'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: widget.onMarket,
                              icon: const Icon(
                                Icons.shopping_cart_outlined,
                                size: 16,
                              ),
                              label: const Text('Modo compra'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: widget.onCheckout,
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                              ),
                              label: const Text('Fechar compra'),
                            ),
                          ),
                        ],
                      ),
                    if (list.reminder != null)
                      TextButton.icon(
                        onPressed: widget.onReminder,
                        icon: const Icon(
                          Icons.notifications_outlined,
                          size: 14,
                        ),
                        label: Text(
                          'Lembrete: ${formatDateTime(list.reminder!.scheduledAt)}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (list.hasPaymentBalances) ...[
                      TextButton.icon(
                        onPressed: widget.onBalances,
                        icon: const Icon(Icons.payments_outlined, size: 16),
                        label: const Text('Editar saldos'),
                      ),
                      PaymentBalancesUsagePanel(list: list),
                    ],
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        onPressed: _toggleExpanded,
                        icon: const Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 16,
                        ),
                        label: const Text('Recolher resumo'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
