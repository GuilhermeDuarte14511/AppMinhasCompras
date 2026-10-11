import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/editorial_workspace_theme.dart';

class ReplenishmentSuggestionsSheet extends StatefulWidget {
  const ReplenishmentSuggestionsSheet({super.key, required this.suggestions});

  final List<ReplenishmentSuggestion> suggestions;

  @override
  State<ReplenishmentSuggestionsSheet> createState() =>
      _ReplenishmentSuggestionsSheetState();
}

class _ReplenishmentSuggestionsSheetState
    extends State<ReplenishmentSuggestionsSheet> {
  late final Set<int> _selectedIndexes;

  @override
  void initState() {
    super.initState();
    _selectedIndexes = {for (var i = 0; i < widget.suggestions.length; i++) i};
  }

  String _sourceLabel(ReplenishmentSuggestion suggestion) =>
      switch (suggestion.source) {
        ReplenishmentSuggestionSource.recurring => 'Compra recorrente',
        ReplenishmentSuggestionSource.lastMonth => 'Baseado no mês passado',
        ReplenishmentSuggestionSource.catalogFallback => 'Baseado no catálogo',
      };

  void _toggleSelection(int index, bool selected) {
    setState(() {
      if (selected) {
        _selectedIndexes.add(index);
      } else {
        _selectedIndexes.remove(index);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIndexes.length == widget.suggestions.length) {
        _selectedIndexes.clear();
      } else {
        _selectedIndexes
          ..clear()
          ..addAll(Iterable<int>.generate(widget.suggestions.length));
      }
    });
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(builder: _buildContent),
  );

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = widget.suggestions
        .asMap()
        .entries
        .where((entry) => _selectedIndexes.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);
    final total = selected.fold<double>(
      0,
      (sum, item) => sum + item.estimatedTotal,
    );
    final allSelected = selected.length == widget.suggestions.length;
    final moneyStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: min(
            MediaQuery.sizeOf(context).height * .84,
            min(720, constraints.maxHeight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Fechar reposição',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reposição inteligente',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sugestões baseadas no histórico e catálogo',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  border: Border.symmetric(
                    horizontal: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  spacing: 16,
                  children: [
                    Text(
                      '${selected.length} de ${widget.suggestions.length} selecionados',
                      style: theme.textTheme.labelMedium,
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Subtotal estimado',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          formatCurrency(total),
                          style: moneyStyle?.copyWith(color: colors.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (widget.suggestions.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    onPressed: _toggleSelectAll,
                    child: Text(
                      allSelected ? 'Desmarcar tudo' : 'Selecionar tudo',
                    ),
                  ),
                ),
              Expanded(
                child: widget.suggestions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma sugestão de reposição disponível.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: widget.suggestions.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                          color: colors.outlineVariant,
                        ),
                        itemBuilder: (context, index) {
                          final item = widget.suggestions[index];
                          return CheckboxListTile(
                            key: ValueKey('replenishment_$index'),
                            value: _selectedIndexes.contains(index),
                            onChanged: (value) =>
                                _toggleSelection(index, value ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            title: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Text(
                                  item.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  formatCurrency(item.estimatedTotal),
                                  style: moneyStyle,
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.suggestedQuantity} × ${formatCurrency(item.suggestedUnitPrice)} · ${item.category.label}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${formatCountLabel(item.occurrences, 'compra', 'compras')} · ${formatShortDate(item.lastPurchasedAt)}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  Text(
                                    _sourceLabel(item),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(top: BorderSide(color: colors.outlineVariant)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: selected.isEmpty
                            ? null
                            : () => Navigator.pop(context, selected),
                        icon: const Icon(Icons.playlist_add, size: 20),
                        label: Text('Criar lista (${selected.length})'),
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
      },
    );
  }
}
