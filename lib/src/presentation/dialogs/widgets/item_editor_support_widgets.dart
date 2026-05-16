import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/models_and_utils.dart';
import '../../../domain/product_price_analysis.dart';
import '../../utils/item_price_insight.dart';

class ItemPriceInsightBanner extends StatelessWidget {
  const ItemPriceInsightBanner({super.key, required this.insight});

  final ItemPriceInsight insight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (
      backgroundColor,
      foregroundColor,
      icon,
    ) = switch (insight.direction) {
      PriceInsightDirection.down => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        Icons.south_rounded,
      ),
      PriceInsightDirection.same => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.remove_rounded,
      ),
      PriceInsightDirection.up => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.north_rounded,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LocalPriceAdviceBanner extends StatelessWidget {
  const LocalPriceAdviceBanner({super.key, required this.advice});

  final ProductPriceAdvice advice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (backgroundColor, foregroundColor, icon) = switch (advice.type) {
      ProductPriceAdviceType.bestPrice || ProductPriceAdviceType.goodPrice => (
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        Icons.verified_rounded,
      ),
      ProductPriceAdviceType.highPrice || ProductPriceAdviceType.recordHigh => (
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        Icons.report_gmailerrorred_rounded,
      ),
      ProductPriceAdviceType.normalPrice => (
        colorScheme.surfaceContainerHighest,
        colorScheme.onSurfaceVariant,
        Icons.balance_rounded,
      ),
      ProductPriceAdviceType.learning => (
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        Icons.school_rounded,
      ),
      ProductPriceAdviceType.noPrice => (
        colorScheme.secondaryContainer,
        colorScheme.onSecondaryContainer,
        Icons.lightbulb_rounded,
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: foregroundColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assistente de preço',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    advice.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: foregroundColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    advice.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foregroundColor.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogSuggestionTile extends StatelessWidget {
  const CatalogSuggestionTile({
    super.key,
    required this.product,
    required this.onTap,
  });

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_rounded),
      title: Text(product.name),
      subtitle: Text(product.barcode ?? 'Sem código'),
      onTap: onTap,
    );
  }
}

class PendingDraftsPreview extends StatelessWidget {
  const PendingDraftsPreview({super.key, required this.drafts});

  final List<ShoppingItemDraft> drafts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final previewNames = drafts.take(3).map((draft) => draft.name).join(', ');
    final remaining = drafts.length - min(drafts.length, 3);
    final suffix = remaining > 0 ? ' +$remaining' : '';
    final itemLabel = drafts.length == 1 ? 'item pronto' : 'itens prontos';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.playlist_add_check_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${drafts.length} $itemLabel: $previewNames$suffix',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogPriceHint extends StatelessWidget {
  const CatalogPriceHint({super.key, required this.product});

  final CatalogProduct product;

  @override
  Widget build(BuildContext context) {
    final history = product.priceHistory;
    final latestPrice =
        product.unitPrice ?? (history.isNotEmpty ? history.last.price : null);
    if (latestPrice == null || latestPrice <= 0) {
      return const SizedBox.shrink();
    }

    final previousPrice = history.length > 1
        ? history[history.length - 2].price
        : null;
    final variation = previousPrice == null || previousPrice <= 0
        ? null
        : ((latestPrice - previousPrice) / previousPrice) * 100;
    final variationText = variation == null
        ? 'Primeiro preço salvo no catálogo.'
        : variation > 0
        ? 'Subiu ${variation.abs().toStringAsFixed(1)}% em relação ao registro anterior.'
        : variation < 0
        ? 'Caiu ${variation.abs().toStringAsFixed(1)}% em relação ao registro anterior.'
        : 'Preço igual ao registro anterior.';

    final latestDate = history.isNotEmpty
        ? formatDateTime(history.last.recordedAt)
        : formatDateTime(product.updatedAt);
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preço sugerido: ${formatCurrency(latestPrice)}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$variationText Histórico local: ${formatCountLabel(history.length, 'registro', 'registros')}. Última atualização: $latestDate.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptStatChip extends StatelessWidget {
  const ReceiptStatChip({super.key, required this.icon, required this.text});

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
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
