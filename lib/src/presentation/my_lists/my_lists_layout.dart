import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../domain/models_and_utils.dart';

enum MyListsFilter { all, active, closed, shared }

class MyListsLayout extends StatelessWidget {
  const MyListsLayout({
    super.key,
    required this.lists,
    required this.sharedCount,
    required this.visibleCount,
    required this.controller,
    required this.filter,
    required this.selectionMode,
    required this.onFilter,
    required this.onClear,
    required this.onCreate,
    required this.onTemplate,
    required this.onHistory,
    required this.onReplenishment,
    required this.rows,
  });

  final List<ShoppingListModel> lists;
  final int sharedCount, visibleCount;
  final TextEditingController controller;
  final MyListsFilter filter;
  final bool selectionMode;
  final ValueChanged<MyListsFilter> onFilter;
  final VoidCallback onClear, onCreate, onTemplate, onHistory, onReplenishment;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final open = lists.where((list) => !list.isClosed).length;
    final pending = lists.fold<double>(
      0,
      (sum, list) => sum + list.pendingValue,
    );
    final filtered = controller.text.isNotEmpty || filter != MyListsFilter.all;
    final counts = {
      MyListsFilter.all: lists.length,
      MyListsFilter.active: open,
      MyListsFilter.closed: lists.length - open,
      MyListsFilter.shared: sharedCount,
    };
    final labels = {
      MyListsFilter.all: 'Todas',
      MyListsFilter.active: 'Abertas',
      MyListsFilter.closed: 'Fechadas',
      MyListsFilter.shared: 'Compartilhadas',
    };
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 390),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!selectionMode) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RESUMO',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              letterSpacing: .8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${formatCountLabel(open, 'lista aberta', 'listas abertas')} · Prev. ${formatCurrency(pending)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Nova lista'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: onTemplate,
                        icon: const Icon(Icons.copy_outlined, size: 14),
                        label: const Text('Criar com base em antiga'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: onHistory,
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 14,
                        ),
                        label: const Text('Histórico mensal'),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        onPressed: onReplenishment,
                        icon: const Icon(Icons.autorenew, size: 14),
                        label: const Text('Reposição inteligente'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar lista...',
                    filled: true,
                    fillColor: colors.surfaceContainerLowest,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar busca',
                            onPressed: controller.clear,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: colors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: MyListsFilter.values
                        .map(
                          (value) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              key: ValueKey('my_lists_filter_${value.name}'),
                              selected: filter == value,
                              showCheckmark: false,
                              onSelected: (_) => onFilter(value),
                              selectedColor: const Color(0xFF365943),
                              backgroundColor: colors.surface,
                              side: BorderSide(
                                color: filter == value
                                    ? const Color(0xFF365943)
                                    : colors.outlineVariant,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: const StadiumBorder(),
                              label: Text(
                                '${labels[value]} (${counts[value]})',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: filter == value
                                      ? Colors.white
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        filtered
                            ? formatCountLabel(
                                visibleCount,
                                'resultado',
                                'resultados',
                              )
                            : 'REGISTROS RECENTES',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          letterSpacing: .8,
                        ),
                      ),
                    ),
                    if (filtered)
                      TextButton(
                        onPressed: onClear,
                        child: const Text('Limpar filtros'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              if (lists.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        'Nenhuma lista ainda',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crie sua primeira lista para começar.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onCreate,
                        child: const Text('Criar primeira lista'),
                      ),
                    ],
                  ),
                )
              else if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Text(
                        'Nenhuma lista encontrada',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tente outro nome ou limpe os filtros.',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: onClear,
                        child: const Text('Limpar filtros'),
                      ),
                    ],
                  ),
                )
              else
                Material(
                  color: colors.surfaceContainerLowest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .7),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
