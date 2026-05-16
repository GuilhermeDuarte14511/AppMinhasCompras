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
