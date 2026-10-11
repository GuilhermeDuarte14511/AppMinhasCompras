import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/purchase_checkout_review.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  const priced = ShoppingItem(
    id: 'priced',
    name: 'Arroz',
    quantity: 2,
    unitPrice: 12.50,
    isPurchased: true,
  );
  const missingPrice = ShoppingItem(
    id: 'missing',
    name: 'Leite',
    quantity: 1,
    unitPrice: 0,
    isPurchased: true,
  );
  const pending = ShoppingItem(
    id: 'pending',
    name: 'Café',
    quantity: 1,
    unitPrice: 20,
  );

  test('blocks closing when included items have no price', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [priced, missingPrice, pending],
    );

    expect(review.calculatedTotalCents, 2500);
    expect(review.includedItemsCount, 2);
    expect(review.missingPriceItems.map((item) => item.name), ['Leite']);
    expect(review.canFinalize, isFalse);
  });

  test('reconciles receipt total in exact cents', () {
    final matching = PurchaseCheckoutReview.calculate(
      items: const [priced, pending],
      receiptTotalCents: 2500,
    );
    final different = PurchaseCheckoutReview.calculate(
      items: const [priced, pending],
      receiptTotalCents: 2499,
    );

    expect(matching.differenceCents, 0);
    expect(matching.canFinalize, isTrue);
    expect(different.differenceCents, -1);
    expect(different.canFinalize, isTrue);
  });

  test('includes pending items only when requested', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [priced, pending],
      includePending: true,
    );

    expect(review.calculatedTotalCents, 4500);
    expect(review.includedItemsCount, 2);
    expect(review.pendingItems, isEmpty);
    expect(review.canFinalize, isTrue);
  });

  test('uses a discounted final amount without changing item prices', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [priced, pending],
      receiptTotalCents: 1999,
    );
    expect(review.calculatedTotalCents, 2500);
    expect(review.finalTotalCents, 1999);
    expect(review.differenceCents, -501);
    expect(review.canFinalize, isTrue);
    expect(priced.unitPrice, 12.50);
  });
  test('rejects zero final amount', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [priced],
      receiptTotalCents: 0,
    );
    expect(review.canFinalize, isFalse);
  });

  test('allows a final total even when an item lacks an individual price', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [priced, missingPrice],
      receiptTotalCents: 2000,
    );
    expect(review.canFinalize, isTrue);
    expect(review.finalTotalCents, 2000);
    expect(review.missingPriceItems.single.unitPrice, 0);
  });

  test('does not close a purchase with only pending items', () {
    final review = PurchaseCheckoutReview.calculate(
      items: const [pending],
      receiptTotalCents: 2000,
    );
    expect(review.canFinalize, isFalse);
  });
}
