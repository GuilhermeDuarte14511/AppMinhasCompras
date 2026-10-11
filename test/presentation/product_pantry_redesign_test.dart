import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/pantry.dart';
import 'package:lista_compras_material/src/presentation/product_details_page.dart';
import 'package:lista_compras_material/src/presentation/pantry_page.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  testWidgets('product mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ProductDetailsPage),
      matchesGoldenFile('goldens/product_stitch_390.png'),
    );
  });
  testWidgets('product updates price and history through existing dialog', (
    tester,
  ) async {
    final store = await _open(tester);
    await tester.tap(find.byTooltip('Atualizar preço'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2190');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    final product = store.catalogProducts.firstWhere((p) => p.id == 'coffee');
    expect(product.unitPrice, 21.9);
    expect(product.priceHistory.length, 7);
    expect(product.priceHistory.last.price, 21.9);
    expect(find.textContaining('21,90'), findsWidgets);
  });
  testWidgets('product without history or price shows actual empty states', (
    tester,
  ) async {
    final store = await _open(tester, productId: 'soap');
    expect(find.text('Sem preço'), findsWidgets);
    expect(find.text('Nenhum preço registrado ainda.'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    await store.replaceCatalogProducts([]);
    await tester.pumpAndSettle();
    expect(find.text('Produto não encontrado'), findsOneWidget);
    expect(find.byTooltip('Editar produto'), findsNothing);
  });
  testWidgets('product compact dark enlarged layout', (tester) async {
    _size(tester, const Size(320, 568));
    await _open(tester, scale: 1.5, dark: true);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -450),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('pantry mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester, pantry: true);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PantryPage),
      matchesGoldenFile('goldens/pantry_stitch_390.png'),
    );
  });
  testWidgets('pantry filters and stock selection persist real states', (
    tester,
  ) async {
    final store = await _open(tester, pantry: true);
    await tester.enterText(find.byType(TextField), 'Café');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Banana prata'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('pantry_status_coffee_in_stock')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('pantry_status_coffee_in_stock')),
    );
    await tester.pumpAndSettle();
    expect(
      store.pantryItems.firstWhere((p) => p.id == 'coffee').status,
      PantryStockStatus.inStock,
    );
    expect(find.text('Adicionar à lista'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Acabou'));
    await tester.pumpAndSettle();
    expect(find.text('Café especial torrado e moído 250g'), findsNothing);
    expect(find.text('Banana prata'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Café especial torrado e moído 250g'),
      150,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Café especial torrado e moído 250g'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pantry replenishment merges existing quantity and confirms removal',
    (tester) async {
      final store = await _open(tester, pantry: true);
      await store.createList(name: 'Reposição');
      await tester.enterText(find.byType(TextField), 'Café');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Adicionar à lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à lista'));
      await tester.pumpAndSettle();
      expect(store.lists.single.items.single.quantity, 2);
      await tester.tap(find.text('Adicionar à lista'));
      await tester.pumpAndSettle();
      expect(store.lists.single.items.single.quantity, 4);
      await tester.tap(
        find.byTooltip(
          'Remover Café especial torrado e moído 250g da despensa',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(store.pantryItems.length, 3);
      await tester.tap(
        find.byTooltip(
          'Remover Café especial torrado e moído 250g da despensa',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();
      expect(store.pantryItems.length, 2);
      expect(find.text('Nenhum produto encontrado'), findsOneWidget);
    },
  );
  testWidgets('pantry catalog picker adds an existing product', (tester) async {
    final store = await _open(tester, pantry: true);
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar produto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sabão neutro'));
    await tester.pumpAndSettle();
    expect(store.pantryItems.any((p) => p.name == 'Sabão neutro'), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pantry compact enlarged dark layout and empty state', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    final store = await _open(tester, pantry: true, scale: 1.5, dark: true);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -380));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final item in [...store.pantryItems]) {
      await store.removePantryItem(item.id);
    }
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sua despensa está vazia'));
    expect(tester.takeException(), isNull);
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<ShoppingListsStore> _open(
  WidgetTester tester, {
  bool pantry = false,
  String productId = 'coffee',
  double scale = 1,
  bool dark = false,
}) async {
  if (tester.view.physicalSize == const Size(800, 600)) {
    _size(tester, const Size(390, 884));
  }
  final catalog = _Catalog();
  final store = ShoppingListsStore(
    _Lists(),
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(catalog),
    historyStorage: _History(),
    pantryStorage: _Pantry(),
    lookupService: _Lookup(),
    homeWidgetService: const NoopShoppingHomeWidgetService(),
  );
  await store.load();
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => pantry
                    ? PantryPage(store: store)
                    : ProductDetailsPage(store: store, productId: productId),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return store;
}

class _Lists implements ShoppingListsStorage {
  @override
  Future<List<ShoppingListModel>> loadLists() async => [];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {}
}

class _History implements PurchaseHistoryStorage {
  @override
  Future<List<CompletedPurchase>> loadHistory() async => [];
  @override
  Future<void> saveHistory(List<CompletedPurchase> history) async {}
}

class _Lookup implements ProductLookupService {
  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async => null;
}

class _Catalog implements ProductCatalogStorage {
  List<CatalogProduct> products = [
    CatalogProduct(
      id: 'coffee',
      name: 'Café especial torrado e moído 250g',
      category: ShoppingCategory.grocery,
      unitPrice: 18.9,
      barcode: '7891808123456',
      usageCount: 8,
      updatedAt: DateTime(2026, 10, 9),
      priceHistory: [
        for (final e in [
          (6, 18.6),
          (7, 20.4),
          (8, 19.4),
          (8, 18.9),
          (9, 17.5),
          (10, 18.9),
        ])
          PriceHistoryEntry(price: e.$2, recordedAt: DateTime(2026, e.$1, 9)),
      ],
    ),
    CatalogProduct(
      id: 'soap',
      name: 'Sabão neutro',
      category: ShoppingCategory.cleaning,
      usageCount: 2,
      updatedAt: DateTime(2026, 10, 8),
      priceHistory: [],
    ),
  ];
  @override
  Future<List<CatalogProduct>> loadProducts() async => products;
  @override
  Future<void> saveProducts(List<CatalogProduct> value) async {
    products = value;
  }
}

class _Pantry implements PantryStorage {
  List<PantryItem> items = [
    PantryItem(
      id: 'coffee',
      catalogProductId: 'coffee',
      name: 'Café especial torrado e moído 250g',
      category: ShoppingCategory.grocery,
      unitPrice: 18.9,
      suggestedQuantity: 2,
      status: PantryStockStatus.runningLow,
      updatedAt: DateTime(2026, 10, 9),
    ),
    PantryItem(
      id: 'banana',
      name: 'Banana prata',
      category: ShoppingCategory.produce,
      unitPrice: 7.5,
      status: PantryStockStatus.outOfStock,
      updatedAt: DateTime(2026, 10, 9),
    ),
    PantryItem(
      id: 'milk',
      name: 'Leite integral 1L',
      category: ShoppingCategory.dairy,
      unitPrice: 6.9,
      status: PantryStockStatus.inStock,
      updatedAt: DateTime(2026, 10, 9),
    ),
  ];
  @override
  Future<List<PantryItem>> loadItems() async => items;
  @override
  Future<void> saveItems(List<PantryItem> value) async {
    items = value;
  }
}
