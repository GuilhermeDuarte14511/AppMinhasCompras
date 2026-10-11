import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shared_lists_pages.dart';
import 'package:lista_compras_material/src/presentation/shared_lists/widgets/shared_lists_overview.dart';
import 'package:lista_compras_material/src/presentation/shared_lists/widgets/shared_items_widgets.dart';
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
  testWidgets('shared overview mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await tester.pumpWidget(
      _host(
        Scaffold(
          appBar: AppBar(title: const Text('Listas compartilhadas')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: SharedListsOverview(
              lists: [
                _summary(),
                _summary(
                  id: 'other',
                  name: 'Feira e orgânicos',
                  owner: 'another',
                ),
              ],
              currentUid: 'owner',
              onJoin: () {},
              onOpen: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/shared_overview_stitch_390.png'),
    );
    expect(find.textContaining('Sincronizado'), findsNothing);
    expect(find.textContaining('Estimado'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'overview open join login empty and error states retain callbacks',
    (tester) async {
      String? opened;
      var joined = 0;
      var retry = 0;
      Widget overview({
        String uid = 'owner',
        bool error = false,
        List<SharedShoppingListSummary> lists = const [],
      }) => _host(
        Scaffold(
          body: SharedListsOverview(
            lists: lists,
            currentUid: uid,
            onJoin: () => joined++,
            onOpen: (id) => opened = id,
            hasError: error,
            onRetry: () => retry++,
          ),
        ),
      );
      await tester.pumpWidget(overview(lists: [_summary()]));
      await tester.tap(find.text('Compras da semana'));
      await tester.tap(find.text('Entrar com código'));
      expect(opened, 'shared');
      expect(joined, 1);
      await tester.pumpWidget(overview(uid: ''));
      expect(find.text('Entre para ver listas compartilhadas'), findsOneWidget);
      await tester.pumpWidget(overview());
      expect(find.text('Nenhuma lista compartilhada'), findsOneWidget);
      await tester.pumpWidget(overview(error: true));
      await tester.tap(find.text('Atualizar'));
      expect(retry, 1);
    },
  );
  testWidgets('shared editor mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    await expectLater(
      find.byType(SharedListEditorPage),
      matchesGoldenFile('goldens/shared_editor_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'shared editor changes quantity and picked state through repository',
    (tester) async {
      final repo = await _open(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey("coffee")),
        180,
        scrollable: _scroll(),
      );
      await tester.pumpAndSettle();
      final card = find.byType(SharedItemCard).first;
      final id = tester.widget<SharedItemCard>(card).item.id;
      await tester.ensureVisible(
        find.descendant(of: card, matching: find.byTooltip('Aumentar')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('Aumentar')),
      );
      await tester.pumpAndSettle();
      expect(repo.items.firstWhere((item) => item.id == id).quantity, 3);
      await tester.ensureVisible(
        find.descendant(of: card, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: card, matching: find.byType(Checkbox)),
      );
      await tester.pumpAndSettle();
      expect(
        repo.items.firstWhere((item) => item.id == id).isPurchased,
        isTrue,
      );
      expect(find.text('Comprados 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('shared filters search and empty results use real items', (
    tester,
  ) async {
    await _open(tester);
    await tester.ensureVisible(find.text('Todos 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos 3'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Leite');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(SharedItemCard).first,
      180,
      scrollable: _scroll(),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SharedItemCard>(find.byType(SharedItemCard).first)
          .item
          .name,
      'Leite integral 1L',
    );
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nada encontrado nessa busca'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Todos 3'), findsOneWidget);
  });
  testWidgets('closed shared list disables writes and preserves reopen', (
    tester,
  ) async {
    final repo = await _open(tester, closed: true);
    expect(find.widgetWithText(FilledButton, 'Adicionar item'), findsNothing);
    expect(find.text('Lista fechada'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(SharedItemCard).first,
      180,
      scrollable: _scroll(),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Checkbox>(find.byType(Checkbox).first).onChanged,
      isNull,
    );
    await tester.tap(find.byTooltip('Mais ações'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reabrir lista'));
    await tester.pumpAndSettle();
    expect(repo.list.isClosed, isFalse);
    expect(find.widgetWithText(FilledButton, 'Adicionar item'), findsOneWidget);
  });
  testWidgets('shared settings preserve budget balances and reminder', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Detalhes da lista'));
    await tester.pumpAndSettle();
    expect(find.text('Orçamento'), findsWidgets);
    await tester.ensureVisible(find.text('Carteiras e saldos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carteiras e saldos'));
    await tester.pumpAndSettle();
    expect(find.text('Definir saldos'), findsOneWidget);
    await tester.ensureVisible(find.text('Lembrete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lembrete'));
    await tester.pumpAndSettle();
    expect(find.text('Definir lembrete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared item add action opens existing form', (tester) async {
    await _open(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar item'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Item'), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar formulário'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared editor compact enlarged dark layout', (tester) async {
    _size(tester, const Size(320, 568));
    await _open(tester, scale: 1.5, dark: true);
    expect(
      find.widgetWithText(FilledButton, 'Adicionar item').hitTestable(),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey("coffee")),
      150,
      scrollable: _scroll(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Finder _scroll() => find
    .descendant(
      of: find.byType(CustomScrollView),
      matching: find.byType(Scrollable),
    )
    .first;
void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Widget _host(Widget child, {double scale = 1, bool dark = false}) =>
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
      home: child,
    );
Future<_Repository> _open(
  WidgetTester tester, {
  bool closed = false,
  double scale = 1,
  bool dark = false,
}) async {
  if (tester.view.physicalSize == const Size(800, 600)) {
    _size(tester, const Size(390, 884));
  }
  final repo = _Repository()..list = _summary(closed: closed);
  final store = ShoppingListsStore(
    _Lists(),
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(_Catalog()),
    historyStorage: _History(),
    lookupService: _Lookup(),
    homeWidgetService: const NoopShoppingHomeWidgetService(),
  );
  await store.load();
  addTearDown(store.dispose);
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    _host(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => SharedListEditorPage(
                  repository: repo,
                  store: store,
                  listId: 'shared',
                  currentUidProvider: () => 'owner',
                ),
              ),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
      scale: scale,
      dark: dark,
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump(const Duration(milliseconds: 400));
  repo.lists.add(repo.list);
  await tester.pump();
  repo.itemUpdates.add(repo.items);
  await tester.pumpAndSettle();
  return repo;
}

SharedShoppingListSummary _summary({
  String id = 'shared',
  String name = 'Compras da semana',
  String owner = 'owner',
  bool closed = false,
}) => SharedShoppingListSummary(
  id: id,
  name: name,
  ownerUid: owner,
  memberUids: [owner, 'member'],
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 10, 10),
  budget: 100,
  isClosed: closed,
);

class _Repository implements SharedListsRepository {
  SharedShoppingListSummary list = _summary();
  final lists = StreamController<SharedShoppingListSummary?>.broadcast();
  final itemUpdates = StreamController<List<SharedShoppingItem>>.broadcast();
  List<SharedShoppingItem> items = [
    for (final entry in [
      ('coffee', 'Café especial torrado e moído 250g', 2, 18.9, false),
      ('milk', 'Leite integral 1L', 1, 6.9, false),
      ('banana', 'Banana prata', 1, 10.2, true),
    ])
      SharedShoppingItem(
        id: entry.$1,
        name: entry.$2,
        quantity: entry.$3,
        unitPrice: entry.$4,
        isPurchased: entry.$5,
        updatedBy: 'owner',
        updatedAt: DateTime(2026, 10, 10),
        createdAt: DateTime(2026, 10, 1),
      ),
  ];
  @override
  Stream<SharedShoppingListSummary?> watchSharedList(String listId) =>
      lists.stream;
  @override
  Stream<List<SharedShoppingItem>> watchListItems(String listId) =>
      itemUpdates.stream;
  @override
  Future<void> togglePurchased({
    required String listId,
    required String itemId,
    required bool isPurchased,
    required String updatedBy,
  }) async {
    items = [
      for (final item in items)
        item.id == itemId ? item.copyWith(isPurchased: isPurchased) : item,
    ];
    itemUpdates.add(items);
  }

  @override
  Future<void> changeQuantity({
    required String listId,
    required String itemId,
    required int quantity,
    required String updatedBy,
  }) async {
    items = [
      for (final item in items)
        item.id == itemId ? item.copyWith(quantity: quantity) : item,
    ];
    itemUpdates.add(items);
  }

  @override
  Future<void> reopenSharedList({
    required String listId,
    required String updatedBy,
  }) async {
    list = list.copyWith(isClosed: false);
    lists.add(list);
  }

  Future<void> dispose() async {
    await lists.close();
    await itemUpdates.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Lists implements ShoppingListsStorage {
  @override
  Future<List<ShoppingListModel>> loadLists() async => [];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {}
}

class _Catalog implements ProductCatalogStorage {
  @override
  Future<List<CatalogProduct>> loadProducts() async => [];
  @override
  Future<void> saveProducts(List<CatalogProduct> value) async {}
}

class _History implements PurchaseHistoryStorage {
  @override
  Future<List<CompletedPurchase>> loadHistory() async => [];
  @override
  Future<void> saveHistory(List<CompletedPurchase> value) async {}
}

class _Lookup implements ProductLookupService {
  @override
  Future<ProductLookupResult?> lookupByBarcode(String value) async => null;
}
