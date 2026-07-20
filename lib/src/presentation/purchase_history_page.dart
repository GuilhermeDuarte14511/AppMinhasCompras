import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
import 'shopping_list_editor_page.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({
    super.key,
    required this.store,
    this.voiceRecognitionService,
  });

  final ShoppingListsStore store;
  final ShoppingVoiceRecognitionService? voiceRecognitionService;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  late final TextEditingController _searchController;

  String get _searchQuery => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<DateTime, List<CompletedPurchase>> _filteredHistoryByMonth() {
    final grouped = widget.store.historyGroupedByMonth();
    final normalizedQuery = normalizeQuery(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return grouped;
    }

    final filtered = <DateTime, List<CompletedPurchase>>{};
    for (final entry in grouped.entries) {
      final matches = entry.value
          .where((purchase) {
            if (normalizeQuery(purchase.listName).contains(normalizedQuery)) {
              return true;
            }
            for (final item in purchase.items) {
              if (normalizeQuery(item.name).contains(normalizedQuery)) {
                return true;
              }
            }
            return false;
          })
          .toList(growable: false);
      if (matches.isNotEmpty) {
        filtered[entry.key] = matches;
      }
    }
    return filtered;
  }

  String _monthLabel(DateTime month) {
    final raw = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    if (raw.isEmpty) {
      return '';
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  Future<void> _showPurchaseDetails(CompletedPurchase purchase) async {
    await showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CompletedPurchaseDetailsSheet(purchase: purchase),
    );
  }

  Future<void> _deletePurchase(CompletedPurchase purchase) async {
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir fechamento?'),
        content: Text(
          'Deseja remover o fechamento da lista "${purchase.listName}" em ${formatDateTime(purchase.closedAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.deleteCompletedPurchase(purchase.id);
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: 'Fechamento removido do histórico.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _clearHistory() async {
    if (widget.store.purchaseHistory.isEmpty) {
      return;
    }
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico mensal?'),
        content: const Text(
          'Essa ação remove todos os fechamentos salvos no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.clearPurchaseHistory();
    if (!mounted) {
      return;
    }
    AppToast.show(
      context,
      message: 'Histórico mensal limpo com sucesso.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _createListFromEmptyState() async {
    final name = await showListNameDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
    );
    if (!mounted || name == null) {
      return;
    }

    final created = await widget.store.createList(name: name);
    if (!mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    AppToast.show(
      context,
      message: 'Lista criada.',
      type: AppToastType.success,
      duration: const Duration(seconds: 4),
    );
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: created.id,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final grouped = _filteredHistoryByMonth();
        final totalEntries = grouped.values.fold<int>(
          0,
          (entryTotal, entries) => entryTotal + entries.length,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Histórico mensal'),
            actions: [
              IconButton(
                tooltip: 'Limpar histórico',
                onPressed: widget.store.purchaseHistory.isEmpty
                    ? null
                    : _clearHistory,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
            ],
          ),
          body: AppGradientScene(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: _HistoryContentPanel(
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Buscar por lista ou produto',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searchController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                              filled: true,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _HistorySummaryPill(
                                icon: Icons.event_note_rounded,
                                label: 'Fechamentos',
                                value: '$totalEntries',
                              ),
                              const SizedBox(width: 8),
                              _HistorySummaryPill(
                                icon: Icons.calendar_month_rounded,
                                label: 'Meses',
                                value: '${grouped.length}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: grouped.isEmpty
                        ? _EmptyPurchaseHistoryState(
                            hasQuery: _searchQuery.isNotEmpty,
                            onClearSearch: _searchController.clear,
                            onCreateList: _createListFromEmptyState,
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              ...grouped.entries.map((group) {
                                final month = group.key;
                                final entries = group.value;
                                final monthTotal = entries.fold<double>(
                                  0,
                                  (total, purchase) =>
                                      total + purchase.totalValue,
                                );
                                final monthPurchased = entries.fold<double>(
                                  0,
                                  (total, purchase) =>
                                      total + purchase.purchasedValue,
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _HistoryContentPanel(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _monthLabel(month),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            _HistoryPillLabel(
                                              icon: Icons.receipt_long_rounded,
                                              text: formatCountLabel(
                                                entries.length,
                                                'fechamento',
                                                'fechamentos',
                                              ),
                                            ),
                                            _HistoryPillLabel(
                                              icon: Icons.payments_rounded,
                                              text:
                                                  'Planejado ${formatCurrency(monthTotal)}',
                                            ),
                                            _HistoryPillLabel(
                                              icon: Icons.check_circle_rounded,
                                              text:
                                                  'Comprado ${formatCurrency(monthPurchased)}',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        ...entries.map((purchase) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              onTap: () => _showPurchaseDetails(
                                                purchase,
                                              ),
                                              child: Ink(
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .surfaceContainerHighest
                                                      .withValues(alpha: 0.38),
                                                ),
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.fromLTRB(
                                                        12,
                                                        10,
                                                        8,
                                                        10,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              purchase.listName,
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .titleSmall
                                                                  ?.copyWith(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 2,
                                                            ),
                                                            Text(
                                                              formatDateTime(
                                                                purchase
                                                                    .closedAt,
                                                              ),
                                                              style: Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall
                                                                  ?.copyWith(
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurfaceVariant,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              height: 6,
                                                            ),
                                                            Text(
                                                              'Planejado: ${formatCurrency(purchase.totalValue)}',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                            ),
                                                            Text(
                                                              'Comprado: ${formatCurrency(purchase.purchasedValue)}',
                                                              style:
                                                                  Theme.of(
                                                                        context,
                                                                      )
                                                                      .textTheme
                                                                      .bodySmall,
                                                            ),
                                                            if (purchase
                                                                .hasPaymentBalances)
                                                              Text(
                                                                purchase.uncoveredSpentAmount >
                                                                        0
                                                                    ? 'Falta cobrir: ${formatCurrency(purchase.uncoveredSpentAmount)}'
                                                                    : 'Despesa coberta pelos saldos.',
                                                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                  color:
                                                                      purchase.uncoveredSpentAmount >
                                                                          0
                                                                      ? Theme.of(
                                                                          context,
                                                                        ).colorScheme.error
                                                                      : Theme.of(
                                                                          context,
                                                                        ).colorScheme.primary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ),
                                                      PopupMenuButton<String>(
                                                        onSelected: (value) {
                                                          switch (value) {
                                                            case 'details':
                                                              _showPurchaseDetails(
                                                                purchase,
                                                              );
                                                            case 'delete':
                                                              _deletePurchase(
                                                                purchase,
                                                              );
                                                          }
                                                        },
                                                        itemBuilder:
                                                            (context) => const [
                                                              PopupMenuItem(
                                                                value:
                                                                    'details',
                                                                child: Text(
                                                                  'Ver detalhes',
                                                                ),
                                                              ),
                                                              PopupMenuItem(
                                                                value: 'delete',
                                                                child: Text(
                                                                  'Excluir fechamento',
                                                                ),
                                                              ),
                                                            ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPurchaseHistoryState extends StatelessWidget {
  const _EmptyPurchaseHistoryState({
    required this.hasQuery,
    required this.onClearSearch,
    required this.onCreateList,
  });

  final bool hasQuery;
  final VoidCallback onClearSearch;
  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'Nenhum fechamento encontrado'
        : 'Sem histórico de compras';
    final description = hasQuery
        ? 'Tente outro termo para lista ou produto.'
        : 'Feche uma compra para ver gastos por mês.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 82,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar busca'),
              ),
            ] else ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreateList,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar lista'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedPurchaseDetailsSheet extends StatelessWidget {
  const _CompletedPurchaseDetailsSheet({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final orderedItems = [...purchase.items]
      ..sort((a, b) {
        if (a.isPurchased != b.isPurchased) {
          return a.isPurchased ? -1 : 1;
        }
        return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
      children: [
        _HistoryContentPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                purchase.listName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Fechada em ${formatDateTime(purchase.closedAt)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HistoryPillLabel(
                    icon: Icons.shopping_bag_rounded,
                    text: purchase.productsCount == 1
                        ? '1 produto'
                        : '${purchase.productsCount} produtos',
                  ),
                  _HistoryPillLabel(
                    icon: Icons.confirmation_number_rounded,
                    text: formatUnitCount(purchase.totalItems),
                  ),
                  _HistoryPillLabel(
                    icon: Icons.attach_money_rounded,
                    text: 'Planejado ${formatCurrency(purchase.totalValue)}',
                  ),
                  _HistoryPillLabel(
                    icon: Icons.check_circle_rounded,
                    text: 'Comprado ${formatCurrency(purchase.purchasedValue)}',
                  ),
                  if (purchase.pendingProductsCount > 0)
                    _HistoryPillLabel(
                      icon: Icons.pending_actions_rounded,
                      text: purchase.pendingProductsCount == 1
                          ? '1 pendente'
                          : '${purchase.pendingProductsCount} pendentes',
                    ),
                  if (purchase.hasBudget)
                    _HistoryPillLabel(
                      icon: Icons.account_balance_wallet_rounded,
                      text: 'Orçamento ${formatCurrency(purchase.budget!)}',
                    ),
                  if (purchase.hasPaymentBalances)
                    _HistoryPillLabel(
                      icon: Icons.payments_rounded,
                      text:
                          'Saldos ${formatCurrency(purchase.paymentBalancesTotal)}',
                    ),
                  if (purchase.hasPaymentBalances)
                    _HistoryPillLabel(
                      icon: purchase.uncoveredSpentAmount > 0
                          ? Icons.error_outline_rounded
                          : Icons.check_circle_rounded,
                      text: purchase.uncoveredSpentAmount > 0
                          ? 'Falta ${formatCurrency(purchase.uncoveredSpentAmount)}'
                          : 'Coberto ${formatCurrency(purchase.coveredSpentAmount)}',
                    ),
                ],
              ),
            ],
          ),
        ),
        if (purchase.hasPaymentBalances) ...[
          const SizedBox(height: 12),
          _CompletedPurchasePaymentPanel(purchase: purchase),
        ],
        const SizedBox(height: 12),
        ...orderedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HistoryContentPanel(
              child: Row(
                children: [
                  Icon(
                    item.isPurchased
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.isPurchased
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} x ${formatCurrency(item.unitPrice)} - ${item.category.label}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    formatCurrency(item.subtotal),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CompletedPurchasePaymentPanel extends StatelessWidget {
  const _CompletedPurchasePaymentPanel({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = purchase.paymentUsage
        .where((entry) => entry.balance.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return _HistoryContentPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como a compra foi paga',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Despesa considerada: ${formatCurrency(purchase.spentValue)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
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
            if (purchase.uncoveredSpentAmount > 0)
              Text(
                'Ainda sem cobertura: ${formatCurrency(purchase.uncoveredSpentAmount)}',
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

Duration _historyAdaptiveMotionDuration(
  BuildContext context,
  Duration fallback,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class _HistorySummaryPill extends StatelessWidget {
  const _HistorySummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: _historyAdaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Text(
                  value,
                  key: ValueKey('$label|$value'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryContentPanel extends StatelessWidget {
  const _HistoryContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _HistoryPillLabel extends StatelessWidget {
  const _HistoryPillLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = colorScheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 5),
            Text(
              text,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
