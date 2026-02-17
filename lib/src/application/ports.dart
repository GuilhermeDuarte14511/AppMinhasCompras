import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';

abstract class ShoppingListsStorage {
  Future<List<ShoppingListModel>> loadLists();

  Future<void> saveLists(List<ShoppingListModel> lists);
}

abstract class ProductCatalogStorage {
  Future<List<CatalogProduct>> loadProducts();

  Future<void> saveProducts(List<CatalogProduct> products);
}

abstract class PurchaseHistoryStorage {
  Future<List<CompletedPurchase>> loadHistory();

  Future<void> saveHistory(List<CompletedPurchase> history);
}

abstract class ProductCatalogGateway {
  Future<void> load();

  List<CatalogProduct> allProducts();

  CatalogProduct? findByName(String rawName);

  CatalogProduct? findByBarcode(String? rawBarcode);

  List<String> suggestNames({String query = '', int limit = 20});

  Future<void> upsertFromDraft(ShoppingItemDraft draft);

  Future<void> upsertFromLookupResult(ProductLookupResult result);

  Future<void> ingestFromLists(Iterable<ShoppingListModel> lists);

  Future<void> replaceAllProducts(List<CatalogProduct> products);

  void dispose();
}

enum ProductLookupSource {
  cosmos,
  openFoodFacts,
  openProductsFacts,
  localCatalog,
  notFound,
}

class ProductLookupResult {
  const ProductLookupResult({
    required this.source,
    required this.barcode,
    this.name,
    this.category,
    this.unitPrice,
    this.priceHistory = const [],
  });

  final ProductLookupSource source;
  final String barcode;
  final String? name;
  final ShoppingCategory? category;
  final double? unitPrice;
  final List<PriceHistoryEntry> priceHistory;

  bool get hasData => name != null || category != null || unitPrice != null;
}

abstract class ProductLookupService {
  Future<ProductLookupResult?> lookupByBarcode(String barcode);
}

abstract class ShoppingBackupService {
  Future<BackupExportResult> exportBackup(String payload);

  Future<String?> importBackup();
}

abstract class ShoppingReminderService {
  Future<void> initialize();

  Future<void> scheduleForList(ShoppingListModel list);

  Future<void> cancelForList(String listId);

  Future<void> notifyBudgetNearLimit(
    ShoppingListModel list, {
    required double budgetUsageRatio,
  });

  Future<void> notifySyncPending({
    required int pendingRecords,
    required bool hasNetworkConnection,
  });

  Future<void> syncFromLists(
    List<ShoppingListModel> lists, {
    bool reset = false,
  });
}

abstract class ShoppingHomeWidgetService {
  Future<void> updateFromLists(List<ShoppingListModel> lists);
}
