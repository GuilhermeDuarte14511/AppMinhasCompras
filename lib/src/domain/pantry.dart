import 'dart:math';

import 'classifications.dart';
import 'models_and_utils.dart';

enum PantryStockStatus {
  inStock('in_stock'),
  runningLow('running_low'),
  outOfStock('out_of_stock');

  const PantryStockStatus(this.key);

  final String key;

  static PantryStockStatus fromKey(String? key) {
    return PantryStockStatus.values.firstWhere(
      (status) => status.key == key,
      orElse: () => PantryStockStatus.inStock,
    );
  }
}

class PantryItem {
  const PantryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.updatedAt,
    this.catalogProductId,
    this.barcode,
    this.unitPrice,
    this.suggestedQuantity = 1,
    this.lastPurchasedAt,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    final rawUnitPrice = json['unitPrice'];
    return PantryItem(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? (json['id'] as String).trim()
          : uniqueId(),
      catalogProductId: _nonEmptyString(json['catalogProductId']),
      name: _nonEmptyString(json['name']) ?? '',
      category: ShoppingCategoryParser.fromKey(json['category'] as String?),
      barcode: sanitizeBarcode(json['barcode'] as String?),
      unitPrice: rawUnitPrice is num && rawUnitPrice.isFinite
          ? max(0, rawUnitPrice.toDouble())
          : null,
      suggestedQuantity: max(
        1,
        (json['suggestedQuantity'] as num?)?.toInt() ?? 1,
      ),
      status: PantryStockStatus.fromKey(json['status'] as String?),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      lastPurchasedAt: DateTime.tryParse(
        (json['lastPurchasedAt'] as String?) ?? '',
      ),
    );
  }

  final String id;
  final String? catalogProductId;
  final String name;
  final ShoppingCategory category;
  final String? barcode;
  final double? unitPrice;
  final int suggestedQuantity;
  final PantryStockStatus status;
  final DateTime updatedAt;
  final DateTime? lastPurchasedAt;

  bool get needsRestock => status != PantryStockStatus.inStock;

  PantryItem copyWith({
    String? id,
    String? catalogProductId,
    String? name,
    ShoppingCategory? category,
    String? barcode,
    double? unitPrice,
    int? suggestedQuantity,
    PantryStockStatus? status,
    DateTime? updatedAt,
    DateTime? lastPurchasedAt,
    bool clearCatalogProductId = false,
    bool clearBarcode = false,
    bool clearUnitPrice = false,
    bool clearLastPurchasedAt = false,
  }) {
    return PantryItem(
      id: id ?? this.id,
      catalogProductId: clearCatalogProductId
          ? null
          : _nonEmptyString(catalogProductId) ?? this.catalogProductId,
      name: name?.trim().isNotEmpty == true ? name!.trim() : this.name,
      category: category ?? this.category,
      barcode: clearBarcode ? null : sanitizeBarcode(barcode) ?? this.barcode,
      unitPrice: clearUnitPrice ? null : unitPrice ?? this.unitPrice,
      suggestedQuantity: max(1, suggestedQuantity ?? this.suggestedQuantity),
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      lastPurchasedAt: clearLastPurchasedAt
          ? null
          : lastPurchasedAt ?? this.lastPurchasedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'catalogProductId': catalogProductId,
      'name': name,
      'category': category.key,
      'barcode': barcode,
      'unitPrice': unitPrice,
      'suggestedQuantity': suggestedQuantity,
      'status': status.key,
      'updatedAt': updatedAt.toIso8601String(),
      'lastPurchasedAt': lastPurchasedAt?.toIso8601String(),
    };
  }

  static String? _nonEmptyString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
