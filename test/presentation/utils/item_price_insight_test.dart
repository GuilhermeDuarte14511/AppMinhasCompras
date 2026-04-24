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
    expect(insight.label, contains('menor'));
    expect(insight.label, contains('ultimo preco salvo'));
  });

  test('buildPriceInsight returns increase copy', () {
    final insight = buildPriceInsight(
      currentPrice: 12,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.up);
    expect(insight.label, contains('maior'));
  });

  test('buildPriceInsight returns neutral copy', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.same);
    expect(insight.label, 'Mesmo preco da ultima compra');
  });

  test('buildPriceInsight returns null with invalid reference', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 0,
    );

    expect(insight, isNull);
  });
}
