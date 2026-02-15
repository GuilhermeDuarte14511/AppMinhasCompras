import 'dart:math';

import 'classifications.dart';
import '../core/utils/id_utils.dart';
import '../core/utils/text_utils.dart';

export '../core/utils/id_utils.dart';
export '../core/utils/text_utils.dart';

class ShoppingListModel {
  const ShoppingListModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
    this.budget,
    this.reminder,
    this.paymentBalances = const [],
    this.isClosed = false,
    this.closedAt,
  });

  factory ShoppingListModel.empty({required String name}) {
    return ShoppingListModel(
      id: uniqueId(),
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      items: const [],
      budget: null,
      reminder: null,
      isClosed: false,
      closedAt: null,
    );
  }

  factory ShoppingListModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final parsedItems = <ShoppingItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          parsedItems.add(
            ShoppingItem.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    final rawReminder = json['reminder'];
    final rawClosedAt = json['closedAt'];

    return ShoppingListModel(
      id: (json['id'] as String?) ?? uniqueId(),
      name: (json['name'] as String?) ?? 'Lista sem nome',
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
      items: parsedItems,
      budget: (json['budget'] as num?)?.toDouble(),
      reminder: rawReminder is Map
          ? ShoppingReminderConfig.fromJson(
              Map<String, dynamic>.from(rawReminder),
            )
          : null,
      paymentBalances: _parsePaymentBalances(json['paymentBalances']),
      isClosed: (json['isClosed'] as bool?) ?? false,
      closedAt: rawClosedAt is String ? DateTime.tryParse(rawClosedAt) : null,
    );
  }

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ShoppingItem> items;
  final double? budget;
  final ShoppingReminderConfig? reminder;
  final List<PaymentBalance> paymentBalances;
  final bool isClosed;
  final DateTime? closedAt;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);
  int get purchasedItemsCount => items.where((item) => item.isPurchased).length;
  double get totalValue =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get pendingValue => items
      .where((item) => !item.isPurchased)
      .fold<double>(0, (sum, item) => sum + item.subtotal);
  bool get hasBudget => budget != null && budget! > 0;
  bool get isOverBudget => hasBudget && totalValue > budget!;
  double get overBudgetAmount => isOverBudget ? totalValue - budget! : 0;
  double get budgetRemaining => hasBudget ? budget! - totalValue : 0;
  bool get hasPaymentBalances =>
      paymentBalances.any((entry) => entry.value > 0);
  double get paymentBalancesTotal =>
      paymentBalances.fold<double>(0, (sum, entry) => sum + entry.value);
  double get uncoveredAmount {
    var pending = totalValue;
    for (final entry in paymentBalances) {
      pending -= entry.value;
      if (pending <= 0) {
        return 0;
      }
    }
    return pending;
  }

  double get coveredAmount => totalValue - uncoveredAmount;
  List<PaymentUsage> get paymentUsage {
    var pending = totalValue;
    final usage = <PaymentUsage>[];
    for (final entry in paymentBalances) {
      final available = entry.value;
      final consumed = pending <= 0 ? 0.0 : min(available, pending);
      pending -= consumed;
      usage.add(
        PaymentUsage(
          balance: entry,
          consumed: consumed,
          remaining: max(available - consumed, 0),
        ),
      );
    }
    return List.unmodifiable(usage);
  }

  bool get isEditable => !isClosed;

  ShoppingListModel deepCopy() {
    return ShoppingListModel(
      id: id,
      name: name,
      createdAt: createdAt,
      updatedAt: updatedAt,
      items: items.map((item) => item.copyWith()).toList(growable: false),
      budget: budget,
      reminder: reminder,
      paymentBalances: paymentBalances
          .map((entry) => entry.copyWith())
          .toList(growable: false),
      isClosed: isClosed,
      closedAt: closedAt,
    );
  }

  ShoppingListModel copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ShoppingItem>? items,
    double? budget,
    ShoppingReminderConfig? reminder,
    List<PaymentBalance>? paymentBalances,
    bool? isClosed,
    DateTime? closedAt,
    bool clearBudget = false,
    bool clearReminder = false,
    bool clearPaymentBalances = false,
    bool clearClosedAt = false,
  }) {
    return ShoppingListModel(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      items: items ?? this.items,
      budget: clearBudget ? null : budget ?? this.budget,
      reminder: clearReminder ? null : reminder ?? this.reminder,
      paymentBalances: clearPaymentBalances
          ? const []
          : paymentBalances ?? this.paymentBalances,
      isClosed: isClosed ?? this.isClosed,
      closedAt: clearClosedAt ? null : closedAt ?? this.closedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
      'budget': budget,
      'reminder': reminder?.toJson(),
      'paymentBalances': paymentBalances
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'isClosed': isClosed,
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  static List<PaymentBalance> _parsePaymentBalances(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final parsed = <PaymentBalance>[];
    for (final entry in raw) {
      if (entry is Map) {
        parsed.add(PaymentBalance.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return List.unmodifiable(parsed);
  }
}

class CompletedPurchase {
  const CompletedPurchase({
    required this.id,
    required this.listId,
    required this.listName,
    required this.closedAt,
    required this.items,
    this.budget,
    this.paymentBalances = const [],
  });

  factory CompletedPurchase.fromList(
    ShoppingListModel list, {
    DateTime? closedAt,
  }) {
    return CompletedPurchase(
      id: uniqueId(),
      listId: list.id,
      listName: list.name,
      closedAt: closedAt ?? DateTime.now(),
      items: list.items.map((item) => item.copyWith()).toList(growable: false),
      budget: list.budget,
      paymentBalances: list.paymentBalances
          .map((entry) => entry.copyWith())
          .toList(growable: false),
    );
  }

  factory CompletedPurchase.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final parsedItems = <ShoppingItem>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is Map) {
          parsedItems.add(
            ShoppingItem.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    return CompletedPurchase(
      id: (json['id'] as String?) ?? uniqueId(),
      listId: (json['listId'] as String?) ?? '',
      listName: (json['listName'] as String?) ?? 'Lista sem nome',
      closedAt:
          DateTime.tryParse((json['closedAt'] as String?) ?? '') ??
          DateTime.now(),
      items: parsedItems,
      budget: (json['budget'] as num?)?.toDouble(),
      paymentBalances: _parsePaymentBalances(json['paymentBalances']),
    );
  }

  final String id;
  final String listId;
  final String listName;
  final DateTime closedAt;
  final List<ShoppingItem> items;
  final double? budget;
  final List<PaymentBalance> paymentBalances;

  int get totalItems => items.fold<int>(0, (sum, item) => sum + item.quantity);
  int get productsCount => items.length;
  int get purchasedProductsCount =>
      items.where((item) => item.isPurchased).length;
  int get pendingProductsCount => productsCount - purchasedProductsCount;
  double get totalValue =>
      items.fold<double>(0, (sum, item) => sum + item.subtotal);
  double get purchasedValue => items
      .where((item) => item.isPurchased)
      .fold<double>(0, (sum, item) => sum + item.subtotal);
  double get pendingValue => items
      .where((item) => !item.isPurchased)
      .fold<double>(0, (sum, item) => sum + item.subtotal);
  bool get hasBudget => budget != null && budget! > 0;
  bool get isOverBudget => hasBudget && totalValue > budget!;
  double get overBudgetAmount => isOverBudget ? totalValue - budget! : 0;
  bool get hasPaymentBalances =>
      paymentBalances.any((entry) => entry.value > 0);
  double get paymentBalancesTotal =>
      paymentBalances.fold<double>(0, (sum, entry) => sum + entry.value);
  double get spentValue =>
      purchasedProductsCount > 0 ? purchasedValue : totalValue;
  double get uncoveredSpentAmount {
    var pending = spentValue;
    for (final entry in paymentBalances) {
      pending -= entry.value;
      if (pending <= 0) {
        return 0;
      }
    }
    return pending;
  }

  double get coveredSpentAmount => spentValue - uncoveredSpentAmount;
  List<PaymentUsage> get paymentUsage {
    var pending = spentValue;
    final usage = <PaymentUsage>[];
    for (final entry in paymentBalances) {
      final available = entry.value;
      final consumed = pending <= 0 ? 0.0 : min(available, pending);
      pending -= consumed;
      usage.add(
        PaymentUsage(
          balance: entry,
          consumed: consumed,
          remaining: max(available - consumed, 0),
        ),
      );
    }
    return List.unmodifiable(usage);
  }

  CompletedPurchase copyWith({
    String? id,
    String? listId,
    String? listName,
    DateTime? closedAt,
    List<ShoppingItem>? items,
    double? budget,
    List<PaymentBalance>? paymentBalances,
    bool clearBudget = false,
    bool clearPaymentBalances = false,
  }) {
    return CompletedPurchase(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      listName: listName ?? this.listName,
      closedAt: closedAt ?? this.closedAt,
      items: items ?? this.items,
      budget: clearBudget ? null : budget ?? this.budget,
      paymentBalances: clearPaymentBalances
          ? const []
          : paymentBalances ?? this.paymentBalances,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listId': listId,
      'listName': listName,
      'closedAt': closedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'budget': budget,
      'paymentBalances': paymentBalances
          .map((entry) => entry.toJson())
          .toList(growable: false),
    };
  }

  static List<PaymentBalance> _parsePaymentBalances(dynamic raw) {
    if (raw is! List) {
      return const [];
    }
    final parsed = <PaymentBalance>[];
    for (final entry in raw) {
      if (entry is Map) {
        parsed.add(PaymentBalance.fromJson(Map<String, dynamic>.from(entry)));
      }
    }
    return List.unmodifiable(parsed);
  }
}

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.category,
    this.unitPrice,
    this.barcode,
    this.usageCount = 1,
    required this.updatedAt,
    this.priceHistory = const [],
  });

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    final parsedUpdatedAt =
        DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
        DateTime.now();
    final rawUnitPrice = json['unitPrice'];
    final parsedUnitPrice = rawUnitPrice is num
        ? rawUnitPrice.toDouble()
        : null;
    final rawHistory = json['priceHistory'];
    var parsedHistory = <PriceHistoryEntry>[];
    if (rawHistory is List) {
      parsedHistory = rawHistory
          .whereType<Map>()
          .map(
            (entry) =>
                PriceHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);
    }
    if (parsedHistory.isEmpty && (parsedUnitPrice ?? 0) > 0) {
      parsedHistory = [
        PriceHistoryEntry(price: parsedUnitPrice!, recordedAt: parsedUpdatedAt),
      ];
    }
    final lastPrice = parsedHistory.isNotEmpty
        ? parsedHistory.last.price
        : parsedUnitPrice;
    return CatalogProduct(
      id: (json['id'] as String?) ?? uniqueId(),
      name: (json['name'] as String?) ?? '',
      category: ShoppingCategoryParser.fromKey(json['category'] as String?),
      unitPrice: lastPrice,
      barcode: sanitizeBarcode(json['barcode'] as String?),
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 1,
      updatedAt: parsedUpdatedAt,
      priceHistory: parsedHistory,
    );
  }

  final String id;
  final String name;
  final ShoppingCategory category;
  final double? unitPrice;
  final String? barcode;
  final int usageCount;
  final DateTime updatedAt;
  final List<PriceHistoryEntry> priceHistory;

  CatalogProduct copyWith({
    String? id,
    String? name,
    ShoppingCategory? category,
    double? unitPrice,
    String? barcode,
    int? usageCount,
    DateTime? updatedAt,
    List<PriceHistoryEntry>? priceHistory,
    bool clearBarcode = false,
  }) {
    return CatalogProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unitPrice: unitPrice ?? this.unitPrice,
      barcode: clearBarcode ? null : sanitizeBarcode(barcode) ?? this.barcode,
      usageCount: usageCount ?? this.usageCount,
      updatedAt: updatedAt ?? this.updatedAt,
      priceHistory: priceHistory ?? this.priceHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.key,
      'unitPrice': unitPrice,
      'barcode': barcode,
      'usageCount': usageCount,
      'updatedAt': updatedAt.toIso8601String(),
      'priceHistory': priceHistory.map((entry) => entry.toJson()).toList(),
    };
  }
}

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.barcode,
    this.isPurchased = false,
    this.category = ShoppingCategory.other,
    this.priceHistory = const [],
  });

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final unitPrice = json['unitPrice'];
    final rawHistory = json['priceHistory'];
    var parsedHistory = <PriceHistoryEntry>[];
    if (rawHistory is List) {
      parsedHistory = rawHistory
          .whereType<Map>()
          .map(
            (entry) =>
                PriceHistoryEntry.fromJson(Map<String, dynamic>.from(entry)),
          )
          .toList(growable: false);
    }
    final parsedUnitPrice = unitPrice is num ? unitPrice.toDouble() : 0.0;
    if (parsedHistory.isEmpty && parsedUnitPrice > 0) {
      parsedHistory = [
        PriceHistoryEntry(price: parsedUnitPrice, recordedAt: DateTime.now()),
      ];
    }

    return ShoppingItem(
      id: (json['id'] as String?) ?? uniqueId(),
      name: (json['name'] as String?) ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: parsedUnitPrice,
      barcode: sanitizeBarcode(json['barcode'] as String?),
      isPurchased: (json['isPurchased'] as bool?) ?? false,
      category: ShoppingCategoryParser.fromKey(json['category'] as String?),
      priceHistory: parsedHistory,
    );
  }

  final String id;
  final String name;
  final int quantity;
  final double unitPrice;
  final String? barcode;
  final bool isPurchased;
  final ShoppingCategory category;
  final List<PriceHistoryEntry> priceHistory;

  double get subtotal => quantity * unitPrice;

  ShoppingItem copyWith({
    String? id,
    String? name,
    int? quantity,
    double? unitPrice,
    String? barcode,
    bool clearBarcode = false,
    bool? isPurchased,
    ShoppingCategory? category,
    List<PriceHistoryEntry>? priceHistory,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      barcode: clearBarcode ? null : sanitizeBarcode(barcode) ?? this.barcode,
      isPurchased: isPurchased ?? this.isPurchased,
      category: category ?? this.category,
      priceHistory: priceHistory ?? this.priceHistory,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'barcode': barcode,
      'isPurchased': isPurchased,
      'category': category.key,
      'priceHistory': priceHistory.map((entry) => entry.toJson()).toList(),
    };
  }
}

class ShoppingItemDraft {
  const ShoppingItemDraft({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.category,
    this.barcode,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final ShoppingCategory category;
  final String? barcode;
}

class BudgetEditorResult {
  const BudgetEditorResult({this.value, this.clear = false});

  final double? value;
  final bool clear;
}

class PaymentBalancesEditorResult {
  const PaymentBalancesEditorResult({this.value, this.clear = false});

  final List<PaymentBalance>? value;
  final bool clear;
}

class ReminderEditorResult {
  const ReminderEditorResult({this.value, this.clear = false});

  final ShoppingReminderConfig? value;
  final bool clear;
}

class PurchaseCheckoutResult {
  const PurchaseCheckoutResult({required this.markPendingAsPurchased});

  final bool markPendingAsPurchased;
}

class ShoppingReminderConfig {
  const ShoppingReminderConfig({required this.scheduledAt});

  factory ShoppingReminderConfig.fromJson(Map<String, dynamic> json) {
    final rawScheduledAt = json['scheduledAt'];
    if (rawScheduledAt is String) {
      final parsed = DateTime.tryParse(rawScheduledAt);
      if (parsed != null) {
        return ShoppingReminderConfig(scheduledAt: _normalize(parsed));
      }
    }

    // Backward compatibility with the old weekly schema.
    final rawWeekday =
        (json['weekday'] as num?)?.toInt() ?? DateTime.now().weekday;
    final rawHour = (json['hour'] as num?)?.toInt() ?? 19;
    final rawMinute = (json['minute'] as num?)?.toInt() ?? 0;
    final weekday = rawWeekday.clamp(DateTime.monday, DateTime.sunday).toInt();
    final hour = rawHour.clamp(0, 23).toInt();
    final minute = rawMinute.clamp(0, 59).toInt();
    return ShoppingReminderConfig(
      scheduledAt: _legacyNextOccurrence(
        weekday: weekday,
        hour: hour,
        minute: minute,
      ),
    );
  }

  final DateTime scheduledAt;

  DateTime nextOccurrence() => scheduledAt;

  static DateTime _normalize(DateTime value) {
    final local = value.toLocal();
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
  }

  static DateTime _legacyNextOccurrence({
    required int weekday,
    required int hour,
    required int minute,
  }) {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, hour, minute);
    while (candidate.weekday != weekday || !candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  Map<String, dynamic> toJson() {
    return {'scheduledAt': scheduledAt.toIso8601String()};
  }
}

class BackupImportReport {
  const BackupImportReport({
    required this.importedLists,
    required this.replaced,
  });

  final int importedLists;
  final bool replaced;
}

enum BackupExportMode { file, clipboard }

class BackupExportResult {
  const BackupExportResult({required this.mode, this.location});

  final BackupExportMode mode;
  final String? location;
}

class PriceHistoryEntry {
  const PriceHistoryEntry({required this.price, required this.recordedAt});

  factory PriceHistoryEntry.fromJson(Map<String, dynamic> json) {
    final rawPrice = json['price'];
    return PriceHistoryEntry(
      price: rawPrice is num ? rawPrice.toDouble() : 0,
      recordedAt:
          DateTime.tryParse((json['recordedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }

  final double price;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() {
    return {'price': price, 'recordedAt': recordedAt.toIso8601String()};
  }
}

enum PaymentBalanceType {
  card('card'),
  debit('debit'),
  pix('pix'),
  voucher('voucher'),
  cash('cash'),
  other('other');

  const PaymentBalanceType(this.key);

  final String key;
}

class PaymentBalanceTypeParser {
  static PaymentBalanceType fromKey(String? key) {
    switch (key) {
      case 'card':
        return PaymentBalanceType.card;
      case 'debit':
        return PaymentBalanceType.debit;
      case 'pix':
        return PaymentBalanceType.pix;
      case 'voucher':
        return PaymentBalanceType.voucher;
      case 'cash':
        return PaymentBalanceType.cash;
      default:
        return PaymentBalanceType.other;
    }
  }
}

extension PaymentBalanceTypeLabel on PaymentBalanceType {
  String get label {
    switch (this) {
      case PaymentBalanceType.card:
        return 'Cartao';
      case PaymentBalanceType.debit:
        return 'Debito';
      case PaymentBalanceType.pix:
        return 'Pix';
      case PaymentBalanceType.voucher:
        return 'Voucher';
      case PaymentBalanceType.cash:
        return 'Dinheiro';
      case PaymentBalanceType.other:
        return 'Outro';
    }
  }
}

class PaymentBalance {
  const PaymentBalance({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
  });

  factory PaymentBalance.fromJson(Map<String, dynamic> json) {
    return PaymentBalance(
      id: (json['id'] as String?) ?? uniqueId(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Saldo',
      type: PaymentBalanceTypeParser.fromKey(json['type'] as String?),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  final String id;
  final String name;
  final PaymentBalanceType type;
  final double amount;

  double get value => max(amount, 0);

  PaymentBalance copyWith({
    String? id,
    String? name,
    PaymentBalanceType? type,
    double? amount,
  }) {
    return PaymentBalance(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'type': type.key, 'amount': amount};
  }
}

class PaymentUsage {
  const PaymentUsage({
    required this.balance,
    required this.consumed,
    required this.remaining,
  });

  final PaymentBalance balance;
  final double consumed;
  final double remaining;

  bool get isExhausted => remaining <= 0.0001;
}
