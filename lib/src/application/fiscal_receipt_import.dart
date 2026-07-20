import 'dart:math';

import '../domain/models_and_utils.dart';
import '../domain/pantry.dart';

class FiscalReceiptReviewedItem {
  const FiscalReceiptReviewedItem({required this.draft, this.plannedItemId});

  final ShoppingItemDraft draft;
  final String? plannedItemId;
}

class FiscalReceiptReviewSubmission {
  const FiscalReceiptReviewSubmission({
    required this.items,
    required this.finalizePurchase,
    this.declaredTotal,
  });

  final List<FiscalReceiptReviewedItem> items;
  final bool finalizePurchase;
  final double? declaredTotal;

  double get recognizedTotal => items.fold<double>(
    0,
    (sum, item) => sum + (item.draft.quantity * item.draft.unitPrice),
  );

  double? get differenceFromDeclaredTotal {
    final total = declaredTotal;
    return total == null ? null : recognizedTotal - total;
  }
}

class FiscalReceiptImportPlan {
  const FiscalReceiptImportPlan({
    required this.updatedList,
    required this.appliedDrafts,
    required this.addedCount,
    required this.updatedCount,
  });

  final ShoppingListModel updatedList;
  final List<ShoppingItemDraft> appliedDrafts;
  final int addedCount;
  final int updatedCount;
}

class FiscalReceiptImportTransaction {
  const FiscalReceiptImportTransaction({
    required this.beforeList,
    required this.appliedList,
    required this.catalogBefore,
    required this.historyBefore,
    required this.pantryBefore,
    required this.addedCount,
    required this.updatedCount,
    this.completedPurchaseId,
  });

  final ShoppingListModel beforeList;
  final ShoppingListModel appliedList;
  final List<CatalogProduct> catalogBefore;
  final List<CompletedPurchase> historyBefore;
  final List<PantryItem> pantryBefore;
  final int addedCount;
  final int updatedCount;
  final String? completedPurchaseId;

  bool get finalizedPurchase => completedPurchaseId != null;
}

class FiscalReceiptImportPlanner {
  const FiscalReceiptImportPlanner();

  FiscalReceiptImportPlan createPlan({
    required ShoppingListModel source,
    required FiscalReceiptReviewSubmission submission,
    required DateTime recordedAt,
    required String Function() createId,
  }) {
    if (source.isClosed) {
      throw StateError('A lista já está fechada.');
    }
    if (submission.items.isEmpty) {
      throw ArgumentError.value(
        submission.items,
        'submission.items',
        'Selecione pelo menos um item.',
      );
    }

    final items = source.items
        .map((item) => item.copyWith())
        .toList(growable: true);
    final claimedItemIds = <String>{};
    final appliedDrafts = <ShoppingItemDraft>[];
    var addedCount = 0;
    var updatedCount = 0;

    for (final reviewed in submission.items) {
      final draft = _validatedDraft(reviewed.draft);
      final plannedId = reviewed.plannedItemId?.trim();
      var targetIndex = -1;

      if (plannedId != null && plannedId.isNotEmpty) {
        if (!claimedItemIds.add(plannedId)) {
          throw StateError(
            'Um item planejado só pode receber uma linha do cupom.',
          );
        }
        targetIndex = items.indexWhere((item) => item.id == plannedId);
        if (targetIndex < 0) {
          throw StateError('O item planejado não está mais disponível.');
        }
      } else {
        final normalizedName = normalizeQuery(draft.name);
        targetIndex = items.indexWhere(
          (item) =>
              !claimedItemIds.contains(item.id) &&
              normalizeQuery(item.name) == normalizedName,
        );
        if (targetIndex >= 0) {
          claimedItemIds.add(items[targetIndex].id);
        }
      }

      if (targetIndex >= 0) {
        final existing = items[targetIndex];
        items[targetIndex] = existing.copyWith(
          name: draft.name,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          barcode: draft.barcode ?? existing.barcode,
          isPurchased: true,
          category: draft.category,
          priceHistory: _updatedPriceHistory(
            existing,
            draft.unitPrice,
            recordedAt,
          ),
        );
        updatedCount++;
      } else {
        items.add(
          ShoppingItem(
            id: createId(),
            name: draft.name,
            quantity: draft.quantity,
            unitPrice: draft.unitPrice,
            barcode: draft.barcode,
            isPurchased: true,
            category: draft.category,
            priceHistory: <PriceHistoryEntry>[
              PriceHistoryEntry(price: draft.unitPrice, recordedAt: recordedAt),
            ],
          ),
        );
        addedCount++;
      }

      appliedDrafts.add(
        ShoppingItemDraft(
          name: draft.name,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          category: draft.category,
          barcode: draft.barcode,
          isPurchased: true,
        ),
      );
    }

    return FiscalReceiptImportPlan(
      updatedList: source.copyWith(
        items: List<ShoppingItem>.unmodifiable(items),
        updatedAt: recordedAt,
        isClosed: submission.finalizePurchase,
        closedAt: submission.finalizePurchase ? recordedAt : source.closedAt,
      ),
      appliedDrafts: List<ShoppingItemDraft>.unmodifiable(appliedDrafts),
      addedCount: addedCount,
      updatedCount: updatedCount,
    );
  }

  ShoppingItemDraft _validatedDraft(ShoppingItemDraft draft) {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(draft.name, 'name', 'Informe o produto.');
    }
    if (draft.quantity <= 0) {
      throw ArgumentError.value(
        draft.quantity,
        'quantity',
        'A quantidade deve ser maior que zero.',
      );
    }
    if (!draft.unitPrice.isFinite || draft.unitPrice <= 0) {
      throw ArgumentError.value(
        draft.unitPrice,
        'unitPrice',
        'O preço deve ser maior que zero.',
      );
    }
    return ShoppingItemDraft(
      name: name,
      quantity: max(1, draft.quantity),
      unitPrice: max(0, draft.unitPrice),
      category: draft.category,
      barcode: sanitizeBarcode(draft.barcode),
      isPurchased: true,
    );
  }

  List<PriceHistoryEntry> _updatedPriceHistory(
    ShoppingItem existing,
    double price,
    DateTime recordedAt,
  ) {
    final history = List<PriceHistoryEntry>.from(existing.priceHistory);
    if (history.isEmpty && existing.unitPrice > 0) {
      history.add(
        PriceHistoryEntry(price: existing.unitPrice, recordedAt: recordedAt),
      );
    }
    if (history.isEmpty || (history.last.price - price).abs() > 0.0001) {
      history.add(PriceHistoryEntry(price: price, recordedAt: recordedAt));
    }
    return List<PriceHistoryEntry>.unmodifiable(history);
  }
}
