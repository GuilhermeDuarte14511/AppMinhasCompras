import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/fiscal_receipt_import.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  group('FiscalReceiptImportPlanner', () {
    test(
      'applies edited data to the linked planned item and closes the purchase',
      () {
        final recordedAt = DateTime(2026, 7, 20, 14, 30);
        final source = _list([
          _item(id: 'planned-rice', name: 'Arroz', unitPrice: 10),
          _item(id: 'planned-milk', name: 'Leite', unitPrice: 6),
        ]);

        final plan = const FiscalReceiptImportPlanner().createPlan(
          source: source,
          submission: const FiscalReceiptReviewSubmission(
            items: [
              FiscalReceiptReviewedItem(
                plannedItemId: 'planned-rice',
                draft: ShoppingItemDraft(
                  name: 'Arroz integral',
                  quantity: 2,
                  unitPrice: 12.50,
                  category: ShoppingCategory.grainsAndPasta,
                  barcode: '789100000001',
                  isPurchased: true,
                ),
              ),
            ],
            finalizePurchase: true,
            declaredTotal: 25,
          ),
          recordedAt: recordedAt,
          createId: _unexpectedId,
        );

        expect(plan.addedCount, 0);
        expect(plan.updatedCount, 1);
        expect(plan.updatedList.isClosed, isTrue);
        expect(plan.updatedList.closedAt, recordedAt);
        expect(plan.updatedList.items, hasLength(2));

        final imported = plan.updatedList.items.first;
        expect(imported.id, 'planned-rice');
        expect(imported.name, 'Arroz integral');
        expect(imported.quantity, 2);
        expect(imported.unitPrice, 12.50);
        expect(imported.isPurchased, isTrue);
        expect(imported.priceHistory.map((entry) => entry.price), [10, 12.50]);

        final untouched = plan.updatedList.items.last;
        expect(untouched.id, 'planned-milk');
        expect(untouched.isPurchased, isFalse);
        expect(plan.appliedDrafts.single.isPurchased, isTrue);
      },
    );

    test('adds only reviewed items and keeps the list open when requested', () {
      final source = _list([
        _item(id: 'planned-milk', name: 'Leite', unitPrice: 6),
      ]);

      final plan = const FiscalReceiptImportPlanner().createPlan(
        source: source,
        submission: const FiscalReceiptReviewSubmission(
          items: [
            FiscalReceiptReviewedItem(
              draft: ShoppingItemDraft(
                name: 'Café',
                quantity: 1,
                unitPrice: 18.90,
                category: ShoppingCategory.grocery,
                isPurchased: true,
              ),
            ),
          ],
          finalizePurchase: false,
        ),
        recordedAt: DateTime(2026, 7, 20),
        createId: _newItemId,
      );

      expect(plan.updatedList.isClosed, isFalse);
      expect(plan.updatedList.items, hasLength(2));
      expect(plan.updatedList.items.last.id, 'receipt-item');
      expect(plan.updatedList.items.last.name, 'Café');
      expect(plan.updatedList.items.last.isPurchased, isTrue);
      expect(plan.updatedList.items.first.id, 'planned-milk');
      expect(plan.updatedList.items.first.isPurchased, isFalse);
    });

    test('rejects linking two receipt lines to the same planned item', () {
      final source = _list([
        _item(id: 'planned-rice', name: 'Arroz', unitPrice: 10),
      ]);
      const submission = FiscalReceiptReviewSubmission(
        items: [
          FiscalReceiptReviewedItem(
            plannedItemId: 'planned-rice',
            draft: ShoppingItemDraft(
              name: 'Arroz A',
              quantity: 1,
              unitPrice: 10,
              category: ShoppingCategory.grainsAndPasta,
            ),
          ),
          FiscalReceiptReviewedItem(
            plannedItemId: 'planned-rice',
            draft: ShoppingItemDraft(
              name: 'Arroz B',
              quantity: 1,
              unitPrice: 11,
              category: ShoppingCategory.grainsAndPasta,
            ),
          ),
        ],
        finalizePurchase: false,
      );

      expect(
        () => const FiscalReceiptImportPlanner().createPlan(
          source: source,
          submission: submission,
          recordedAt: DateTime(2026, 7, 20),
          createId: _newItemId,
        ),
        throwsStateError,
      );
    });
  });
}

ShoppingListModel _list(List<ShoppingItem> items) {
  return ShoppingListModel(
    id: 'list-1',
    name: 'Mercado',
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 19),
    items: items,
  );
}

ShoppingItem _item({
  required String id,
  required String name,
  required double unitPrice,
}) {
  return ShoppingItem(
    id: id,
    name: name,
    quantity: 1,
    unitPrice: unitPrice,
    isPurchased: false,
    category: ShoppingCategory.grocery,
    priceHistory: [
      PriceHistoryEntry(price: unitPrice, recordedAt: DateTime(2026, 7, 1)),
    ],
  );
}

String _newItemId() => 'receipt-item';

String _unexpectedId() => throw StateError('No item should be created.');
