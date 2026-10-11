import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../data/remote/shared_lists_repository.dart';
import '../../../domain/models_and_utils.dart';
import '../../theme/editorial_workspace_theme.dart';

const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];
String _month(DateTime date) => '${_months[date.month - 1]} ${date.year}';
String _date(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

class SharedHistorySheet extends StatefulWidget {
  const SharedHistorySheet({
    super.key,
    required this.list,
    required this.repository,
  });
  final SharedShoppingListSummary list;
  final SharedListsRepository repository;
  @override
  State<SharedHistorySheet> createState() => _SharedHistorySheetState();
}

class _SharedHistorySheetState extends State<SharedHistorySheet> {
  late Stream<List<CompletedPurchase>> _history;
  @override
  void initState() {
    super.initState();
    _history = widget.repository.watchSharedHistory(widget.list.id);
  }

  @override
  void didUpdateWidget(SharedHistorySheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.list.id != widget.list.id) {
      _history = widget.repository.watchSharedHistory(widget.list.id);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        final text = Theme.of(context).textTheme;
        return LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            height: min(
              min(MediaQuery.sizeOf(context).height * .88, 820),
              constraints.maxHeight,
            ),
            child: ColoredBox(
              color: colors.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Fechar histórico',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                        Expanded(
                          child: Text(
                            'Histórico compartilhado',
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Compras fechadas da lista “${widget.list.name}”.',
                        style: text.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: StreamBuilder<List<CompletedPurchase>>(
                      stream: _history,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _HistoryState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Não foi possível carregar o histórico.',
                            message:
                                'Feche e abra novamente para tentar de novo.',
                          );
                        }
                        if (!snapshot.hasData &&
                            snapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Carregando histórico…'),
                              ],
                            ),
                          );
                        }
                        final entries = List<CompletedPurchase>.of(
                          snapshot.data ?? [],
                        )..sort((a, b) => b.closedAt.compareTo(a.closedAt));
                        if (entries.isEmpty) {
                          return const _HistoryState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Nenhuma compra fechada ainda.',
                            message:
                                'As compras finalizadas desta lista aparecerão aqui.',
                          );
                        }
                        final groups = <DateTime, List<CompletedPurchase>>{};
                        for (final purchase in entries) {
                          groups
                              .putIfAbsent(
                                DateTime(
                                  purchase.closedAt.year,
                                  purchase.closedAt.month,
                                ),
                                () => [],
                              )
                              .add(purchase);
                        }
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Compras finalizadas',
                                    style: text.labelLarge,
                                  ),
                                ),
                                Text(
                                  '${entries.length} ${entries.length == 1 ? 'registro' : 'registros'}',
                                  style: text.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            for (final group in groups.entries) ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _month(group.key),
                                  style: text.labelMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              for (final purchase in group.value)
                                SharedHistoryCard(
                                  key: ValueKey(purchase.id),
                                  purchase: purchase,
                                  initiallyExpanded:
                                      purchase.id == entries.first.id,
                                ),
                              const SizedBox(height: 20),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Fechar'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        );
      },
    ),
  );
}

class _HistoryState extends StatelessWidget {
  const _HistoryState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            icon,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class SharedHistoryCard extends StatefulWidget {
  const SharedHistoryCard({
    super.key,
    required this.purchase,
    this.initiallyExpanded = false,
  });
  final CompletedPurchase purchase;
  final bool initiallyExpanded;
  @override
  State<SharedHistoryCard> createState() => _SharedHistoryCardState();
}

class _SharedHistoryCardState extends State<SharedHistoryCard> {
  late bool _expanded = widget.initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final purchase = widget.purchase;
    return Container(
      decoration: BoxDecoration(
        color: _expanded ? colors.surfaceContainerLow : colors.surface,
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_date(purchase.closedAt), style: text.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    '${purchase.productsCount} ${purchase.productsCount == 1 ? 'item' : 'itens'} · Pago ${formatCurrency(purchase.spentValue)}',
                    style: text.bodySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_expanded ? 'Ocultar detalhes' : 'Ver detalhes'),
                          const SizedBox(width: 4),
                          Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: _PurchaseDetails(purchase: purchase),
            ),
        ],
      ),
    );
  }
}

class _PurchaseDetails extends StatelessWidget {
  const _PurchaseDetails({required this.purchase});
  final CompletedPurchase purchase;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 12),
        Text('Detalhes da compra', style: text.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Valor final pago: ${formatCurrency(purchase.spentValue)}',
          style: text.bodySmall?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: 8),
        for (final item in purchase.items) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Subtotal: ${formatCurrency(item.subtotal)}',
                  style: text.bodySmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        if (purchase.hasPaymentBalances) ...[
          const SizedBox(height: 16),
          Text('Saldos utilizados', style: text.labelLarge),
          for (final usage in purchase.paymentUsage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${usage.balance.name}: ${formatCurrency(usage.consumed)}',
                style: text.bodySmall,
              ),
            ),
        ],
      ],
    );
  }
}

class SharedHistoryDetailsSheet extends StatelessWidget {
  const SharedHistoryDetailsSheet({super.key, required this.purchase});
  final CompletedPurchase purchase;
  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(
      builder: (context) => AlertDialog(
        title: const Text('Detalhes da compra'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_date(purchase.closedAt)),
                const SizedBox(height: 12),
                _PurchaseDetails(purchase: purchase),
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
      ),
    ),
  );
}
