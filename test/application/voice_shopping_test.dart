import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/voice_shopping.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  group('VoiceShoppingParser', () {
    test('recognizes spoken quantity after a product name', () {
      const parser = VoiceShoppingParser();
      for (final transcript in [
        'Arroz Camil 2 Unidades',
        'ARROZ CAMIL DUAS UNIDADES',
        'arroz camil dois unidades',
        'duas unidades de arroz camil',
      ]) {
        final intent = parser.parse(transcript).single;
        expect(intent.name, 'Arroz camil', reason: transcript);
        expect(intent.quantity, 2, reason: transcript);
      }
    });

    test('keeps sizes and product number names while parsing spoken units', () {
      const parser = VoiceShoppingParser();
      final intents = parser.parse(
        'Sabonete três unidades, café vinte e duas unidades, '
        'água trinta unidades, arroz cinco quilos, arroz tipo dois',
      );
      expect(intents.map((item) => item.quantity), [3, 22, 30, 1, 1]);
      expect(intents.map((item) => item.name), [
        'Sabonete',
        'Café',
        'Água',
        'Arroz cinco quilos',
        'Arroz tipo dois',
      ]);
    });

    test('parses multiple Portuguese items, quantities, and spoken price', () {
      const parser = VoiceShoppingParser();

      final intents = parser.parse(
        'Adicione dois detergentes Minuano por 5,49 cada, '
        'um arroz de cinco quilos e três sabonetes',
      );

      expect(intents, hasLength(3));
      expect(intents[0].name, 'Detergentes minuano');
      expect(intents[0].quantity, 2);
      expect(intents[0].unitPrice, 5.49);
      expect(intents[1].name, 'Arroz de cinco quilos');
      expect(intents[1].quantity, 1);
      expect(intents[2].name, 'Sabonetes');
      expect(intents[2].quantity, 3);
    });

    test('keeps composite number words together', () {
      const parser = VoiceShoppingParser();

      final intents = parser.parse(
        'Adicione vinte e dois sabonetes e um detergente',
      );

      expect(intents, hasLength(2));
      expect(intents.first.quantity, 22);
      expect(intents.first.name, 'Sabonetes');
    });

    test(
      'accepts quantities after item names without changing product sizes',
      () {
        const parser = VoiceShoppingParser();

        final intents = parser.parse(
          'Arroz 2, leite 1, arroz tipo 1, água 1 litro',
        );

        expect(intents.map((item) => item.name), [
          'Arroz',
          'Leite',
          'Arroz tipo 1',
          'Água 1 litro',
        ]);
        expect(intents.map((item) => item.quantity), [2, 1, 1, 1]);
      },
    );
  });

  group('VoiceCatalogMatcher', () {
    const matcher = VoiceCatalogMatcher();

    test('does not auto-select condensed milk for generic milk', () {
      final product = _product(
        id: 'condensed-milk',
        name: 'Leite condensado 395g',
        price: 5.89,
      );
      const intent = VoiceItemIntent(
        rawText: 'leite',
        name: 'Leite',
        quantity: 1,
      );

      final resolved = matcher.resolve(intent, catalogProducts: [product]);

      expect(resolved.matchedProduct, isNull);
      expect(resolved.draft.name, 'Leite');
      expect(resolved.alternatives.single.product, product);
    });

    test('applies a unique safe match and recovers catalog data', () {
      final product = _product(
        id: 'minuano',
        name: 'Detergente Minuano 500 ml',
        price: 4.99,
        barcode: '7891234567895',
      );
      const intent = VoiceItemIntent(
        rawText: 'dois detergentes minuano',
        name: 'Detergentes Minuano',
        quantity: 2,
      );

      final resolved = matcher.resolve(intent, catalogProducts: [product]);

      expect(resolved.confidence, VoiceCatalogMatchConfidence.high);
      expect(resolved.draft.name, product.name);
      expect(resolved.draft.quantity, 2);
      expect(resolved.draft.unitPrice, 4.99);
      expect(resolved.draft.barcode, '7891234567895');
    });

    test('spoken price overrides the last catalog price', () {
      final product = _product(
        id: 'coffee',
        name: 'Café Pilão 500 g',
        price: 20,
      );
      const intent = VoiceItemIntent(
        rawText: 'café pilão por 22 reais',
        name: 'Café Pilão 500 g',
        quantity: 1,
        unitPrice: 22,
      );

      final resolved = matcher.resolve(intent, catalogProducts: [product]);

      expect(resolved.confidence, VoiceCatalogMatchConfidence.exact);
      expect(resolved.draft.unitPrice, 22);
    });

    test(
      'does not copy barcode when multiple catalog variants are ambiguous',
      () {
        final neutral = _product(
          id: 'neutral',
          name: 'Detergente Minuano Neutro 500 ml',
          price: 5,
          barcode: '7891234567895',
        );
        final lemon = _product(
          id: 'lemon',
          name: 'Detergente Minuano Limão 500 ml',
          price: 5.20,
          barcode: '7891234567888',
        );
        const intent = VoiceItemIntent(
          rawText: 'detergente minuano',
          name: 'Detergente Minuano',
          quantity: 1,
        );

        final resolved = matcher.resolve(
          intent,
          catalogProducts: [neutral, lemon],
        );

        expect(resolved.confidence, VoiceCatalogMatchConfidence.ambiguous);
        expect(resolved.draft.barcode, isNull);
        expect(resolved.draft.unitPrice, 0);
        expect(resolved.alternatives, hasLength(2));
      },
    );

    test('selecting an alternative applies its trusted catalog fields', () {
      final product = _product(
        id: 'neutral',
        name: 'Detergente Minuano Neutro 500 ml',
        price: 5,
        barcode: '7891234567895',
      );
      const intent = VoiceItemIntent(
        rawText: 'detergente minuano',
        name: 'Detergente Minuano',
        quantity: 1,
      );
      final unresolved = matcher.resolve(
        intent,
        catalogProducts: [
          product,
          _product(
            id: 'lemon',
            name: 'Detergente Minuano Limão 500 ml',
            price: 5.20,
          ),
        ],
      );

      final selected = unresolved.selectProduct(product);

      expect(selected.draft.name, product.name);
      expect(selected.draft.unitPrice, 5);
      expect(selected.draft.barcode, '7891234567895');
      expect(selected.confidence, VoiceCatalogMatchConfidence.exact);
    });
  });

  group('voice product suggestions', () {
    const matcher = VoiceCatalogMatcher();
    const parser = VoiceShoppingParser();

    test(
      'rice ignores capitalization and requires choice between variants',
      () {
        final products = [
          _product(id: 'rice1', name: 'ARROZ BRANCO CAMIL 5KG', price: 20),
          _product(id: 'rice2', name: 'Arroz integral Camil 1kg', price: 10),
        ];
        final resolved = matcher.resolve(
          parser.parse('ARROZ duas unidades').single,
          catalogProducts: products,
        );
        expect(resolved.confidence, VoiceCatalogMatchConfidence.ambiguous);
        expect(
          resolved.alternatives.map((candidate) => candidate.product.id),
          containsAll(['rice1', 'rice2']),
        );
        expect(resolved.selectProduct(products.last).draft.quantity, 2);
      },
    );

    test(
      'macarrão PENNE suggests penne even without the generic pasta word',
      () {
        final penne = _product(
          id: 'penne',
          name: 'PENNE BARILLA GRANO DURO 500G',
          price: 12,
        );
        final resolved = matcher.resolve(
          parser.parse('macarrão PENNE duas unidades').single,
          catalogProducts: [
            penne,
            _product(
              id: 'spaghetti',
              name: 'Macarrão espaguete 500g',
              price: 5,
            ),
          ],
        );
        expect(resolved.confidence, VoiceCatalogMatchConfidence.ambiguous);
        expect(resolved.matchedProduct, isNull);
        expect(resolved.alternatives.first.product.id, 'penne');
        expect(
          resolved.alternatives.map((candidate) => candidate.product.id),
          isNot(contains('spaghetti')),
        );
        final selected = resolved.selectProduct(penne);
        expect(selected.draft.name, penne.name);
        expect(selected.draft.quantity, 2);
        expect(selected.draft.unitPrice, 12);
      },
    );

    test('PENNE alone matches its catalog entry and never invents one', () {
      final penne = _product(
        id: 'penne',
        name: 'Macarrão Penne Barilla 500g',
        price: 12,
      );
      final intent = parser.parse('PENNE').single;
      expect(
        matcher.resolve(intent, catalogProducts: [penne]).matchedProduct,
        penne,
      );
      expect(
        matcher.resolve(intent, catalogProducts: []).alternatives,
        isEmpty,
      );
    });
  });

  group('VoiceDraftListMerger', () {
    const merger = VoiceDraftListMerger();

    test('adds a new product and merges an existing catalog product', () {
      final recordedAt = DateTime(2026, 7, 20, 15);
      final result = merger.merge(
        [
          ShoppingItem(
            id: 'detergent',
            name: 'Detergente Minuano 500 ml',
            quantity: 1,
            unitPrice: 4.99,
            barcode: '7891234567895',
            category: ShoppingCategory.cleaning,
            priceHistory: [
              PriceHistoryEntry(price: 4.99, recordedAt: DateTime(2026, 7, 10)),
            ],
          ),
        ],
        const [
          ShoppingItemDraft(
            name: 'Detergente Minuano',
            quantity: 2,
            unitPrice: 5.49,
            barcode: '7891234567895',
            category: ShoppingCategory.cleaning,
          ),
          ShoppingItemDraft(
            name: 'Sabonete',
            quantity: 3,
            unitPrice: 2.50,
            category: ShoppingCategory.personalCare,
          ),
        ],
        recordedAt: recordedAt,
      );

      expect(result.createdCount, 1);
      expect(result.mergedCount, 1);
      expect(result.items, hasLength(2));
      expect(result.items.first.quantity, 3);
      expect(result.items.first.unitPrice, 5.49);
      expect(result.items.first.priceHistory, hasLength(2));
      expect(result.items.first.priceHistory.last.recordedAt, recordedAt);
      expect(result.items.last.name, 'Sabonete');
      expect(result.items.last.quantity, 3);
    });

    test('does not add a price observation when the value did not change', () {
      final result = merger.merge(
        [
          ShoppingItem(
            id: 'coffee',
            name: 'Café',
            quantity: 1,
            unitPrice: 20,
            category: ShoppingCategory.grocery,
            priceHistory: [
              PriceHistoryEntry(price: 20, recordedAt: DateTime(2026, 7)),
            ],
          ),
        ],
        const [
          ShoppingItemDraft(
            name: 'Café',
            quantity: 1,
            unitPrice: 20,
            category: ShoppingCategory.grocery,
          ),
        ],
        recordedAt: DateTime(2026, 7, 20),
      );

      expect(result.items.single.quantity, 2);
      expect(result.items.single.priceHistory, hasLength(1));
    });
  });
}

CatalogProduct _product({
  required String id,
  required String name,
  required double price,
  String? barcode,
}) {
  return CatalogProduct(
    id: id,
    name: name,
    category: ShoppingCategory.cleaning,
    unitPrice: price,
    barcode: barcode,
    usageCount: 3,
    updatedAt: DateTime(2026, 7, 20),
  );
}
