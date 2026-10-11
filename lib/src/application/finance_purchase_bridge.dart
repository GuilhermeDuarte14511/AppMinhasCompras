import '../domain/models_and_utils.dart';
import 'finance_integration.dart';

FinancePurchaseRequest buildFinancePurchaseRequest({
  required CompletedPurchase purchase,
  required String cardId,
  FinancePaymentSourceKind paymentSourceKind = FinancePaymentSourceKind.credit,
  String? categoryId,
}) {
  final rawDescription = 'Compras — ${purchase.listName.trim()}';
  final description = rawDescription.length <= 120
      ? rawDescription
      : rawDescription.substring(0, 120);
  return FinancePurchaseRequest(
    externalPurchaseId: _purchaseKey(purchase),
    cardId: cardId,
    paymentSourceKind: paymentSourceKind,
    categoryId: categoryId,
    description: description,
    amountCents: (purchase.spentValue * 100).round(),
    purchasedOn: purchase.closedAt,
    notes:
        '${purchase.productsCount} produtos • '
        '${purchase.totalItems} unidades • enviado pelo Minhas Compras',
  );
}

String _purchaseKey(CompletedPurchase purchase) =>
    'shopping-list:${purchase.listId}';

List<FinancePurchaseSync> buildFinancePurchasePlan({
  required CompletedPurchase purchase,
  required List<FinancePaymentAllocation> allocations,
  String? categoryId,
}) {
  final total = (purchase.spentValue * 100).round();
  if (allocations.isEmpty ||
      allocations.length > 5 ||
      allocations.any(
        (part) => part.amountCents <= 0 || part.sourceId.isEmpty,
      ) ||
      allocations
              .map((part) => '${part.sourceKind}:${part.sourceId}')
              .toSet()
              .length !=
          allocations.length ||
      allocations.fold<int>(0, (sum, part) => sum + part.amountCents) !=
          total) {
    throw ArgumentError(
      'Distribua o total exato entre 1 e 5 meios de pagamento distintos.',
    );
  }
  return List.generate(allocations.length, (index) {
    final part = allocations[index];
    final base = buildFinancePurchaseRequest(
      purchase: purchase,
      cardId: part.sourceId,
      paymentSourceKind: FinancePaymentSourceKind.fromWireValue(
        part.sourceKind,
      ),
      categoryId: categoryId,
    );
    final split = allocations.length > 1;
    final suffix = split
        ? ' · pagamento ${index + 1}/${allocations.length}'
        : '';
    final description = base.description.length + suffix.length > 120
        ? base.description.substring(0, 120 - suffix.length)
        : base.description;
    return FinancePurchaseSync(
      purchaseId: purchase.id,
      connectionId: purchase.financeIntent?.connectionId ?? '',
      sourceName: part.sourceName,
      request: FinancePurchaseRequest(
        externalPurchaseId: split
            ? '${_purchaseKey(purchase)}_part_${index + 1}'
            : _purchaseKey(purchase),
        cardId: part.sourceId,
        paymentSourceKind: base.paymentSourceKind,
        categoryId: categoryId,
        description: '$description$suffix',
        amountCents: part.amountCents,
        purchasedOn: purchase.closedAt,
        notes: base.notes,
      ),
    );
  }, growable: false);
}
