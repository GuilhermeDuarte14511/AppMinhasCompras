import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../../../data/remote/shared_lists_repository.dart';

class SharedEditorialSummary extends StatelessWidget {
  const SharedEditorialSummary({
    super.key,
    required this.list,
    required this.items,
    required this.isOwner,
  });
  final SharedShoppingListSummary list;
  final List<SharedShoppingItem> items;
  final bool isOwner;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final picked = items
        .where((item) => item.isPurchased)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
    final count = items.where((item) => item.isPurchased).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              '${formatCountLabel(list.memberCount, 'membro', 'membros')} · ${isOwner ? 'Dono' : 'Membro'}',
              style: theme.textTheme.bodySmall,
            ),
            if (list.isClosed)
              Text(
                'Lista fechada',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLowest,
            border: Border.all(color: colors.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (list.hasBudget) ...[
                Text(
                  'Orçamento: ${formatCurrency(list.budget!)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
              ],
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    for (final entry in [
                      ('Estimado', total),
                      ('Já pego', picked),
                    ])
                      SizedBox(
                        width: (constraints.maxWidth - 16) / 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.$1, style: theme.textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              formatCurrency(entry.$2),
                              style: theme.textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: items.isEmpty ? 0 : count / items.length,
                minHeight: 4,
                backgroundColor: colors.outlineVariant,
              ),
              const SizedBox(height: 8),
              Text(
                '${formatCountLabel(items.length - count, 'pendente', 'pendentes')} · ${formatCountLabel(count, 'comprado', 'comprados')} · ${formatCurrency(total - picked)} falta pegar',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
