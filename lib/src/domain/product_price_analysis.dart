import 'dart:math';

import 'models_and_utils.dart';

enum ProductPriceTrendDirection { down, same, up, unknown }

enum ProductPriceAdviceType {
  noPrice,
  learning,
  bestPrice,
  goodPrice,
  normalPrice,
  highPrice,
  recordHigh,
}

class ProductPriceAnalysis {
  const ProductPriceAnalysis._({
    required this.entries,
    required this.direction,
    required this.summaryLabel,
    this.latestPrice,
    this.previousPrice,
    this.absoluteDelta = 0,
    this.percentDelta = 0,
    this.lowestPrice,
    this.highestPrice,
    this.averagePrice,
  });

  factory ProductPriceAnalysis.fromHistory(List<PriceHistoryEntry> history) {
    final entries =
        history.where((entry) => entry.price > 0).toList(growable: false)
          ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    if (entries.isEmpty) {
      return const ProductPriceAnalysis._(
        entries: <PriceHistoryEntry>[],
        direction: ProductPriceTrendDirection.unknown,
        summaryLabel: 'Sem preço salvo',
      );
    }

    final prices = entries.map((entry) => entry.price);
    final latestPrice = entries.last.price;
    final previousPrice = entries.length > 1
        ? entries[entries.length - 2].price
        : null;
    final lowestPrice = prices.reduce(min);
    final highestPrice = prices.reduce(max);
    final averagePrice =
        prices.reduce((sum, price) => sum + price) / entries.length;

    if (previousPrice == null || previousPrice <= 0) {
      return ProductPriceAnalysis._(
        entries: List.unmodifiable(entries),
        direction: ProductPriceTrendDirection.unknown,
        summaryLabel: 'Primeiro preço salvo',
        latestPrice: latestPrice,
        lowestPrice: lowestPrice,
        highestPrice: highestPrice,
        averagePrice: averagePrice,
      );
    }

    final absoluteDelta = latestPrice - previousPrice;
    final percentDelta = (absoluteDelta / previousPrice) * 100;
    final roundedPercent = percentDelta.abs().round();

    if (absoluteDelta.abs() < 0.0001 || roundedPercent == 0) {
      return ProductPriceAnalysis._(
        entries: List.unmodifiable(entries),
        direction: ProductPriceTrendDirection.same,
        summaryLabel: 'Mesmo preço do registro anterior',
        latestPrice: latestPrice,
        previousPrice: previousPrice,
        lowestPrice: lowestPrice,
        highestPrice: highestPrice,
        averagePrice: averagePrice,
      );
    }

    final direction = absoluteDelta.isNegative
        ? ProductPriceTrendDirection.down
        : ProductPriceTrendDirection.up;
    final relation = absoluteDelta.isNegative ? 'menor' : 'maior';
    return ProductPriceAnalysis._(
      entries: List.unmodifiable(entries),
      direction: direction,
      summaryLabel: '$roundedPercent% $relation que o registro anterior',
      latestPrice: latestPrice,
      previousPrice: previousPrice,
      absoluteDelta: absoluteDelta,
      percentDelta: percentDelta,
      lowestPrice: lowestPrice,
      highestPrice: highestPrice,
      averagePrice: averagePrice,
    );
  }

  final List<PriceHistoryEntry> entries;
  final ProductPriceTrendDirection direction;
  final String summaryLabel;
  final double? latestPrice;
  final double? previousPrice;
  final double absoluteDelta;
  final double percentDelta;
  final double? lowestPrice;
  final double? highestPrice;
  final double? averagePrice;

  bool get hasEnoughHistory => entries.length >= 2;
}

class ProductPriceAdvice {
  const ProductPriceAdvice({
    required this.type,
    required this.title,
    required this.message,
    this.percentFromAverage = 0,
  });

  factory ProductPriceAdvice.fromAnalysis(ProductPriceAnalysis analysis) {
    final latestPrice = analysis.latestPrice;
    final averagePrice = analysis.averagePrice;
    final lowestPrice = analysis.lowestPrice;
    final highestPrice = analysis.highestPrice;

    if (latestPrice == null || averagePrice == null) {
      return const ProductPriceAdvice(
        type: ProductPriceAdviceType.noPrice,
        title: 'Sem preço para analisar',
        message: 'Salve um preço para receber alertas locais.',
      );
    }

    if (analysis.entries.length < 3) {
      return const ProductPriceAdvice(
        type: ProductPriceAdviceType.learning,
        title: 'Ainda aprendendo o preço',
        message: 'Com mais registros, o alerta fica mais preciso.',
      );
    }

    if (lowestPrice != null && (latestPrice - lowestPrice).abs() < 0.0001) {
      return const ProductPriceAdvice(
        type: ProductPriceAdviceType.bestPrice,
        title: 'Melhor preço registrado',
        message: 'Está no menor valor salvo para este produto.',
      );
    }

    final percentFromAverage =
        ((latestPrice - averagePrice) / averagePrice) * 100;
    final roundedPercent = percentFromAverage.abs().round();

    if (highestPrice != null &&
        (latestPrice - highestPrice).abs() < 0.0001 &&
        percentFromAverage >= 25) {
      return ProductPriceAdvice(
        type: ProductPriceAdviceType.recordHigh,
        title: 'Maior preço registrado',
        message:
            'Está $roundedPercent% acima da média. Vale conferir antes de comprar.',
        percentFromAverage: percentFromAverage,
      );
    }

    if (percentFromAverage <= -10) {
      return ProductPriceAdvice(
        type: ProductPriceAdviceType.goodPrice,
        title: 'Preço bom',
        message: 'Está $roundedPercent% abaixo da média do histórico.',
        percentFromAverage: percentFromAverage,
      );
    }

    if (percentFromAverage >= 15) {
      return ProductPriceAdvice(
        type: ProductPriceAdviceType.highPrice,
        title: 'Preço acima da média',
        message: 'Está $roundedPercent% acima da média do histórico.',
        percentFromAverage: percentFromAverage,
      );
    }

    return const ProductPriceAdvice(
      type: ProductPriceAdviceType.normalPrice,
      title: 'Dentro do preço normal',
      message: 'Está perto da média salva para este produto.',
    );
  }

  factory ProductPriceAdvice.forCurrentPrice({
    required List<PriceHistoryEntry> history,
    required double currentPrice,
    DateTime? recordedAt,
  }) {
    if (currentPrice <= 0) {
      return const ProductPriceAdvice(
        type: ProductPriceAdviceType.noPrice,
        title: 'Sem preço para analisar',
        message: 'Informe um preço para receber alertas locais.',
      );
    }
    return ProductPriceAdvice.fromAnalysis(
      ProductPriceAnalysis.fromHistory([
        ...history,
        PriceHistoryEntry(
          price: currentPrice,
          recordedAt: recordedAt ?? DateTime.now(),
        ),
      ]),
    );
  }

  final ProductPriceAdviceType type;
  final String title;
  final String message;
  final double percentFromAverage;
}
