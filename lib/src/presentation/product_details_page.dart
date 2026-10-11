import 'dart:math';

import 'package:flutter/material.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import '../domain/product_price_analysis.dart';
import 'dialogs_and_sheets.dart';
import 'theme/editorial_workspace_theme.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

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
    final price = await showAppDialog<double>(
      context: context,
      builder: (context) => Theme(
        data: editorialWorkspaceTheme(Theme.of(context)),
        child: _ProductPriceDialog(initialPrice: product.unitPrice ?? 0),
      ),
    );

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
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) {
            final product = _currentProduct();
            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Detalhes do produto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                titleSpacing: 0,
                leadingWidth: 40,
                actions: [
                  if (product != null) ...[
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Editar produto',
                      onPressed: () => _editProduct(product),
                      icon: const Icon(Icons.edit_rounded),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Atualizar preço',
                      onPressed: () => _updatePrice(product),
                      icon: const Icon(Icons.price_change_rounded),
                    ),
                    IconButton(
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Excluir produto',
                      onPressed: () => _deleteProduct(product),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ],
              ),
              body: SafeArea(
                child: product == null
                    ? const _ProductRemovedState()
                    : _ProductDetailsContent(product: product),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProductDetailsContent extends StatelessWidget {
  const _ProductDetailsContent({required this.product});
  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final analysis = ProductPriceAnalysis.fromHistory(product.priceHistory);
    final monthly = _monthlyChartEntries(analysis.entries);
    final advice = ProductPriceAdvice.fromAnalysis(analysis);
    final history = analysis.entries.reversed.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Chip(
                    label: Text(product.category.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  const Spacer(),
                  Text(
                    '${product.usageCount} usos',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(product.name, style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                'Atualizado em ${formatShortDate(product.updatedAt)}',
                style: theme.textTheme.bodySmall,
              ),
              if (product.barcode?.isNotEmpty == true) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Icon(
                      Icons.view_week_outlined,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        product.barcode!,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 28),
              _ProductPaper(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PREÇO ATUAL',
                              style: theme.textTheme.labelSmall,
                            ),
                            Text(
                              _formatNullablePrice(product.unitPrice),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 32,
                              ),
                            ),
                          ],
                        ),
                        Tooltip(
                          message: analysis.summaryLabel,
                          child: Chip(
                            avatar: Icon(
                              analysis.absoluteDelta < 0
                                  ? Icons.south_rounded
                                  : analysis.absoluteDelta > 0
                                  ? Icons.north_rounded
                                  : Icons.horizontal_rule,
                              size: 14,
                            ),
                            label: Text(
                              analysis.hasEnoughHistory
                                  ? '${analysis.absoluteDelta < 0 ? '-' : '+'}${formatCurrency(analysis.absoluteDelta.abs())} (${analysis.percentDelta.toStringAsFixed(1).replaceAll('.', ',')}%)'
                                  : analysis.summaryLabel,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (analysis.hasEnoughHistory) ...[
                      const SizedBox(height: 8),
                      Text(
                        analysis.summaryLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const Divider(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) => Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          for (final stat in [
                            ('MÍNIMA', analysis.lowestPrice),
                            ('MÉDIA', analysis.averagePrice),
                            ('MÁXIMA', analysis.highestPrice),
                          ])
                            SizedBox(
                              width: (constraints.maxWidth - 16) / 3,
                              child: Column(
                                children: [
                                  Text(
                                    stat.$1,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNullablePrice(stat.$2),
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    Text(
                      _chartRangeLabel(
                        shownCount: monthly.length,
                        totalCount: _monthlyPriceCount(analysis.entries),
                      ),
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Um ponto por mês: sempre o último preço salvo.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    if (monthly.length < 2)
                      Text(
                        'Ainda não há meses suficientes para desenhar a tendência.',
                        style: theme.textTheme.bodySmall,
                      )
                    else
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLow,
                          border: Border.all(color: colors.outlineVariant),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Semantics(
                                label:
                                    'Gráfico mensal com ${monthly.length} meses. Último preço salvo por mês. Faixa ${_chartPriceRangeLabel(monthly)}.',
                                child: SizedBox(
                                  height: 110,
                                  width: double.infinity,
                                  child: CustomPaint(
                                    painter: _PriceHistoryChartPainter(
                                      entries: monthly,
                                      lineColor: colors.primary,
                                      fillColor: colors.primary.withValues(
                                        alpha: .15,
                                      ),
                                      gridColor: colors.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                              _ChartMonthLabels(entries: monthly),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Histórico de preço',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${history.length} registros',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const Divider(height: 16),
              _ProductPaper(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    Container(
                      color: colors.surfaceContainerLow,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'DATA DE REGISTRO',
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          Text('VALOR', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                    if (history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Nenhum preço registrado ainda.'),
                      ),
                    for (var i = 0; i < history.length; i++) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    formatDateTime(history[i].recordedAt),
                                    style: theme.textTheme.bodySmall,
                                  ),
                                  if (i == 0)
                                    Text(
                                      'Mais recente',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: colors.primary),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatCurrency(history[i].price),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ProductPaper(
                background: colors.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ANÁLISE LOCAL DE PREÇO',
                      style: theme.textTheme.labelSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      advice.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(advice.message, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPaper extends StatelessWidget {
  const _ProductPaper({
    required this.child,
    this.background,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final Color? background;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: background ?? Theme.of(context).colorScheme.surfaceContainerLowest,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(8),
    ),
    child: child,
  );
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

class _ProductPriceDialog extends StatefulWidget {
  const _ProductPriceDialog({required this.initialPrice});
  final double initialPrice;
  @override
  State<_ProductPriceDialog> createState() => _ProductPriceDialogState();
}

class _ProductPriceDialogState extends State<_ProductPriceDialog> {
  final _formatter = BrlCurrencyInputFormatter();
  final _formKey = GlobalKey<FormState>();
  late final _controller = TextEditingController(
    text: _formatter.formatValue(widget.initialPrice),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Atualizar preço'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [_formatter],
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
            if (_formKey.currentState?.validate() != true) {
              return;
            }
            Navigator.pop(
              context,
              BrlCurrencyInputFormatter.tryParse(_controller.text),
            );
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
