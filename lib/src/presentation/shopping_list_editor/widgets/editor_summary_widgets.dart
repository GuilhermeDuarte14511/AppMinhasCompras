import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';

Duration _editorSummaryMotionDuration(BuildContext context, Duration fallback) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class ListSummaryPanel extends StatelessWidget {
  const ListSummaryPanel({
    super.key,
    required this.list,
    required this.collapsed,
    required this.onBudgetTap,
    required this.onReminderTap,
    required this.onPaymentBalancesTap,
    required this.onToggleCollapsed,
    this.onReopenTap,
  });

  final ShoppingListModel list;
  final bool collapsed;
  final VoidCallback onBudgetTap;
  final VoidCallback onReminderTap;
  final VoidCallback onPaymentBalancesTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onReopenTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final purchasedCount = list.purchasedItemsCount;
    final pendingCount = max(0, list.items.length - purchasedCount);
    final compactSummary =
        '${list.totalItems} itens • ${formatCurrency(list.totalValue)}';
    final statusParts = <String>[
      '$pendingCount pendentes',
      '$purchasedCount comprados',
      if (list.hasBudget)
        list.isOverBudget
            ? 'Excesso ${formatCurrency(list.overBudgetAmount)}'
            : 'Saldo ${formatCurrency(max(0, list.budgetRemaining))}',
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        color: colorScheme.surface,
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
          width: AppTokens.cardBorderWidth,
        ),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            toggled: !collapsed,
            label: 'Resumo da lista',
            hint: collapsed
                ? 'Toque para expandir o resumo'
                : 'Toque para recolher o resumo',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleCollapsed();
              },
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                  collapsed ? AppTokens.spaceMd : AppTokens.spaceSm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Resumo da lista',
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            compactSummary,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusParts.join(' • '),
                            maxLines: collapsed ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              collapsed ? 'Abrir' : 'Fechar',
                              style: textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              duration: _editorSummaryMotionDuration(
                                context,
                                AppTokens.motionMedium,
                              ),
                              turns: collapsed ? 0 : 0.5,
                              child: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedAlign(
              duration: _editorSummaryMotionDuration(
                context,
                AppTokens.motionMedium,
              ),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: collapsed ? 0 : 1,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTokens.spaceMd,
                  0,
                  AppTokens.spaceMd,
                  AppTokens.spaceMd,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (list.isClosed) ...[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.72,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radiusMd,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Compra fechada. Reabra para editar itens.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (onReopenTap != null)
                                TextButton(
                                  onPressed: onReopenTap,
                                  child: const Text('Reabrir'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      'Valor, quantidade e status atualizados em tempo real.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.86,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        EditorMetricTag(
                          icon: Icons.attach_money_rounded,
                          label: 'Total',
                          value: formatCurrency(list.totalValue),
                        ),
                        EditorMetricTag(
                          icon: Icons.inventory_2_rounded,
                          label: 'Itens',
                          value: '',
                        ),
                        EditorMetricTag(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pendentes',
                          value: formatCurrency(list.pendingValue),
                        ),
                        EditorMetricTag(
                          icon: Icons.check_circle_rounded,
                          label: 'Comprados',
                          value: '',
                        ),
                        EditorMetricTag(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Orçamento disponível',
                          value: list.hasBudget
                              ? formatCurrency(max(0, list.budgetRemaining))
                              : 'Não definido',
                          onTap: onBudgetTap,
                        ),
                        EditorMetricTag(
                          icon: Icons.payments_rounded,
                          label: 'Saldos',
                          value: list.hasPaymentBalances
                              ? formatCurrency(list.paymentBalancesTotal)
                              : 'Não definido',
                          onTap: onPaymentBalancesTap,
                        ),
                        EditorMetricTag(
                          icon: list.reminder == null
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_active_rounded,
                          label: 'Lembrete',
                          value: list.reminder == null
                              ? 'Desligado'
                              : formatDateTime(list.reminder!.scheduledAt),
                          onTap: onReminderTap,
                        ),
                        if (list.hasBudget)
                          EditorMetricTag(
                            icon: list.isOverBudget
                                ? Icons.warning_amber_rounded
                                : Icons.savings_rounded,
                            label: list.isOverBudget ? 'Excesso' : 'Saldo',
                            value: list.isOverBudget
                                ? formatCurrency(list.overBudgetAmount)
                                : formatCurrency(list.budgetRemaining),
                          ),
                        if (list.hasPaymentBalances)
                          EditorMetricTag(
                            icon: list.uncoveredAmount > 0
                                ? Icons.error_outline_rounded
                                : Icons.check_circle_rounded,
                            label: list.uncoveredAmount > 0
                                ? 'Falta pagar'
                                : 'Coberto',
                            value: list.uncoveredAmount > 0
                                ? formatCurrency(list.uncoveredAmount)
                                : formatCurrency(list.coveredAmount),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        EditorQuickSummaryActionChip(
                          icon: Icons.account_balance_wallet_rounded,
                          label: list.hasBudget
                              ? 'Editar orçamento'
                              : 'Definir orçamento',
                          onTap: onBudgetTap,
                        ),
                        EditorQuickSummaryActionChip(
                          icon: Icons.payments_rounded,
                          label: list.hasPaymentBalances
                              ? 'Editar saldos'
                              : 'Definir saldos',
                          onTap: onPaymentBalancesTap,
                        ),
                        EditorQuickSummaryActionChip(
                          icon: list.reminder == null
                              ? Icons.notifications_off_rounded
                              : Icons.notifications_active_rounded,
                          label: list.reminder == null
                              ? 'Definir lembrete'
                              : 'Editar lembrete',
                          onTap: onReminderTap,
                        ),
                      ],
                    ),
                    if (list.hasPaymentBalances) ...[
                      const SizedBox(height: 12),
                      PaymentBalancesUsagePanel(list: list),
                    ],
                    if (list.isOverBudget) ...[
                      const SizedBox(height: 10),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withValues(
                            alpha: 0.85,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: colorScheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Valor total acima do orçamento por .',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class EditorMetricTag extends StatelessWidget {
  const EditorMetricTag({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = _editorSummaryMotionDuration(
      context,
      AppTokens.motionMedium,
    );

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: AnimatedSwitcher(
          duration: motionDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offset = Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: ConstrainedBox(
            key: ValueKey('$label|$value'),
            constraints: const BoxConstraints(maxWidth: 260),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17),
                const SizedBox(width: 7),
                Flexible(
                  child: RichText(
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        TextSpan(text: '$label: '),
                        TextSpan(
                          text: value,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        onTap: () {
          Feedback.forTap(context);
          onTap?.call();
        },
        child: content,
      ),
    );
  }
}

class EditorQuickSummaryActionChip extends StatelessWidget {
  const EditorQuickSummaryActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          Feedback.forTap(context);
          onTap();
        },
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }
}

class PaymentBalancesUsagePanel extends StatelessWidget {
  const PaymentBalancesUsagePanel({super.key, required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = list.paymentUsage
        .where((entry) => entry.balance.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surface.withValues(alpha: 0.68),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consumo por prioridade',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final progress = entry.balance.value <= 0
                  ? 0.0
                  : (entry.consumed / entry.balance.value)
                        .clamp(0.0, 1.0)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.balance.name} (${entry.balance.type.label})',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${formatCurrency(entry.consumed)} / ${formatCurrency(entry.balance.value)}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isExhausted
                          ? 'Saldo esgotado.'
                          : 'Restante: ${formatCurrency(entry.remaining)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.isExhausted
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (list.uncoveredAmount > 0)
              Text(
                'Total sem cobertura de saldo: ${formatCurrency(list.uncoveredAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
