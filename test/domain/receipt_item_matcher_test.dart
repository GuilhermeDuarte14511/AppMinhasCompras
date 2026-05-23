import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/receipt_item_matcher.dart';

void main() {
  const matcher = ReceiptItemMatcher();

  test('matches noisy receipt abbreviation to catalog product', () {
    final result = matcher.match(
      const ShoppingItemDraft(
        name: 'ARR TIO J TP1 5KG',
        quantity: 1,
        unitPrice: 24.9,
        category: ShoppingCategory.grocery,
      ),
      currentItems: const <ShoppingItem>[],
      catalogProducts: [
        _catalogProduct(
          name: 'Arroz Tio João Tipo 1 5kg',
          category: ShoppingCategory.grainsAndPasta,
          unitPrice: 28.5,
          barcode: '789100000001',
        ),
      ],
    );

    expect(result.confidence, ReceiptItemMatchConfidence.high);
    expect(result.candidate?.source, ReceiptItemMatchSource.catalog);
    expect(result.resolvedDraft.name, 'Arroz Tio João Tipo 1 5kg');
    expect(result.resolvedDraft.category, ShoppingCategory.grainsAndPasta);
    expect(result.resolvedDraft.barcode, '789100000001');
    expect(result.resolvedDraft.unitPrice, 24.9);
  });

  test('prefers a current list match over a similar catalog product', () {
    final result = matcher.match(
      const ShoppingItemDraft(
        name: 'LEITE INT PIRACANJUBA',
        quantity: 2,
        unitPrice: 5.49,
        category: ShoppingCategory.grocery,
      ),
      currentItems: [
        _item(
          name: 'Leite Integral Piracanjuba',
          category: ShoppingCategory.dairy,
          unitPrice: 5.99,
          barcode: '789200000001',
        ),
      ],
      catalogProducts: [
        _catalogProduct(
          name: 'Leite Integral Italac',
          category: ShoppingCategory.dairy,
          unitPrice: 5.89,
          barcode: '789200000002',
        ),
      ],
    );

    expect(result.confidence, ReceiptItemMatchConfidence.high);
    expect(result.candidate?.source, ReceiptItemMatchSource.currentList);
    expect(result.resolvedDraft.name, 'Leite Integral Piracanjuba');
    expect(result.resolvedDraft.barcode, '789200000001');
    expect(result.resolvedDraft.unitPrice, 5.49);
  });

  test('keeps original receipt draft when only weak candidates exist', () {
    final result = matcher.match(
      const ShoppingItemDraft(
        name: 'PILHA AA',
        quantity: 1,
        unitPrice: 12,
        category: ShoppingCategory.grocery,
      ),
      currentItems: const <ShoppingItem>[],
      catalogProducts: [
        _catalogProduct(
          name: 'Banana Prata',
          category: ShoppingCategory.produce,
          unitPrice: 7,
        ),
      ],
    );

    expect(result.confidence, ReceiptItemMatchConfidence.none);
    expect(result.candidate, isNull);
    expect(result.resolvedDraft.name, 'PILHA AA');
    expect(result.resolvedDraft.category, ShoppingCategory.grocery);
  });

  test('uses barcode as an exact catalog match when available', () {
    final result = matcher.match(
      const ShoppingItemDraft(
        name: 'OCR ilegivel',
        quantity: 1,
        unitPrice: 8.75,
        category: ShoppingCategory.grocery,
        barcode: '789300000001',
      ),
      currentItems: const <ShoppingItem>[],
      catalogProducts: [
        _catalogProduct(
          name: 'Café Torrado 500g',
          category: ShoppingCategory.beverages,
          unitPrice: 18,
          barcode: '789300000001',
        ),
      ],
    );

    expect(result.confidence, ReceiptItemMatchConfidence.exact);
    expect(result.candidate?.source, ReceiptItemMatchSource.catalog);
    expect(result.resolvedDraft.name, 'Café Torrado 500g');
    expect(result.resolvedDraft.unitPrice, 8.75);
  });

  test('matches WMS receipt abbreviations to catalog names', () {
    final results = matcher.matchAll(
      const [
        ShoppingItemDraft(
          name: 'BEB LACTEA TODDYNHO',
          quantity: 5,
          unitPrice: 2.99,
          category: ShoppingCategory.dairy,
        ),
        ShoppingItemDraft(
          name: 'MARG QUALY C S',
          quantity: 1,
          unitPrice: 9.45,
          category: ShoppingCategory.dairy,
        ),
        ShoppingItemDraft(
          name: 'REFR PEPSI COLA',
          quantity: 12,
          unitPrice: 1.79,
          category: ShoppingCategory.beverages,
        ),
      ],
      currentItems: const <ShoppingItem>[],
      catalogProducts: [
        _catalogProduct(
          name: 'Bebida Láctea Toddynho',
          category: ShoppingCategory.dairy,
          unitPrice: 2.99,
        ),
        _catalogProduct(
          name: 'Margarina Qualy com Sal',
          category: ShoppingCategory.dairy,
          unitPrice: 9.45,
        ),
        _catalogProduct(
          name: 'Refrigerante Pepsi Cola',
          category: ShoppingCategory.beverages,
          unitPrice: 1.79,
        ),
      ],
    );

    expect(
      results.map((result) => result.confidence),
      everyElement(ReceiptItemMatchConfidence.high),
    );
    expect(results.map((result) => result.resolvedDraft.name), [
      'Bebida Láctea Toddynho',
      'Margarina Qualy com Sal',
      'Refrigerante Pepsi Cola',
    ]);
  });

  test(
    'matches WMS personal care and cleaning abbreviations to catalog names',
    () {
      final results = matcher.matchAll(
        const [
          ShoppingItemDraft(
            name: 'CR D COLGATE T 12',
            quantity: 1,
            unitPrice: 9.8,
            category: ShoppingCategory.personalCare,
          ),
          ShoppingItemDraft(
            name: 'DET LIQ MINUANO',
            quantity: 3,
            unitPrice: 2.35,
            category: ShoppingCategory.cleaning,
          ),
          ShoppingItemDraft(
            name: 'LIMP PERF CONC COALA',
            quantity: 2,
            unitPrice: 14.5,
            category: ShoppingCategory.cleaning,
          ),
          ShoppingItemDraft(
            name: 'SHAMP CLEAR',
            quantity: 1,
            unitPrice: 29.98,
            category: ShoppingCategory.personalCare,
          ),
          ShoppingItemDraft(
            name: 'KIT DOVE SHAMPCOND',
            quantity: 1,
            unitPrice: 29.9,
            category: ShoppingCategory.personalCare,
          ),
        ],
        currentItems: const <ShoppingItem>[],
        catalogProducts: [
          _catalogProduct(
            name: 'Creme Dental Colgate Total 12',
            category: ShoppingCategory.personalCare,
            unitPrice: 9.8,
          ),
          _catalogProduct(
            name: 'Detergente Liquido Minuano',
            category: ShoppingCategory.cleaning,
            unitPrice: 2.35,
          ),
          _catalogProduct(
            name: 'Limpador Perfumado Concentrado Coala',
            category: ShoppingCategory.cleaning,
            unitPrice: 14.5,
          ),
          _catalogProduct(
            name: 'Shampoo Clear',
            category: ShoppingCategory.personalCare,
            unitPrice: 29.98,
          ),
          _catalogProduct(
            name: 'Kit Dove Shampoo Condicionador',
            category: ShoppingCategory.personalCare,
            unitPrice: 29.9,
          ),
        ],
      );

      expect(
        results.map((result) => result.confidence),
        everyElement(ReceiptItemMatchConfidence.high),
      );
      expect(results.map((result) => result.resolvedDraft.name), [
        'Creme Dental Colgate Total 12',
        'Detergente Liquido Minuano',
        'Limpador Perfumado Concentrado Coala',
        'Shampoo Clear',
        'Kit Dove Shampoo Condicionador',
      ]);
    },
  );

  test('matches aliases found in public NFC-e supermarket descriptions', () {
    final results = matcher.matchAll(
      const [
        ShoppingItemDraft(
          name: 'ACHOC PO TODDY',
          quantity: 1,
          unitPrice: 5.25,
          category: ShoppingCategory.sweets,
        ),
        ShoppingItemDraft(
          name: 'PAPEL HIG COTTON',
          quantity: 1,
          unitPrice: 33.9,
          category: ShoppingCategory.personalCare,
        ),
        ShoppingItemDraft(
          name: 'SHHEAD SHOULD ANT COCEIRA',
          quantity: 1,
          unitPrice: 26.9,
          category: ShoppingCategory.personalCare,
        ),
        ShoppingItemDraft(
          name: 'LOGURTE NESTLE NATUR',
          quantity: 1,
          unitPrice: 4.29,
          category: ShoppingCategory.dairy,
        ),
      ],
      currentItems: const <ShoppingItem>[],
      catalogProducts: [
        _catalogProduct(
          name: 'Achocolatado em Pó Toddy',
          category: ShoppingCategory.sweets,
          unitPrice: 5.25,
        ),
        _catalogProduct(
          name: 'Papel Higienico Cotton',
          category: ShoppingCategory.personalCare,
          unitPrice: 33.9,
        ),
        _catalogProduct(
          name: 'Shampoo Head Shoulders Anticoceira',
          category: ShoppingCategory.personalCare,
          unitPrice: 26.9,
        ),
        _catalogProduct(
          name: 'Iogurte Nestle Natural',
          category: ShoppingCategory.dairy,
          unitPrice: 4.29,
        ),
      ],
    );

    expect(
      results.map((result) => result.confidence),
      everyElement(ReceiptItemMatchConfidence.high),
    );
    expect(results.map((result) => result.resolvedDraft.name), [
      'Achocolatado em Pó Toddy',
      'Papel Higienico Cotton',
      'Shampoo Head Shoulders Anticoceira',
      'Iogurte Nestle Natural',
    ]);
  });
}

CatalogProduct _catalogProduct({
  required String name,
  required ShoppingCategory category,
  double? unitPrice,
  String? barcode,
}) {
  return CatalogProduct(
    id: name,
    name: name,
    category: category,
    unitPrice: unitPrice,
    barcode: barcode,
    updatedAt: DateTime(2026, 5, 16),
  );
}

ShoppingItem _item({
  required String name,
  required ShoppingCategory category,
  required double unitPrice,
  String? barcode,
}) {
  return ShoppingItem(
    id: name,
    name: name,
    quantity: 1,
    unitPrice: unitPrice,
    category: category,
    barcode: barcode,
  );
}
