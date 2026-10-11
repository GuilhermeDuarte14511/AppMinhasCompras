import '../domain/models_and_utils.dart';

class PurchaseCheckoutReview {
  const PurchaseCheckoutReview._({
    required this.calculatedTotalCents,
    required this.includedItemsCount,
    required this.pendingItems,
    required this.missingPriceItems,
    required this.receiptTotalCents,
  });

  factory PurchaseCheckoutReview.calculate({
    required List<ShoppingItem> items,
    bool includePending = false,
    int? receiptTotalCents,
  }) {
    final included = items
        .where((item) => item.isPurchased || includePending)
        .toList(growable: false);
    final totalCents = included.fold<int>(
      0,
      (sum, item) => sum + (item.subtotal * 100).round(),
    );
    return PurchaseCheckoutReview._(
      calculatedTotalCents: totalCents,
      includedItemsCount: included.length,
      pendingItems: includePending
          ? const []
          : items.where((item) => !item.isPurchased).toList(growable: false),
      missingPriceItems: included
          .where((item) => item.unitPrice <= 0)
          .toList(growable: false),
      receiptTotalCents: receiptTotalCents,
    );
  }

  final int calculatedTotalCents;
  final int includedItemsCount;
  final List<ShoppingItem> pendingItems;
  final List<ShoppingItem> missingPriceItems;
  final int? receiptTotalCents;

  int? get differenceCents => receiptTotalCents == null
      ? null
      : receiptTotalCents! - calculatedTotalCents;

  int get finalTotalCents => receiptTotalCents ?? calculatedTotalCents;
  bool get totalsMatch => differenceCents == null || differenceCents == 0;
  bool get canFinalize =>
      includedItemsCount > 0 &&
      finalTotalCents > 0 &&
      (missingPriceItems.isEmpty || receiptTotalCents != null);
}
