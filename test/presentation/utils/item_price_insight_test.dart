import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/utils/item_price_insight.dart';

void main() {
  test('buildPriceInsight returns decrease copy', () {
    final insight = buildPriceInsight(
      currentPrice: 8.5,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.down);
    expect(insight.percentDelta, closeTo(-15, 0.0001));
    expect(insight.label, '15% menor que o ultimo preco salvo');
  });

  test('buildPriceInsight returns increase copy', () {
    final insight = buildPriceInsight(
      currentPrice: 12,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.up);
    expect(insight.percentDelta, closeTo(20, 0.0001));
    expect(insight.label, '20% maior que o ultimo preco salvo');
  });

  test('buildPriceInsight returns neutral copy', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.same);
    expect(insight.percentDelta, 0);
    expect(insight.label, 'Mesmo preco da ultima compra');
  });

  test('buildPriceInsight returns neutral copy for rounded zero delta', () {
    final insight = buildPriceInsight(
      currentPrice: 10.04,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.same);
    expect(insight.percentDelta, closeTo(0.4, 0.0001));
    expect(insight.label, 'Mesmo preco da ultima compra');
  });

  test('buildPriceInsight returns neutral copy for rounded zero negative delta', () {
    final insight = buildPriceInsight(
      currentPrice: 9.96,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.same);
    expect(insight.percentDelta, closeTo(-0.4, 0.0001));
    expect(insight.label, 'Mesmo preco da ultima compra');
  });

  test('buildPriceInsight returns null with invalid reference', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 0,
    );

    expect(insight, isNull);
  });

  test('buildPriceInsight returns null with invalid current price', () {
    final insight = buildPriceInsight(
      currentPrice: 0,
      referencePrice: 10,
    );

    expect(insight, isNull);
  });
}
