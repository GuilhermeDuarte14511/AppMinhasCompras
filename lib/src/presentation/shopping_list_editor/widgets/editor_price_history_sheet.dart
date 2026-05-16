import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import 'editor_chrome_widgets.dart';

class EditorPriceHistorySheet extends StatelessWidget {
  const EditorPriceHistorySheet({super.key, required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final history = [...item.priceHistory]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
      children: [
        Text(
          'Histórico de preços',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          item.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const ListTile(title: Text('Sem histórico registrado ainda.'))
        else
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final previous = index + 1 < history.length
                ? history[index + 1]
                : null;
            final delta = previous == null
                ? null
                : record.price - previous.price;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: EditorContentPanel(
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatCurrency(record.price),
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatDateTime(record.recordedAt),
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
                      delta == null
                          ? 'Inicial'
                          : '${delta >= 0 ? '+' : '-'} ${formatCurrency(delta.abs())}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: delta == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : delta > 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
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
