import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/product_price_analysis.dart';

void main() {
  test('analyzes latest price increase from previous record', () {
    final analysis = ProductPriceAnalysis.fromHistory([
      PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 10)),
      PriceHistoryEntry(price: 12.5, recordedAt: DateTime(2026, 2, 10)),
    ]);

    expect(analysis.hasEnoughHistory, isTrue);
    expect(analysis.latestPrice, 12.5);
    expect(analysis.previousPrice, 10);
    expect(analysis.absoluteDelta, 2.5);
    expect(analysis.percentDelta.round(), 25);
    expect(analysis.direction, ProductPriceTrendDirection.up);
    expect(analysis.summaryLabel, '25% maior que o registro anterior');
  });

  test('calculates price range and average using valid entries only', () {
    final analysis = ProductPriceAnalysis.fromHistory([
      PriceHistoryEntry(price: 0, recordedAt: DateTime(2026, 1, 1)),
      PriceHistoryEntry(price: 8, recordedAt: DateTime(2026, 1, 10)),
      PriceHistoryEntry(price: 12, recordedAt: DateTime(2026, 2, 10)),
      PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 3, 10)),
    ]);

    expect(analysis.entries.length, 3);
    expect(analysis.lowestPrice, 8);
    expect(analysis.highestPrice, 12);
    expect(analysis.averagePrice, 10);
    expect(analysis.direction, ProductPriceTrendDirection.down);
    expect(analysis.summaryLabel, '17% menor que o registro anterior');
  });

  test('handles products with a single valid price record', () {
    final analysis = ProductPriceAnalysis.fromHistory([
      PriceHistoryEntry(price: 7.5, recordedAt: DateTime(2026, 1, 10)),
    ]);

    expect(analysis.hasEnoughHistory, isFalse);
    expect(analysis.latestPrice, 7.5);
    expect(analysis.previousPrice, isNull);
    expect(analysis.summaryLabel, 'Primeiro preço salvo');
  });

  group('ProductPriceAdvice', () {
    test('marks latest lowest price as best recorded price', () {
      final analysis = ProductPriceAnalysis.fromHistory([
        PriceHistoryEntry(price: 12, recordedAt: DateTime(2026, 1, 10)),
        PriceHistoryEntry(price: 11, recordedAt: DateTime(2026, 2, 10)),
        PriceHistoryEntry(price: 9, recordedAt: DateTime(2026, 3, 10)),
      ]);

      final advice = ProductPriceAdvice.fromAnalysis(analysis);

      expect(advice.type, ProductPriceAdviceType.bestPrice);
      expect(advice.title, 'Melhor preço registrado');
      expect(advice.message, 'Está no menor valor salvo para este produto.');
    });

    test('marks latest price below average as a good price', () {
      final analysis = ProductPriceAnalysis.fromHistory([
        PriceHistoryEntry(price: 8, recordedAt: DateTime(2026, 1, 10)),
        PriceHistoryEntry(price: 22, recordedAt: DateTime(2026, 2, 10)),
        PriceHistoryEntry(price: 22, recordedAt: DateTime(2026, 3, 10)),
        PriceHistoryEntry(price: 14, recordedAt: DateTime(2026, 4, 10)),
      ]);

      final advice = ProductPriceAdvice.fromAnalysis(analysis);

      expect(advice.type, ProductPriceAdviceType.goodPrice);
      expect(advice.title, 'Preço bom');
      expect(advice.message, 'Está 15% abaixo da média do histórico.');
    });

    test('marks latest price above average as high', () {
      final analysis = ProductPriceAnalysis.fromHistory([
        PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 10)),
        PriceHistoryEntry(price: 11, recordedAt: DateTime(2026, 2, 10)),
        PriceHistoryEntry(price: 10.5, recordedAt: DateTime(2026, 3, 10)),
        PriceHistoryEntry(price: 13, recordedAt: DateTime(2026, 4, 10)),
      ]);

      final advice = ProductPriceAdvice.fromAnalysis(analysis);

      expect(advice.type, ProductPriceAdviceType.highPrice);
      expect(advice.title, 'Preço acima da média');
      expect(advice.message, 'Está 17% acima da média do histórico.');
    });

    test('marks latest high as record high when it is far above average', () {
      final analysis = ProductPriceAnalysis.fromHistory([
        PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 10)),
        PriceHistoryEntry(price: 11, recordedAt: DateTime(2026, 2, 10)),
        PriceHistoryEntry(price: 10.5, recordedAt: DateTime(2026, 3, 10)),
        PriceHistoryEntry(price: 16, recordedAt: DateTime(2026, 4, 10)),
      ]);

      final advice = ProductPriceAdvice.fromAnalysis(analysis);

      expect(advice.type, ProductPriceAdviceType.recordHigh);
      expect(advice.title, 'Maior preço registrado');
      expect(
        advice.message,
        'Está 35% acima da média. Vale conferir antes de comprar.',
      );
    });

    test('uses learning copy when history has few records', () {
      final analysis = ProductPriceAnalysis.fromHistory([
        PriceHistoryEntry(price: 8, recordedAt: DateTime(2026, 1, 10)),
        PriceHistoryEntry(price: 8.5, recordedAt: DateTime(2026, 2, 10)),
      ]);

      final advice = ProductPriceAdvice.fromAnalysis(analysis);

      expect(advice.type, ProductPriceAdviceType.learning);
      expect(advice.title, 'Ainda aprendendo o preço');
      expect(advice.message, 'Com mais registros, o alerta fica mais preciso.');
    });

    test('analyzes a current unsaved price against local history', () {
      final advice = ProductPriceAdvice.forCurrentPrice(
        history: [
          PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 10)),
          PriceHistoryEntry(price: 11, recordedAt: DateTime(2026, 2, 10)),
          PriceHistoryEntry(price: 10.5, recordedAt: DateTime(2026, 3, 10)),
        ],
        currentPrice: 13,
        recordedAt: DateTime(2026, 4, 10),
      );

      expect(advice.type, ProductPriceAdviceType.highPrice);
      expect(advice.title, 'Preço acima da média');
      expect(advice.message, 'Está 17% acima da média do histórico.');
    });
  });
}
