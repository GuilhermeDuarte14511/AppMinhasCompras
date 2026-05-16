import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';
import '../../extensions/classification_ui_extensions.dart';

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
    _selectedIndexes = <int>{
      for (var i = 0; i < widget.suggestions.length; i++) i,
    };
  }

  String _sourceLabel(ReplenishmentSuggestion suggestion) {
    switch (suggestion.source) {
      case ReplenishmentSuggestionSource.recurring:
        return 'Compra recorrente';
      case ReplenishmentSuggestionSource.lastMonth:
        return 'Baseado no mês passado';
      case ReplenishmentSuggestionSource.catalogFallback:
        return 'Baseado no catálogo';
    }
  }

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
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final allSelected = _selectedIndexes.length == widget.suggestions.length;
    final selectedSuggestions = widget.suggestions
        .asMap()
        .entries
        .where((entry) => _selectedIndexes.contains(entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);

    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.9, 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              'Reposição inteligente',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Selecione os itens sugeridos para montar a nova lista.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  selected: allSelected,
                  onSelected: (_) => _toggleSelectAll(),
                  label: Text(
                    allSelected ? 'Desmarcar tudo' : 'Selecionar tudo',
                  ),
                ),
                Chip(
                  avatar: const Icon(Icons.shopping_bag_rounded, size: 18),
                  label: Text(formatItemCount(selectedSuggestions.length)),
                ),
                Chip(
                  avatar: const Icon(Icons.attach_money_rounded, size: 18),
                  label: Text(
                    formatCurrency(
                      selectedSuggestions.fold<double>(
                        0,
                        (sum, item) =>
                            sum +
                            (item.suggestedUnitPrice * item.suggestedQuantity),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: widget.suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final suggestion = widget.suggestions[index];
                final isSelected = _selectedIndexes.contains(index);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) => _toggleSelection(index, value ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
                  title: Text(
                    suggestion.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SelectionInfoChip(
                          icon: Icons.inventory_2_rounded,
                          text:
                              '${suggestion.suggestedQuantity} x ${formatCurrency(suggestion.suggestedUnitPrice)}',
                        ),
                        _SelectionInfoChip(
                          icon: suggestion.category.icon,
                          text: suggestion.category.label,
                        ),
                        _SelectionInfoChip(
                          icon: Icons.history_rounded,
                          text:
                              '${formatCountLabel(suggestion.occurrences, 'compra', 'compras')} · ${formatShortDate(suggestion.lastPurchasedAt)}',
                        ),
                        _SelectionInfoChip(
                          icon: Icons.auto_awesome_rounded,
                          text: _sourceLabel(suggestion),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: selectedSuggestions.isEmpty
                        ? null
                        : () => Navigator.pop(context, selectedSuggestions),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text('Criar lista'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionInfoChip extends StatelessWidget {
  const _SelectionInfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
