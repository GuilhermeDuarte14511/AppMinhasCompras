import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';

class EditorPriceHistorySheet extends StatelessWidget {
  const EditorPriceHistorySheet({super.key, required this.item});
  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final history = [...item.priceHistory]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return ListView(
      key: const ValueKey('price_history_scroll'),
      shrinkWrap: true,
      padding: EdgeInsets.only(
        top: 4,
        bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Histórico de preços',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontFamily: 'MercadoNewsreader',
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Fechar histórico de preços',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22),
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.outlineVariant),
        if (history.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Sem histórico registrado ainda.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < history.length; index++) ...[
                  if (index > 0)
                    Divider(height: 1, color: colors.outlineVariant),
                  _PriceRecord(
                    record: history[index],
                    newest: index == 0,
                    previous: index + 1 < history.length
                        ? history[index + 1]
                        : null,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PriceRecord extends StatelessWidget {
  const _PriceRecord({
    required this.record,
    required this.newest,
    required this.previous,
  });
  final PriceHistoryEntry record;
  final bool newest;
  final PriceHistoryEntry? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final delta = previous == null ? null : record.price - previous!.price;
    final neutral = delta == null || delta == 0;
    final foreground = neutral
        ? colors.onSurfaceVariant
        : delta > 0
        ? colors.error
        : colors.primary;
    final background = neutral
        ? colors.surfaceContainer
        : delta > 0
        ? colors.errorContainer
        : colors.primaryContainer;
    final label = delta == null
        ? 'Inicial'
        : delta == 0
        ? 'Sem alteração'
        : '${delta > 0 ? '+' : '−'}${formatCurrency(delta.abs())}';
    final date = DateFormat.localeExists('pt_BR')
        ? DateFormat(
            "dd 'de' MMMM 'de' yyyy, HH:mm",
            'pt_BR',
          ).format(record.recordedAt)
        : formatDateTime(record.recordedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                formatCurrency(record.price),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: newest ? FontWeight.w600 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: foreground,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
