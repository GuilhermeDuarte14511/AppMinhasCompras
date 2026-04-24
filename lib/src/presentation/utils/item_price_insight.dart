enum PriceInsightDirection { down, same, up }

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

ItemPriceInsight? buildPriceInsight({
  required double currentPrice,
  required double referencePrice,
}) {
  if (referencePrice <= 0 || currentPrice <= 0) {
    return null;
  }

  final percentDelta = ((currentPrice - referencePrice) / referencePrice) * 100;
  if (percentDelta.abs() < 0.0001) {
    return const ItemPriceInsight(
      direction: PriceInsightDirection.same,
      percentDelta: 0,
      label: 'Mesmo preco da ultima compra',
    );
  }

  final roundedPercent = percentDelta.abs().round();
  if (roundedPercent == 0) {
    return ItemPriceInsight(
      direction: PriceInsightDirection.same,
      percentDelta: percentDelta,
      label: 'Mesmo preco da ultima compra',
    );
  }

  if (percentDelta.isNegative) {
    return ItemPriceInsight(
      direction: PriceInsightDirection.down,
      percentDelta: percentDelta,
      label: '$roundedPercent% menor que o ultimo preco salvo',
    );
  }

  return ItemPriceInsight(
    direction: PriceInsightDirection.up,
    percentDelta: percentDelta,
    label: '$roundedPercent% maior que o ultimo preco salvo',
  );
}
