import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/presentation/trash_lists_page.dart';

final _now = DateTime(2026, 10, 10, 12);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  testWidgets('trash mobile reference with real retention dates and count', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('3 listas excluídas'), findsOneWidget);
    expect(find.text('Expira em 22 dias'), findsOneWidget);
    expect(find.text('Expira em 6 dias'), findsOneWidget);
    expect(find.text('Expira em 1 dia'), findsOneWidget);
    expect(find.text('Excluída em 02 de outubro de 2026'), findsOneWidget);
    expect(find.byTooltip('Esvaziar lixeira'), findsNothing);
    await expectLater(
      find.byType(TrashListsPage),
      matchesGoldenFile('goldens/trash_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('restore returns real list and keeps retained contents', (
    tester,
  ) async {
    final storage = _Lists();
    final store = await _open(tester, storage: storage);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restaurar').first);
    await tester.pumpAndSettle();
    expect(store.trashedLists.length, 2);
    expect(store.lists.single.name, 'Feira de sábado e hortifrúti');
    expect(store.lists.single.items.single.name, 'Café');
    expect(
      storage.values.where((value) => value.id == 'fair').single.deletedAt,
      isNull,
    );
    expect(find.text('2 listas excluídas'), findsOneWidget);
    expect(find.textContaining('voltou para suas listas.'), findsOneWidget);
  });
  testWidgets(
    'permanent deletion requires confirmation and cancellation preserves list',
    (tester) async {
      final storage = _Lists();
      final store = await _open(tester, storage: storage);
      await tester.tap(
        find.widgetWithText(TextButton, 'Excluir definitivamente').first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Excluir definitivamente?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(store.trashedLists.length, 3);
      await tester.tap(
        find.widgetWithText(TextButton, 'Excluir definitivamente').first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Excluir definitivamente'),
      );
      await tester.pumpAndSettle();
      expect(store.trashedLists.length, 2);
      expect(storage.values.any((value) => value.id == 'fair'), isFalse);
      expect(find.text('Lista excluída definitivamente.'), findsOneWidget);
    },
  );
  testWidgets('empty state after restoring last entry and back navigation', (
    tester,
  ) async {
    await _open(tester, storage: _Lists(single: true));
    expect(find.text('1 lista excluída'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Restaurar'));
    await tester.pumpAndSettle();
    expect(find.text('A lixeira está vazia'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TrashListsPage), findsNothing);
  });
  testWidgets(
    'positive subhour retention stays one day and expired records are purged',
    (tester) async {
      final now = DateTime.now();
      final storage = _Lists(single: true);
      storage.values = [
        _list(
          'last',
          'Última chance',
          now
              .subtract(const Duration(days: 30))
              .add(const Duration(minutes: 30)),
        ),
      ];
      final store = await _open(tester, storage: storage, now: now);
      expect(find.text('Expira em 1 dia'), findsOneWidget);
      // Advance the page clock past the real retention deadline; opening purges it.
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await _open(
        tester,
        storage: storage,
        now: now.add(const Duration(hours: 1)),
      );
      expect(find.text('A lixeira está vazia'), findsOneWidget);
      expect(storage.values, isEmpty);
      expect(store.trashedLists.length, 1);
    },
  );
  testWidgets(
    'compact dark enlarged text keeps actions scrollable and dialog accessible',
    (tester) async {
      await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Excluir definitivamente').first,
      );
      await tester.tap(
        find.widgetWithText(TextButton, 'Excluir definitivamente').first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Limpeza de primavera'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<ShoppingListsStore> _open(
  WidgetTester tester, {
  _Lists? storage,
  DateTime? now,
  Size size = const Size(390, 884),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final listStorage = storage ?? _Lists();
  final fixtures = List<ShoppingListModel>.of(listStorage.values);
  final store = ShoppingListsStore(
    listStorage,
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(_Catalog()),
    historyStorage: _History(),
    lookupService: _Lookup(),
    homeWidgetService: const NoopShoppingHomeWidgetService(),
  );
  await store.load();
  // Seed after load so the fixed golden clock is independent of host time.
  for (final list in fixtures) {
    await store.upsertList(list, ingestCatalog: false);
  }
  addTearDown(store.dispose);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
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
                builder: (_) => TrashListsPage(
                  store: store,
                  nowProvider: () => now ?? _now,
                ),
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

ShoppingListModel _list(String id, String name, DateTime deleted) =>
    ShoppingListModel(
      id: id,
      name: name,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: deleted,
      deletedAt: deleted,
      items: [
        ShoppingItem(
          id: 'coffee',
          name: 'Café',
          quantity: 2,
          unitPrice: 18.9,
          category: ShoppingCategory.grocery,
        ),
      ],
    );

class _Lists implements ShoppingListsStorage {
  _Lists({bool single = false}) {
    values = [
      _list(
        'fair',
        'Feira de sábado e hortifrúti',
        _now.subtract(const Duration(days: 8)),
      ),
      if (!single)
        _list(
          'bbq',
          'Churrasco da família',
          _now.subtract(const Duration(days: 24)),
        ),
      if (!single)
        _list(
          'spring',
          'Limpeza de primavera',
          _now.subtract(const Duration(days: 29)),
        ),
    ];
  }
  List<ShoppingListModel> values = [];
  @override
  Future<List<ShoppingListModel>> loadLists() async => [];
  @override
  Future<void> saveLists(List<ShoppingListModel> value) async {
    values = List.of(value);
  }
}

class _Catalog implements ProductCatalogStorage {
  @override
  Future<List<CatalogProduct>> loadProducts() async => [];
  @override
  Future<void> saveProducts(List<CatalogProduct> value) async {}
}

class _Lookup implements ProductLookupService {
  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async => null;
}

class _History implements PurchaseHistoryStorage {
  @override
  Future<List<CompletedPurchase>> loadHistory() async => [];
  @override
  Future<void> saveHistory(List<CompletedPurchase> value) async {}
}
