import 'dart:async';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shared_lists/widgets/shared_history_sheet.dart';
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
  testWidgets(
    'shared history golden presents actual month dates and paid total',
    (tester) async {
      final repo = await _open(tester);
      repo.events.add([
        _purchase('older', DateTime(2026, 9, 2)),
        _purchase('latest', DateTime(2026, 10, 10, 10, 42)),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('2 registros'), findsOneWidget);
      expect(
        find.text('Valor final pago: ${formatCurrency(25)}'),
        findsOneWidget,
      );
      expect(find.text('Carteira: ${formatCurrency(10)}'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/shared_history_stitch_390.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading error empty and streamed recovery are distinct', (
    tester,
  ) async {
    final repo = await _open(tester);
    expect(find.text('Carregando histórico…'), findsOneWidget);
    expect(find.text('Nenhuma compra fechada ainda.'), findsNothing);
    repo.events.addError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível carregar o histórico.'), findsOneWidget);
    expect(find.text('Nenhuma compra fechada ainda.'), findsNothing);
    repo.events.add([]);
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma compra fechada ainda.'), findsOneWidget);
    repo.events.add([_purchase('new', DateTime(2026, 10, 2))]);
    await tester.pumpAndSettle();
    expect(find.text('1 registro'), findsOneWidget);
    expect(repo.subscriptions, 1);
  });
  testWidgets(
    'sorts months and purchases newest first without changing source array',
    (tester) async {
      final repo = await _open(tester);
      final entries = [
        _purchase('sep', DateTime(2026, 9, 2)),
        _purchase('early', DateTime(2026, 10, 1)),
        _purchase('late', DateTime(2026, 10, 10)),
      ];
      repo.events.add(entries);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ocultar detalhes'));
      await tester.pumpAndSettle();
      final cards = tester
          .widgetList<SharedHistoryCard>(find.byType(SharedHistoryCard))
          .toList();
      expect(cards.map((c) => c.purchase.id), ['late', 'early', 'sep']);
      expect(entries.first.id, 'sep');
      expect(find.text('outubro 2026'), findsOneWidget);
      expect(find.text('setembro 2026'), findsOneWidget);
    },
  );
  testWidgets(
    'inline detail toggles preserve actual quantities prices and payment usage',
    (tester) async {
      final repo = await _open(tester);
      repo.events.add([_purchase('latest', DateTime(2026, 10, 10))]);
      await tester.pumpAndSettle();
      expect(find.text('2 × ${formatCurrency(15)}'), findsOneWidget);
      expect(find.text('Subtotal: ${formatCurrency(30)}'), findsOneWidget);
      expect(
        find.text('Valor final pago: ${formatCurrency(25)}'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ocultar detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Café torrado e moído 500g'), findsNothing);
      await tester.tap(find.text('Ver detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Café torrado e moído 500g'), findsOneWidget);
      expect(repo.subscriptions, 1);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      expect(find.byType(SharedHistorySheet), findsNothing);
    },
  );
  testWidgets(
    'compact dark enlarged layout scrolls long details and close stays reachable',
    (tester) async {
      final repo = await _open(
        tester,
        size: const Size(320, 568),
        dark: true,
        scale: 1.5,
      );
      repo.events.add([_purchase('new', DateTime(2026, 10, 10), long: true)]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getBottomRight(find.text('Fechar')).dy,
        lessThanOrEqualTo(568),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Fechar histórico'));
      await tester.pumpAndSettle();
      expect(find.byType(SharedHistorySheet), findsNothing);
    },
  );
  testWidgets('standalone details remain available with real payment usage', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedHistoryDetailsSheet(
            purchase: _purchase('one', DateTime(2026, 10, 10)),
          ),
        ),
      ),
    );
    expect(find.text('Café torrado e moído 500g'), findsOneWidget);
    expect(find.text('Carteira: ${formatCurrency(10)}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

CompletedPurchase _purchase(
  String id,
  DateTime date, {
  bool long = false,
}) => CompletedPurchase(
  id: id,
  listId: 'shared',
  listName: 'Compras da semana',
  closedAt: date,
  items: [
    ShoppingItem(
      id: 'coffee',
      name: long
          ? 'Café torrado e moído especial da seleção de compras da família em embalagem econômica'
          : 'Café torrado e moído 500g',
      quantity: 2,
      unitPrice: 15,
      isPurchased: true,
    ),
  ],
  finalTotalCents: 2500,
  paymentBalances: const [
    PaymentBalance(
      id: 'wallet',
      name: 'Carteira',
      type: PaymentBalanceType.cash,
      amount: 10,
    ),
  ],
);
Future<_Repo> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final repo = _Repo();
  addTearDown(repo.events.close);
  final list = SharedShoppingListSummary(
    id: 'shared',
    name: 'Compras da semana',
    ownerUid: 'owner',
    memberUids: ['owner'],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
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
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              useSafeArea: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              builder: (_) => SharedHistorySheet(list: list, repository: repo),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump(const Duration(milliseconds: 500));
  return repo;
}

class _Repo implements SharedListsRepository {
  final events = StreamController<List<CompletedPurchase>>.broadcast();
  int subscriptions = 0;
  @override
  Stream<List<CompletedPurchase>> watchSharedHistory(String listId) {
    expect(listId, 'shared');
    subscriptions++;
    return events.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
