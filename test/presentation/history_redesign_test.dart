import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/application/store_and_services.dart';
import 'package:lista_compras_material/src/data/repositories/product_catalog_repository.dart';
import 'package:lista_compras_material/src/data/services/reminder_service.dart';
import 'package:lista_compras_material/src/data/services/home_widget_service.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/purchase_history_page.dart';
import 'package:lista_compras_material/src/presentation/purchase_history/completed_purchase_details_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

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
  testWidgets('history mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PurchaseHistoryPage),
      matchesGoldenFile('goldens/history_stitch_390.png'),
    );
  });
  testWidgets('closed purchase mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    await tester.tap(find.text('Feira de sábado'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(CompletedPurchaseDetailsSheet),
      matchesGoldenFile('goldens/closed_purchase_stitch_390.png'),
    );
  });
  testWidgets(
    'history search matches list or products and recomputes month totals',
    (tester) async {
      await _open(tester);
      expect(find.text('Outubro 2026'), findsOneWidget);
      expect(find.textContaining('67,40'), findsOneWidget);
      expect(find.textContaining('62,50'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Café');
      await tester.pumpAndSettle();
      expect(find.text('Feira de sábado'), findsOneWidget);
      expect(find.text('Reposição e limpeza'), findsNothing);
      expect(find.text('1 fechamento · 1 mês'), findsOneWidget);
      expect(find.textContaining('54,90'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'não existe');
      await tester.pumpAndSettle();
      expect(find.text('Nenhum fechamento encontrado'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('Feira de sábado'), findsOneWidget);
    },
  );
  testWidgets('history delete and clear remain confirmed and persist', (
    tester,
  ) async {
    final history = _History();
    final store = await _open(tester, history: history);
    await tester.tap(find.byTooltip('Excluir fechamento').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(store.purchaseHistory.length, 3);
    await tester.tap(find.byTooltip('Excluir fechamento').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(history.values.length, 2);
    await tester.tap(find.widgetWithText(TextButton, 'Limpar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(history.values.length, 2);
    await tester.tap(find.widgetWithText(TextButton, 'Limpar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
    await tester.pumpAndSettle();
    expect(history.values, isEmpty);
    expect(find.text('Sem histórico de compras'), findsOneWidget);
  });
  testWidgets(
    'closed purchase preserves pending items budget and payment usage',
    (tester) async {
      await _open(tester, history: _History(withBalances: true));
      await tester.tap(find.text('Feira de sábado'));
      await tester.pumpAndSettle();
      final sheet = find.byType(CompletedPurchaseDetailsSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('1 produto')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Orçamento')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.textContaining('50,00')),
        findsWidgets,
      );
      await _scrollTo(tester, 'Como a compra foi paga');
      expect(find.text('Saldo esgotado.'), findsWidgets);
      expect(find.textContaining('Ainda sem cobertura:'), findsOneWidget);
      await _scrollTo(tester, 'Leite integral 1L');
      expect(
        find.descendant(of: sheet, matching: find.text('Pendente')),
        findsOneWidget,
      );
      expect(find.textContaining('6,90'), findsWidgets);
      expect(find.text('Duplicar como nova lista'), findsNothing);
      expect(find.text('Reabrir lista'), findsNothing);
      await tester.tap(find.byTooltip('Fechar detalhes'));
      await tester.pumpAndSettle();
      expect(find.byType(CompletedPurchaseDetailsSheet), findsNothing);
    },
  );
  testWidgets('history preserves finance partial sync and retry', (
    tester,
  ) async {
    final finance = _Finance(withRecords: true);
    await _open(tester, finance: finance);
    expect(find.text('Sincronização parcial · 1/2'), findsOneWidget);
    await tester.ensureVisible(find.text('Reenviar pendentes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reenviar pendentes'));
    await tester.pumpAndSettle();
    expect(finance.retried, 'fair');
    expect(find.text('Sincronizado com o Finanças'), findsOneWidget);
  });
  testWidgets('history and details compact dark enlarged text layouts', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _open(
      tester,
      scale: 1.5,
      dark: true,
      history: _History(withBalances: true),
    );
    await tester.enterText(find.byType(TextField), 'Feira');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Feira de sábado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Feira de sábado'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, 'Leite integral 1L');
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Fechar detalhes').hitTestable(), findsOneWidget);
  });
  testWidgets('empty history retains create list action', (tester) async {
    final history = _History()..values = [];
    await _open(tester, history: history);
    await tester.tap(find.widgetWithText(FilledButton, 'Criar lista'));
    await tester.pumpAndSettle();
    expect(find.text('Nova lista de compras'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Sem histórico de compras'), findsOneWidget);
  });

  testWidgets(
    'finance query error is hidden for purchases without finance activity',
    (tester) async {
      await _open(tester, finance: _Finance(historyFails: true));
      expect(find.text('Feira de sábado'), findsOneWidget);
      expect(find.text('Não foi possível consultar o envio'), findsNothing);
    },
  );
}

Future<void> _scrollTo(WidgetTester tester, String text) async {
  final scrollable = find
      .descendant(
        of: find.byType(CompletedPurchaseDetailsSheet),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text(text).last,
    150,
    scrollable: scrollable,
  );
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<ShoppingListsStore> _open(
  WidgetTester tester, {
  _History? history,
  _Finance? finance,
  double scale = 1,
  bool dark = false,
}) async {
  if (tester.view.physicalSize == const Size(800, 600)) {
    _size(tester, const Size(390, 884));
  }
  final store = ShoppingListsStore(
    _Lists(),
    reminderService: const NoopShoppingReminderService(),
    productCatalog: ProductCatalogRepository(_Catalog()),
    historyStorage: history ?? _History(),
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
                builder: (_) => PurchaseHistoryPage(
                  store: store,
                  financeRepository: finance ?? _Finance(),
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

class _Lists implements ShoppingListsStorage {
  @override
  Future<List<ShoppingListModel>> loadLists() async => [];
  @override
  Future<void> saveLists(List<ShoppingListModel> value) async {}
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
  _History({bool withBalances = false}) {
    values = [
      CompletedPurchase(
        id: 'fair',
        listId: 'list1',
        listName: 'Feira de sábado',
        closedAt: DateTime(2026, 10, 9, 14, 30),
        finalTotalCents: 5000,
        budget: 70,
        paymentBalances: withBalances
            ? [
                PaymentBalance(
                  id: 'cash',
                  name: 'Dinheiro',
                  type: PaymentBalanceType.cash,
                  amount: 30,
                ),
                PaymentBalance(
                  id: 'pix',
                  name: 'Conta',
                  type: PaymentBalanceType.pix,
                  amount: 10,
                ),
              ]
            : [],
        items: [
          ShoppingItem(
            id: 'coffee',
            name: 'Café especial torrado e moído 250g',
            quantity: 2,
            unitPrice: 18.9,
            category: ShoppingCategory.grocery,
            isPurchased: true,
          ),
          ShoppingItem(
            id: 'banana',
            name: 'Banana prata madura',
            quantity: 1,
            unitPrice: 10.2,
            category: ShoppingCategory.produce,
            isPurchased: true,
          ),
          ShoppingItem(
            id: 'milk',
            name: 'Leite integral 1L',
            quantity: 1,
            unitPrice: 6.9,
            category: ShoppingCategory.dairy,
          ),
        ],
      ),
      CompletedPurchase(
        id: 'clean',
        listId: 'list2',
        listName: 'Reposição e limpeza',
        closedAt: DateTime(2026, 10, 3),
        items: [
          ShoppingItem(
            id: 'soap',
            name: 'Sabão neutro',
            quantity: 1,
            unitPrice: 12.5,
            category: ShoppingCategory.cleaning,
            isPurchased: true,
          ),
        ],
      ),
      CompletedPurchase(
        id: 'monthly',
        listId: 'list3',
        listName: 'Compras do mês',
        closedAt: DateTime(2026, 9, 20),
        items: [
          ShoppingItem(
            id: 'rice',
            name: 'Arroz agulhinha 5kg',
            quantity: 1,
            unitPrice: 29.8,
            category: ShoppingCategory.grocery,
            isPurchased: true,
          ),
        ],
      ),
    ];
  }
  List<CompletedPurchase> values = [];
  @override
  Future<List<CompletedPurchase>> loadHistory() async => values;
  @override
  Future<void> saveHistory(List<CompletedPurchase> value) async {
    values = value;
  }
}

class _Finance implements FinanceIntegrationRepository {
  _Finance({bool withRecords = false, this.historyFails = false}) {
    if (withRecords) {
      records = [
        for (final entry in [
          ('cash', FinanceSyncStatus.synced),
          ('pix', FinanceSyncStatus.pending),
        ])
          FinancePurchaseSync(
            purchaseId: 'fair',
            sourceName: entry.$1,
            status: entry.$2,
            request: FinancePurchaseRequest(
              externalPurchaseId: entry.$1,
              cardId: entry.$1,
              paymentSourceKind: FinancePaymentSourceKind.debit,
              description: 'Feira de sábado',
              amountCents: 2500,
              purchasedOn: DateTime(2026, 10, 9),
            ),
          ),
      ];
    }
  }
  List<FinancePurchaseSync> records = [];
  final bool historyFails;
  String? retried;
  @override
  Future<List<FinancePurchaseSync>> purchaseSyncHistory() async {
    if (historyFails) throw StateError('Finance unavailable');
    return records;
  }

  @override
  Future<void> retryPurchase(String purchaseId) async {
    retried = purchaseId;
    records = [
      for (final record in records)
        FinancePurchaseSync(
          purchaseId: record.purchaseId,
          sourceName: record.sourceName,
          request: record.request,
          status: FinanceSyncStatus.synced,
        ),
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
