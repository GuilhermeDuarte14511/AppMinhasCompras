import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_purchase_bridge.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  test('preserves discounted final total through history and finance', () {
    final purchase = CompletedPurchase(
      id: 'discount-id',
      listId: 'discount-list',
      listName: 'Desconto inesperado',
      closedAt: DateTime(2026, 9, 25),
      finalTotalCents: 950,
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Arroz',
          quantity: 1,
          unitPrice: 12,
          isPurchased: true,
        ),
      ],
    );
    final restored = CompletedPurchase.fromJson(purchase.toJson());
    expect(restored.finalTotalCents, 950);
    expect(restored.spentValue, 9.50);
    expect(restored.items.single.unitPrice, 12);
    expect(restored.copyWith(listName: 'Outro nome').finalTotalCents, 950);
    expect(
      buildFinancePurchaseRequest(purchase: restored, cardId: 'va').amountCents,
      950,
    );
  });
  test('builds an idempotent finance request from completed history', () {
    final purchase = CompletedPurchase(
      id: 'history_123',
      listId: 'list-id',
      listName: 'Compra da semana',
      closedAt: DateTime(2026, 9, 1, 18, 30),
      items: const [
        ShoppingItem(
          id: 'item-1',
          name: 'Arroz',
          quantity: 2,
          unitPrice: 12.995,
          isPurchased: true,
        ),
      ],
    );

    final request = buildFinancePurchaseRequest(
      purchase: purchase,
      cardId: 'card-id',
      categoryId: 'category-id',
    );

    expect(request.externalPurchaseId, 'shopping-list:list-id');
    expect(request.amountCents, 2599);
    expect(request.description, 'Compras — Compra da semana');
    expect(request.purchasedOn, purchase.closedAt);
  });

  test('keeps the external key stable when the local history id changes', () {
    final first = CompletedPurchase(
      id: 'history-a',
      listId: 'same-list',
      listName: 'Mercado',
      closedAt: DateTime(2026, 9, 1),
      items: const [
        ShoppingItem(
          id: 'item',
          name: 'Arroz',
          quantity: 1,
          unitPrice: 10,
          isPurchased: true,
        ),
      ],
    );
    final retried = CompletedPurchase(
      id: 'history-b',
      listId: 'same-list',
      listName: 'Mercado',
      closedAt: DateTime(2026, 9, 1),
      items: first.items,
    );
    expect(
      buildFinancePurchaseRequest(
        purchase: first,
        cardId: 'va',
      ).externalPurchaseId,
      buildFinancePurchaseRequest(
        purchase: retried,
        cardId: 'va',
      ).externalPurchaseId,
    );
  });
}
