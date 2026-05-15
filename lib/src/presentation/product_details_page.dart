import 'dart:math';

import 'package:flutter/material.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import '../domain/product_price_analysis.dart';
import 'dialogs_and_sheets.dart';
import 'extensions/classification_ui_extensions.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

enum _ProductDetailsAction { delete }

class ProductDetailsPage extends StatefulWidget {
  const ProductDetailsPage({
    super.key,
    required this.store,
    required this.productId,
  });

  final ShoppingListsStore store;
  final String productId;

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  CatalogProduct? _currentProduct() {
    for (final product in widget.store.catalogProducts) {
      if (product.id == widget.productId) {
        return product;
      }
    }
    return null;
  }

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
  }

  ShoppingItem _editableItemFromCatalog(CatalogProduct product) {
    return ShoppingItem(
      id: product.id,
      name: product.name,
      quantity: 1,
      unitPrice: product.unitPrice ?? 0,
      barcode: product.barcode,
      category: product.category,
      priceHistory: product.priceHistory,
    );
  }

  List<PriceHistoryEntry> _buildUpdatedPriceHistory({
    required CatalogProduct original,
    required double newPrice,
    required DateTime recordedAt,
  }) {
    final history = [...original.priceHistory];
    final currentPrice = original.unitPrice ?? 0;
    if (history.isEmpty && currentPrice > 0) {
      history.add(
        PriceHistoryEntry(price: currentPrice, recordedAt: original.updatedAt),
      );
    }
    final shouldAppend =
        history.isEmpty || (history.last.price - newPrice).abs() > 0.0001;
    if (shouldAppend) {
      history.add(PriceHistoryEntry(price: newPrice, recordedAt: recordedAt));
    }
    return history;
  }

  Future<void> _replaceProduct(CatalogProduct updated) async {
    final products = widget.store.catalogProducts
        .map((entry) => entry.id == updated.id ? updated : entry)
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(products);
  }

  Future<void> _editProduct(CatalogProduct product) async {
    final blockedNames = widget.store.catalogProducts
        .where((entry) => entry.id != product.id)
        .map((entry) => normalizeQuery(entry.name))
        .toSet();
    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: _editableItemFromCatalog(product),
      blockedNormalizedNames: blockedNames,
      catalogProducts: widget.store.catalogProducts,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );
    if (!mounted || draft == null) {
      return;
    }

    final now = DateTime.now();
    final updated = product.copyWith(
      name: draft.name,
      category: draft.category,
      unitPrice: draft.unitPrice,
      barcode: draft.barcode,
      clearBarcode: draft.barcode == null || draft.barcode!.trim().isEmpty,
      updatedAt: now,
      priceHistory: _buildUpdatedPriceHistory(
        original: product,
        newPrice: draft.unitPrice,
        recordedAt: now,
      ),
    );
    await _replaceProduct(updated);
    if (!mounted) {
      return;
    }
    _showSnack('Produto atualizado.', type: AppToastType.success);
  }

  Future<void> _updatePrice(CatalogProduct product) async {
    final formatter = BrlCurrencyInputFormatter();
    final initialPrice = product.unitPrice ?? 0;
    final controller = TextEditingController(
      text: formatter.formatValue(initialPrice > 0 ? initialPrice : 0),
    );
    final formKey = GlobalKey<FormState>();

    final price = await showAppDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Atualizar preço'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [formatter],
              decoration: const InputDecoration(
                labelText: 'Novo preço',
                prefixIcon: Icon(Icons.attach_money_rounded),
              ),
              validator: (value) {
                final parsed = BrlCurrencyInputFormatter.tryParse(value ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Informe um preço válido.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) {
                  return;
                }
                Navigator.pop(
                  context,
                  BrlCurrencyInputFormatter.tryParse(controller.text),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || price == null || price <= 0) {
      return;
    }

    final now = DateTime.now();
    final updated = product.copyWith(
      unitPrice: price,
      updatedAt: now,
      priceHistory: _buildUpdatedPriceHistory(
        original: product,
        newPrice: price,
        recordedAt: now,
      ),
    );
    await _replaceProduct(updated);
    if (!mounted) {
      return;
    }
    _showSnack('Preço atualizado.', type: AppToastType.success);
  }

  Future<void> _deleteProduct(CatalogProduct product) async {
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir produto?'),
        content: Text('Deseja excluir "${product.name}" do catálogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    final products = widget.store.catalogProducts
        .where((entry) => entry.id != product.id)
        .toList(growable: false);
    await widget.store.replaceCatalogProducts(products);
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final product = _currentProduct();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalhes do produto'),
            actions: [
              if (product != null) ...[
                IconButton(
                  tooltip: 'Editar produto',
                  onPressed: () => _editProduct(product),
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Atualizar preço',
                  onPressed: () => _updatePrice(product),
                  icon: const Icon(Icons.price_change_rounded),
                ),
                PopupMenuButton<_ProductDetailsAction>(
                  tooltip: 'Mais ações',
                  onSelected: (action) {
                    if (action == _ProductDetailsAction.delete) {
                      _deleteProduct(product);
                    }
                  },
                  itemBuilder: (context) =>
                      const <PopupMenuEntry<_ProductDetailsAction>>[
                        PopupMenuItem<_ProductDetailsAction>(
                          value: _ProductDetailsAction.delete,
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18),
                              SizedBox(width: 10),
                              Text('Excluir produto'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ],
          ),
          body: AppGradientScene(
            child: SafeArea(
              child: product == null
                  ? const _ProductRemovedState()
                  : _ProductDetailsContent(product: product),
            ),
          ),
        );
      },
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final analysis = ProductPriceAnalysis.fromHistory(product.priceHistory);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 24 + bottomInset),
      children: [
        _ProductHeader(product: product, analysis: analysis),
        const SizedBox(height: 12),
        _PriceTrendPanel(analysis: analysis),
        const SizedBox(height: 12),
        _PriceAdvicePanel(advice: ProductPriceAdvice.fromAnalysis(analysis)),
        const SizedBox(height: 12),
        _PriceChartPanel(analysis: analysis),
        const SizedBox(height: 12),
        _ProductStatsGrid(analysis: analysis),
        const SizedBox(height: 12),
        _PriceHistoryPanel(analysis: analysis),
      ],
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product, required this.analysis});

  final CatalogProduct product;
  final ProductPriceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return _DetailsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    product.category.icon,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(
                          icon: product.category.icon,
                          label: product.category.label,
                        ),
                        _InfoPill(
                          icon: Icons.history_toggle_off_rounded,
                          label: '${product.usageCount} usos',
                        ),
                        if (product.barcode != null &&
                            product.barcode!.isNotEmpty)
                          _InfoPill(
                            icon: Icons.qr_code_2_rounded,
                            label: product.barcode!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            analysis.latestPrice == null
                ? 'Sem preço salvo'
                : formatCurrency(analysis.latestPrice!),
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Atualizado em ${formatShortDate(product.updatedAt)}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceTrendPanel extends StatelessWidget {
  const _PriceTrendPanel({required this.analysis});

  final ProductPriceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tone = _trendTone(context, analysis.direction);
    final delta = analysis.absoluteDelta;
    final deltaLabel = analysis.hasEnoughHistory
        ? '${delta >= 0 ? '+' : '-'} ${formatCurrency(delta.abs())}'
        : 'Atualize o preço para comparar';

    return _DetailsPanel(
      backgroundColor: tone.background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: tone.foreground, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  analysis.summaryLabel,
                  style: textTheme.titleMedium?.copyWith(
                    color: tone.foreground,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deltaLabel,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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

class _PriceAdvicePanel extends StatelessWidget {
  const _PriceAdvicePanel({required this.advice});

  final ProductPriceAdvice advice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tone = _adviceTone(context, advice.type);
    return _DetailsPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tone.background,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(tone.icon, color: tone.foreground, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistente de preço',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  advice.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  advice.message,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _InfoPill(
                  icon: Icons.offline_bolt_rounded,
                  label: 'Análise local',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChartPanel extends StatelessWidget {
  const _PriceChartPanel({required this.analysis});

  final ProductPriceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final chartEntries = _monthlyChartEntries(analysis.entries);
    final totalMonthCount = _monthlyPriceCount(analysis.entries);
    return _DetailsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Histórico de preços',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _chartRangeLabel(
              shownCount: chartEntries.length,
              totalCount: totalMonthCount,
            ),
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Um ponto por mês: sempre o último preço salvo.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          if (chartEntries.length < 2)
            Text(
              'Ainda não há meses suficientes para desenhar a tendência.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else ...[
            Semantics(
              label:
                  'Gráfico mensal com ${chartEntries.length} meses. Cada ponto mostra o último preço salvo no mês. Faixa exibida ${_chartPriceRangeLabel(chartEntries)}.',
              child: SizedBox(
                height: 136,
                width: double.infinity,
                child: CustomPaint(
                  painter: _PriceHistoryChartPainter(
                    entries: chartEntries,
                    lineColor: colorScheme.primary,
                    fillColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.30,
                    ),
                    gridColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.62,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _ChartMonthLabels(entries: chartEntries),
          ],
        ],
      ),
    );
  }
}

List<PriceHistoryEntry> _monthlyChartEntries(List<PriceHistoryEntry> entries) {
  const chartLimit = 6;
  final sortedEntries =
      entries.where((entry) => entry.price > 0).toList(growable: false)
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final latestByMonth = <String, PriceHistoryEntry>{};
  for (final entry in sortedEntries) {
    latestByMonth[_monthKey(entry.recordedAt)] = entry;
  }
  final monthlyEntries = latestByMonth.values.toList(growable: false);
  if (monthlyEntries.length <= chartLimit) {
    return monthlyEntries;
  }
  return monthlyEntries.sublist(monthlyEntries.length - chartLimit);
}

int _monthlyPriceCount(List<PriceHistoryEntry> entries) {
  return {
    for (final entry in entries)
      if (entry.price > 0) _monthKey(entry.recordedAt),
  }.length;
}

String _monthKey(DateTime value) {
  return '${value.year}-${value.month.toString().padLeft(2, '0')}';
}

String _chartRangeLabel({required int shownCount, required int totalCount}) {
  if (shownCount == 0) {
    return 'Sem meses com preço';
  }
  if (totalCount > shownCount) {
    return 'Últimos $shownCount meses com preço';
  }
  return formatCountLabel(shownCount, 'mês com preço', 'meses com preço');
}

String _chartPriceRangeLabel(List<PriceHistoryEntry> entries) {
  if (entries.isEmpty) {
    return 'Sem preço';
  }
  final prices = entries.map((entry) => entry.price);
  final minPrice = prices.reduce(min);
  final maxPrice = prices.reduce(max);
  if ((maxPrice - minPrice).abs() < 0.0001) {
    return formatCurrency(maxPrice);
  }
  return '${formatCurrency(minPrice)} - ${formatCurrency(maxPrice)}';
}

String _monthLabel(DateTime value) {
  const labels = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return labels[value.month - 1];
}

class _ChartMonthLabels extends StatelessWidget {
  const _ChartMonthLabels({required this.entries});

  final List<PriceHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (final entry in entries)
          Expanded(
            child: Text(
              _monthLabel(entry.recordedAt),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProductStatsGrid extends StatelessWidget {
  const _ProductStatsGrid({required this.analysis});

  final ProductPriceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StatTile(
          icon: Icons.south_rounded,
          label: 'Menor preço',
          value: _formatNullablePrice(analysis.lowestPrice),
        ),
        _StatTile(
          icon: Icons.north_rounded,
          label: 'Maior preço',
          value: _formatNullablePrice(analysis.highestPrice),
        ),
        _StatTile(
          icon: Icons.functions_rounded,
          label: 'Média',
          value: _formatNullablePrice(analysis.averagePrice),
        ),
        _StatTile(
          icon: Icons.event_available_rounded,
          label: 'Registros',
          value: formatCountLabel(analysis.entries.length, 'preço', 'preços'),
        ),
      ],
    );
  }
}

class _PriceHistoryPanel extends StatelessWidget {
  const _PriceHistoryPanel({required this.analysis});

  final ProductPriceAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final history = [...analysis.entries]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final textTheme = Theme.of(context).textTheme;
    return _DetailsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linha do tempo',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Text(
              'Nenhum preço registrado ainda.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
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
              return _HistoryRow(record: record, delta: delta);
            }),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record, required this.delta});

  final PriceHistoryEntry record;
  final double? delta;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priceDelta = delta;
    final isIncrease = (priceDelta ?? 0) > 0;
    final isDecrease = (priceDelta ?? 0) < 0;
    final deltaColor = priceDelta == null
        ? colorScheme.onSurfaceVariant
        : isIncrease
        ? colorScheme.error
        : colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.26),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Icon(Icons.monetization_on_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatCurrency(record.price),
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      formatDateTime(record.recordedAt),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                priceDelta == null
                    ? 'Inicial'
                    : '${isIncrease
                          ? '+'
                          : isDecrease
                          ? '-'
                          : ''} ${formatCurrency(priceDelta.abs())}',
                style: textTheme.labelMedium?.copyWith(
                  color: deltaColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 164,
      child: _DetailsPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary, size: 20),
            const SizedBox(height: 8),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.child, this.backgroundColor});

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _ProductRemovedState extends StatelessWidget {
  const _ProductRemovedState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 52,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Produto não encontrado',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Esse item não está mais no catálogo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendTone {
  const _TrendTone({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

_TrendTone _trendTone(
  BuildContext context,
  ProductPriceTrendDirection direction,
) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (direction) {
    case ProductPriceTrendDirection.down:
      return _TrendTone(
        background: colorScheme.primaryContainer.withValues(alpha: 0.78),
        foreground: colorScheme.onPrimaryContainer,
        icon: Icons.trending_down_rounded,
      );
    case ProductPriceTrendDirection.up:
      return _TrendTone(
        background: colorScheme.errorContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onErrorContainer,
        icon: Icons.trending_up_rounded,
      );
    case ProductPriceTrendDirection.same:
      return _TrendTone(
        background: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        foreground: colorScheme.onSurfaceVariant,
        icon: Icons.trending_flat_rounded,
      );
    case ProductPriceTrendDirection.unknown:
      return _TrendTone(
        background: colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onTertiaryContainer,
        icon: Icons.insights_rounded,
      );
  }
}

_TrendTone _adviceTone(BuildContext context, ProductPriceAdviceType type) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (type) {
    case ProductPriceAdviceType.bestPrice:
    case ProductPriceAdviceType.goodPrice:
      return _TrendTone(
        background: colorScheme.primaryContainer.withValues(alpha: 0.76),
        foreground: colorScheme.onPrimaryContainer,
        icon: Icons.verified_rounded,
      );
    case ProductPriceAdviceType.highPrice:
    case ProductPriceAdviceType.recordHigh:
      return _TrendTone(
        background: colorScheme.errorContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onErrorContainer,
        icon: Icons.report_gmailerrorred_rounded,
      );
    case ProductPriceAdviceType.normalPrice:
      return _TrendTone(
        background: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        foreground: colorScheme.onSurfaceVariant,
        icon: Icons.balance_rounded,
      );
    case ProductPriceAdviceType.learning:
      return _TrendTone(
        background: colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onTertiaryContainer,
        icon: Icons.school_rounded,
      );
    case ProductPriceAdviceType.noPrice:
      return _TrendTone(
        background: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        foreground: colorScheme.onSecondaryContainer,
        icon: Icons.lightbulb_rounded,
      );
  }
}

String _formatNullablePrice(double? value) {
  if (value == null || value <= 0) {
    return 'Sem preço';
  }
  return formatCurrency(value);
}

class _PriceHistoryChartPainter extends CustomPainter {
  const _PriceHistoryChartPainter({
    required this.entries,
    required this.lineColor,
    required this.fillColor,
    required this.gridColor,
  });

  final List<PriceHistoryEntry> entries;
  final Color lineColor;
  final Color fillColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) {
      return;
    }

    const leftPadding = 8.0;
    const rightPadding = 8.0;
    const topPadding = 10.0;
    const bottomPadding = 16.0;
    final chartRect = Rect.fromLTRB(
      leftPadding,
      topPadding,
      size.width - rightPadding,
      size.height - bottomPadding,
    );
    final prices = entries.map((entry) => entry.price).toList(growable: false);
    var minPrice = prices.reduce(min);
    var maxPrice = prices.reduce(max);
    if ((maxPrice - minPrice).abs() < 0.0001) {
      minPrice -= 1;
      maxPrice += 1;
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = chartRect.top + chartRect.height * (i / 3);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    final points = <Offset>[];
    for (var i = 0; i < entries.length; i++) {
      final x =
          chartRect.left + (chartRect.width * (i / max(1, entries.length - 1)));
      final normalized = (entries[i].price - minPrice) / (maxPrice - minPrice);
      final y = chartRect.bottom - (chartRect.height * normalized);
      points.add(Offset(x, y));
    }

    final verticalGuidePaint = Paint()
      ..color = gridColor.withValues(alpha: 0.36)
      ..strokeWidth = 0.8;
    for (final point in points) {
      canvas.drawLine(
        Offset(point.dx, chartRect.top),
        Offset(point.dx, chartRect.bottom),
        verticalGuidePaint,
      );
    }

    final fillPath = Path()..moveTo(points.first.dx, chartRect.bottom);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath
      ..lineTo(points.last.dx, chartRect.bottom)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillColor, fillColor.withValues(alpha: 0.04)],
        ).createShader(chartRect),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      linePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final pointPaint = Paint()..color = lineColor;
    final pointBorderPaint = Paint()..color = Colors.white;
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final isEdgePoint = i == 0 || i == points.length - 1;
      canvas.drawCircle(point, isEdgePoint ? 6.2 : 5, pointBorderPaint);
      canvas.drawCircle(point, isEdgePoint ? 4 : 3.2, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PriceHistoryChartPainter oldDelegate) {
    return oldDelegate.entries != entries ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.gridColor != gridColor;
  }
}
