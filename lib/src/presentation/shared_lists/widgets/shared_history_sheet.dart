import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/remote/shared_lists_repository.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';
import '../../utils/app_modal.dart';

class SharedHistorySheet extends StatelessWidget {
  const SharedHistorySheet({
    super.key,
    required this.list,
    required this.repository,
  });

  final SharedShoppingListSummary list;
  final SharedListsRepository repository;

  Map<DateTime, List<CompletedPurchase>> _groupByMonth(
    List<CompletedPurchase> entries,
  ) {
    final groups = <DateTime, List<CompletedPurchase>>{};
    for (final entry in entries) {
      final key = DateTime(entry.closedAt.year, entry.closedAt.month);
      groups.putIfAbsent(key, () => <CompletedPurchase>[]).add(entry);
    }
    final orderedKeys = groups.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final ordered = <DateTime, List<CompletedPurchase>>{};
    for (final key in orderedKeys) {
      final entriesForMonth = groups[key]!
        ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
      ordered[key] = List.unmodifiable(entriesForMonth);
    }
    return Map.unmodifiable(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico compartilhado',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Compras fechadas da lista "${list.name}".',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: min(MediaQuery.sizeOf(context).height * 0.6, 420),
            child: StreamBuilder<List<CompletedPurchase>>(
              stream: repository.watchSharedHistory(list.id),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <CompletedPurchase>[];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma compra fechada ainda.'),
                  );
                }
                final grouped = _groupByMonth(entries);
                return ListView(
                  children: grouped.entries
                      .map((entry) {
                        final monthLabel = DateFormat(
                          'MMMM yyyy',
                          'pt_BR',
                        ).format(entry.key);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthLabel,
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...entry.value.map((purchase) {
                                return SharedHistoryCard(purchase: purchase);
                              }),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SharedHistoryCard extends StatelessWidget {
  const SharedHistoryCard({super.key, required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.54),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          formatDateTime(purchase.closedAt),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${purchase.productsCount} itens · Total ${formatCurrency(purchase.totalValue)}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showAppDialog<void>(
          context: context,
          builder: (_) => SharedHistoryDetailsSheet(purchase: purchase),
        ),
      ),
    );
  }
}

class SharedHistoryDetailsSheet extends StatelessWidget {
  const SharedHistoryDetailsSheet({super.key, required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Detalhes da compra'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDateTime(purchase.closedAt),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total: ${formatCurrency(purchase.totalValue)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...purchase.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.name, style: textTheme.bodyMedium),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (purchase.hasPaymentBalances) ...[
                const SizedBox(height: 10),
                Text(
                  'Saldos utilizados',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...purchase.paymentUsage.map((entry) {
                  return Text(
                    '${entry.balance.name}: ${formatCurrency(entry.consumed)}',
                    style: textTheme.bodySmall,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
