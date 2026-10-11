import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/catalog_products_page.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/shopping_item_editor_sheet.dart';
import 'package:lista_compras_material/src/presentation/dialogs/widgets/item_editor_category_picker.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('new item mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _openForm(tester);
    await _fill(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_item_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('new item saves current fields and category', (tester) async {
    _size(tester, const Size(390, 884));
    List<ShoppingItemDraft>? result;
    await _openForm(tester, onResult: (drafts) => result = drafts);
    await _fill(tester);
    expect(find.textContaining('37,80'), findsWidgets);
    expect(
      tester
          .widget<ItemEditorCategoryPicker>(
            find.byType(ItemEditorCategoryPicker),
          )
          .value,
      ShoppingCategory.grocery,
    );
    await tester.ensureVisible(find.text('Já peguei este item'));
    await tester.tap(find.text('Já peguei este item'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar item'));
    await tester.pumpAndSettle();
    expect(result!.single.name, 'Café especial torrado moído 250g');
    expect(result!.single.quantity, 2);
    expect(result!.single.unitPrice, 18.90);
    expect(result!.single.isPurchased, isTrue);
    expect(result!.single.barcode, '7891808123456');
  });

  testWidgets('new item compact keyboard dark layout has reachable footer', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _openForm(tester, dark: true, scale: 1.5);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Adicionar item').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('catalog mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _openCatalog(tester);
    await expectLater(
      find.byType(CatalogProductsPage),
      matchesGoldenFile('goldens/catalog_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'catalog category barcode price and search filters use real data',
    (tester) async {
      await _openCatalog(tester);
      await tester.tap(
        find.byKey(
          ValueKey('catalog_category_${ShoppingCategory.produce.key}'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Banana prata madura'), findsOneWidget);
      expect(find.text('Café especial torrado moído 250g'), findsNothing);
      await tester.ensureVisible(find.text('Limpar filtros'));
      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '7891808');
      await tester.pumpAndSettle();
      expect(find.text('Café especial torrado moído 250g'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Com código de barras'));
      await tester.pumpAndSettle();
      expect(find.text('Café especial torrado moído 250g'), findsOneWidget);
      expect(find.text('Banana prata madura'), findsNothing);
      await tester.tap(find.text('Com código de barras'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sem preço').first);
      await tester.tap(find.text('Sem preço').first);
      await tester.pumpAndSettle();
      expect(find.text('Sabão neutro'), findsOneWidget);
      expect(find.text('Banana prata madura'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'catalog selection delete cancellation and pantry action survive redesign',
    (tester) async {
      await _openCatalog(tester);
      await tester.longPress(find.text('Café especial torrado moído 250g'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo (1)'), findsOneWidget);
      await tester.tap(find.byTooltip('Excluir selecionados'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Café especial torrado moído 250g'), findsOneWidget);
      await tester.tap(find.byTooltip('Sair da seleção'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Ações do produto').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar à despensa'));
      await tester.pumpAndSettle();
      expect(find.textContaining('foi adicionado à despensa'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('catalog small enlarged layout and registration work', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _openCatalog(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cadastrar produto'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'catalog batch category and deletion persist through existing store',
    (tester) async {
      final storage = _MemoryCatalog();
      await _openCatalog(tester, storage: storage);
      await tester.longPress(find.text('Café especial torrado moído 250g'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Selecionar visíveis'));
      await tester.pumpAndSettle();
      expect(find.text('Catálogo (4)'), findsOneWidget);
      await tester.tap(find.byTooltip('Categoria em lote'));
      await tester.pumpAndSettle();
      tester
          .widget<DropdownButtonFormField<ShoppingCategory>>(
            find.byType(DropdownButtonFormField<ShoppingCategory>),
          )
          .onChanged!(ShoppingCategory.bakery);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();
      expect(
        storage.products.every(
          (product) => product.category == ShoppingCategory.bakery,
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Excluir selecionados'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
      await tester.pumpAndSettle();
      expect(storage.products, isEmpty);
      expect(find.text('Adicione produtos frequentes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _openForm(
  WidgetTester tester, {
  bool dark = false,
  double scale = 1,
  ValueChanged<List<ShoppingItemDraft>?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        dark ? ThemeData.dark() : ThemeData.light(),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Minhas Compras')),
          body: TextButton(
            onPressed: () async {
              final result = await showShoppingItemsEditorSheet(context);
              onResult?.call(result);
            },
            child: const Text('Abrir formulário'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir formulário'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Item'),
    'Café especial torrado moído 250g',
  );
  await tester.enterText(find.widgetWithText(TextFormField, 'Quantidade'), '2');
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Valor unitário'),
    '1890',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
    '7891808123456',
  );
  await tester.pumpAndSettle();
}

Future<void> _openCatalog(
  WidgetTester tester, {
  _MemoryCatalog? storage,
}) async {
  await tester.pumpWidget(
    ShoppingListApp(
      storage: _MemoryLists(),
      catalogStorage: storage ?? _MemoryCatalog(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(
    find.byKey(const ValueKey('dash_action_template')),
  );
  await tester.tap(find.byKey(const ValueKey('dash_action_template')));
  await tester.pumpAndSettle();
}

class _MemoryLists implements ShoppingListsStorage {
  @override
  Future<List<ShoppingListModel>> loadLists() async => [];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {}
}

class _MemoryCatalog implements ProductCatalogStorage {
  List<CatalogProduct> products = [
    CatalogProduct(
      id: 'coffee',
      name: 'Café especial torrado moído 250g',
      category: ShoppingCategory.grocery,
      unitPrice: 18.90,
      barcode: '7891808123456',
      usageCount: 14,
      updatedAt: DateTime(2026, 10, 9),
      priceHistory: [],
    ),
    CatalogProduct(
      id: 'banana',
      name: 'Banana prata madura',
      category: ShoppingCategory.produce,
      unitPrice: 7.49,
      usageCount: 10,
      updatedAt: DateTime(2026, 10, 8),
      priceHistory: [],
    ),
    CatalogProduct(
      id: 'milk',
      name: 'Leite integral pasteurizado tipo A',
      category: ShoppingCategory.dairy,
      unitPrice: 6.90,
      usageCount: 22,
      updatedAt: DateTime(2026, 10, 7),
      priceHistory: [],
    ),
    CatalogProduct(
      id: 'soap',
      name: 'Sabão neutro',
      category: ShoppingCategory.cleaning,
      usageCount: 2,
      updatedAt: DateTime(2026, 10, 6),
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
