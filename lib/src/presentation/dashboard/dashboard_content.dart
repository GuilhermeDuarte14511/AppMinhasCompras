import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/pantry.dart';
import 'dashboard_icons.dart';
import '../theme/mercado_editorial_theme.dart';

ThemeData dashboardTheme(ThemeData base) => mercadoEditorialTheme(base);

class DashboardShortcut {
  const DashboardShortcut({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final Key key;
  final String title, subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({
    super.key,
    required this.lists,
    required this.catalogCount,
    required this.pantry,
    required this.suggestions,
    required this.shortcuts,
    required this.onCreate,
    required this.onLists,
    required this.onReplenish,
    required this.onPantry,
    required this.onOpenList,
    required this.onContinue,
    this.activeList,
    this.sharedSection,
  });
  final List<ShoppingListModel> lists;
  final int catalogCount;
  final List<PantryItem> pantry;
  final List<ReplenishmentSuggestion> suggestions;
  final List<DashboardShortcut> shortcuts;
  final VoidCallback onCreate, onLists, onReplenish, onPantry;
  final ValueChanged<ShoppingListModel> onOpenList, onContinue;
  final ShoppingListModel? activeList;
  final Widget? sharedSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final pending = lists.fold<double>(
      0,
      (sum, list) => sum + list.pendingValue,
    );
    final open = lists.where((list) => !list.isClosed).length;
    final budgeted = lists
        .where((list) => !list.isClosed && list.hasBudget)
        .toList();
    final budget = budgeted.fold<double>(0, (sum, list) => sum + list.budget!);
    final inStock = pantry
        .where((item) => item.status == PantryStockStatus.inStock)
        .length;
    final restock = pantry
        .where(
          (item) =>
              item.status == PantryStockStatus.runningLow ||
              item.status == PantryStockStatus.outOfStock,
        )
        .length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Panel(
            key: const ValueKey('dash_summary'),
            background: colors.surfaceContainerLow,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Resumo das compras',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                    Text(
                      formatCountLabel(lists.length, 'lista', 'listas'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                _Rule(),
                Row(
                  children: [
                    _Metric(
                      label: 'Abertas',
                      value: formatCountLabel(open, 'lista', 'listas'),
                    ),
                    _Metric(
                      label: 'Fechadas',
                      value: formatCountLabel(
                        lists.length - open,
                        'fechada',
                        'fechadas',
                      ),
                    ),
                    _Metric(
                      label: 'Catálogo',
                      value: formatCountLabel(
                        catalogCount,
                        'produto',
                        'produtos',
                      ),
                    ),
                  ],
                ),
                _Rule(),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total previsto pendente',
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          formatCurrency(pending),
                          style: theme.textTheme.titleLarge,
                        ),
                        if (budgeted.isNotEmpty)
                          Text(
                            'Teto definido: ${formatCurrency(budget)}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                    FilledButton.icon(
                      key: const ValueKey('dash_action_new'),
                      onPressed: onCreate,
                      icon: const Icon(DashboardIcons.add, size: 16),
                      label: const Text('Nova lista'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _Heading('Acesso rápido'),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(12) > 16
                  ? 1
                  : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: shortcuts
                    .where(
                      (action) =>
                          action.key != const ValueKey('dash_action_new') &&
                          action.key != const ValueKey('dash_action_based'),
                    )
                    .map(
                      (action) =>
                          SizedBox(width: width, child: _ShortcutTile(action)),
                    )
                    .toList(),
              );
            },
          ),
          ...shortcuts
              .where(
                (action) => action.key == const ValueKey('dash_action_based'),
              )
              .map(
                (action) => Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ShortcutTile(action),
                ),
              ),
          if (activeList != null) ...[
            const SizedBox(height: 24),
            const _Heading('Lista em andamento'),
            const SizedBox(height: 4),
            Text(activeList!.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _ActiveList(
              list: activeList!,
              onOpen: () => onOpenList(activeList!),
              onContinue: () => onContinue(activeList!),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _Heading('Reposição sugerida'),
            const SizedBox(height: 8),
            _Panel(
              key: const ValueKey('dash_smart_replenishment_card'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Próxima compra sugerida',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    suggestions.any(
                          (item) =>
                              item.source ==
                              ReplenishmentSuggestionSource.recurring,
                        )
                        ? 'Baseada nos itens que você repete.'
                        : 'Comece com produtos do seu catálogo.',
                    style: theme.textTheme.bodySmall,
                  ),
                  ...suggestions
                      .take(3)
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: theme.textTheme.labelLarge,
                              ),
                              Text(
                                'Preço estimado: ${formatCurrency(item.suggestedUnitPrice)}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  _Rule(),
                  Text(
                    'Previsto: ${formatCurrency(suggestions.fold<double>(0, (sum, item) => sum + item.estimatedTotal))}',
                    style: theme.textTheme.labelLarge,
                  ),
                  if (suggestions.length > 3)
                    Text(
                      '+${suggestions.length - 3} itens sugeridos',
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: onReplenish,
                    child: const Text('Criar lista'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _Panel(
            key: const ValueKey('dash_pantry_strip'),
            onTap: onPantry,
            child: Row(
              children: [
                Icon(DashboardIcons.pantry, color: colors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Despensa', style: theme.textTheme.titleMedium),
                      Text(
                        pantry.isEmpty
                            ? 'Comece com produtos do catálogo.'
                            : '${formatCountLabel(inStock, 'disponível', 'disponíveis')} · $restock para repor',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Listas recentes',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (lists.isNotEmpty)
                TextButton(onPressed: onLists, child: const Text('Ver todas')),
            ],
          ),
          const SizedBox(height: 8),
          _Panel(
            child: lists.isEmpty
                ? Text(
                    'Crie sua primeira lista para começar.',
                    style: theme.textTheme.bodySmall,
                  )
                : Column(
                    children: lists
                        .take(3)
                        .map(
                          (list) => ListTile(
                            key: ValueKey('dash_recent_${list.id}'),
                            contentPadding: EdgeInsets.zero,
                            onTap: () => onOpenList(list),
                            title: Text(
                              list.name,
                              style: theme.textTheme.labelLarge,
                            ),
                            subtitle: Text(
                              '${list.isClosed ? 'Fechada' : 'Ativa'} · ${formatShortDate(list.updatedAt)} · ${formatItemCount(list.items.length)} · ${formatCountLabel(list.purchasedItemsCount, 'comprado', 'comprados')} · ${formatUnitCount(list.totalItems)}',
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: Text(
                              formatCurrency(list.totalValue),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (sharedSection != null) ...[
            const SizedBox(height: 24),
            sharedSection!,
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({super.key, required this.child, this.background, this.onTap});
  final Widget child;
  final Color? background;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: background ?? Theme.of(context).colorScheme.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .8),
      ),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    ),
  );
}

class _Rule extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .4),
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.labelLarge);
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile(this.action);
  final DashboardShortcut action;
  @override
  Widget build(BuildContext context) => Material(
    key: action.key,
    color: Theme.of(context).colorScheme.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: .6),
      ),
    ),
    child: InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(
              action.icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    action.title,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    action.subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 10),
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

class _ActiveList extends StatelessWidget {
  const _ActiveList({
    required this.list,
    required this.onOpen,
    required this.onContinue,
  });
  final ShoppingListModel list;
  final VoidCallback onOpen, onContinue;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = list.items.isEmpty
        ? 0.0
        : list.purchasedItemsCount / list.items.length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total estimado', style: theme.textTheme.bodySmall),
                    Text(
                      formatCurrency(list.totalValue),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Orçamento teto', style: theme.textTheme.bodySmall),
                    Text(
                      list.hasBudget
                          ? formatCurrency(list.budget!)
                          : 'Não definido',
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          _Rule(),
          Text(
            '${list.purchasedItemsCount} de ${formatItemCount(list.items.length)} ${list.items.length == 1 ? 'comprado' : 'comprados'} · ${(progress * 100).round()}%',
            style: theme.textTheme.bodySmall,
          ),
          if (list.hasBudget)
            Text(
              list.isOverBudget
                  ? 'Acima do teto: ${formatCurrency(list.overBudgetAmount)}'
                  : 'Restam ${formatCurrency(list.budgetRemaining)} do orçamento',
              style: theme.textTheme.bodySmall,
            ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: const Color(0xFF365943),
              backgroundColor: theme.colorScheme.surfaceContainerLow,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: onContinue,
                child: const Text('Continuar compra'),
              ),
              OutlinedButton(
                onPressed: onOpen,
                child: const Text('Abrir lista'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
