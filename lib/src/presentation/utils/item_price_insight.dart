enum PriceInsightDirection { down, same, up }

const _priceInsightTolerance = 0.0001;

class ItemPriceInsight {
  const ItemPriceInsight({
    required this.direction,
    required this.percentDelta,
    required this.label,
  });

  final PriceInsightDirection direction;
  final double percentDelta;
  final String label;
}

bool hasMeaningfulPriceDifference(double firstPrice, double secondPrice) {
  return (firstPrice - secondPrice).abs() >= _priceInsightTolerance;
}

ItemPriceInsight? buildPriceInsight({
  required double currentPrice,
  required double referencePrice,
}) {
  if (referencePrice <= 0 || currentPrice <= 0) {
    return null;
  }

  final percentDelta = ((currentPrice - referencePrice) / referencePrice) * 100;
  if (!hasMeaningfulPriceDifference(currentPrice, referencePrice)) {
    return const ItemPriceInsight(
      direction: PriceInsightDirection.same,
      percentDelta: 0,
      label: 'Mesmo preço da última compra',
    );
  }

  final roundedPercent = percentDelta.abs().round();
  if (roundedPercent == 0) {
    return ItemPriceInsight(
      direction: PriceInsightDirection.same,
      percentDelta: percentDelta,
      label: 'Mesmo preço da última compra',
    );
  }

  if (percentDelta.isNegative) {
    return ItemPriceInsight(
      direction: PriceInsightDirection.down,
      percentDelta: percentDelta,
      label: '$roundedPercent% menor que o último preço salvo',
    );
  }

  return ItemPriceInsight(
    direction: PriceInsightDirection.up,
    percentDelta: percentDelta,
    label: '$roundedPercent% maior que o último preço salvo',
  );
}
