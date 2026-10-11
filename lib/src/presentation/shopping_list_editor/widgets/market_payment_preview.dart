import 'package:flutter/material.dart';

import '../../../application/finance_integration.dart';
import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';

/// Read-only projection; actual payment still happens at checkout.
class MarketPaymentPreview extends StatefulWidget {
  const MarketPaymentPreview({
    super.key,
    required this.list,
    required this.onEditBalances,
    this.repository,
  });

  final ShoppingListModel list;
  final VoidCallback onEditBalances;
  final FinanceIntegrationRepository? repository;

  @override
  State<MarketPaymentPreview> createState() => _MarketPaymentPreviewState();
}

class _MarketPaymentPreviewState extends State<MarketPaymentPreview> {
  FinanceWorkspace? _workspace;
  bool _loading = false;
  int _generation = 0;

  String _linkedSources(ShoppingListModel list) => list.paymentBalances
      .where((balance) => balance.financeSourceId != null)
      .map(
        (balance) => '${balance.financeSourceKind}:${balance.financeSourceId}',
      )
      .join('|');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant MarketPaymentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_linkedSources(oldWidget.list) != _linkedSources(widget.list)) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    if (_linkedSources(widget.list).isEmpty || widget.repository == null) {
      setState(() {
        _workspace = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _workspace = null;
    });
    FinanceWorkspace? workspace;
    try {
      workspace = await widget.repository!.loadWorkspace().timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      // The cart remains usable offline; never present a stored budget as live balance.
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _workspace = workspace;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.list.copyWith(
      items: widget.list.items
          .where((item) => item.isPurchased)
          .toList(growable: false),
    );
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Carrinho: ${formatCurrency(cart.totalValue)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: widget.onEditBalances,
                  child: const Text('Meios de pagamento'),
                ),
              ],
            ),
            if (cart.paymentBalances.isEmpty)
              const Text('Escolha um saldo para acompanhar quanto vai sobrar.'),
            for (final usage in cart.paymentUsage) ...[
              const SizedBox(height: 4),
              _balanceLine(context, usage),
            ],
            if (cart.hasPaymentBalances && cart.uncoveredAmount > 0)
              Text(
                'Faltam ${formatCurrency(cart.uncoveredAmount)} nos valores reservados para esta lista.',
                style: TextStyle(color: scheme.error),
              ),
            if (_linkedSources(widget.list).isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(
                    _loading ? 'Consultando saldo…' : 'Atualizar saldo',
                  ),
                ),
              ),
            const Text(
              'Previsão para os itens pegos. Pagamento confirmado ao fechar a compra.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceLine(BuildContext context, PaymentUsage usage) {
    final balance = usage.balance;
    final linked = balance.financeSourceId != null;
    final source = _workspace?.availablePaymentSources
        .where(
          (source) =>
              source.id == balance.financeSourceId &&
              source.kind.wireValue == balance.financeSourceKind,
        )
        .firstOrNull;
    if (linked && source == null) {
      return Text(
        '${balance.name}: ${_loading ? 'consultando…' : 'saldo indisponível'}',
      );
    }
    final availableCents =
        source?.availableCents ?? (balance.value * 100).round();
    final remaining = availableCents - (usage.consumed * 100).round();
    final label = remaining < 0
        ? 'faltam ${formatCurrency(-remaining / 100)}'
        : 'saldo após pagar: ${formatCurrency(remaining / 100)}';
    return Text(
      '${balance.name} · $label${linked ? '' : ' (saldo informado)'}',
      key: ValueKey('market_balance_${balance.id}'),
      style: remaining < 0
          ? TextStyle(color: Theme.of(context).colorScheme.error)
          : null,
    );
  }
}
