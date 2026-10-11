import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dashboard/dashboard_content.dart';
import 'package:lista_compras_material/src/presentation/dashboard/dashboard_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('empty dashboard contains no invented purchases or dates', (
    tester,
  ) async {
    await tester.pumpWidget(_app(lists: []));
    expect(find.text('0 listas'), findsWidgets);
    expect(find.text('Lista em andamento'), findsNothing);
    expect(find.text('Reposição sugerida'), findsNothing);
    expect(find.text('Atualizado hoje'), findsNothing);
    await tester.ensureVisible(
      find.text('Crie sua primeira lista para começar.'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('list actions target the same real list and creation delegates', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(_app(onAction: calls.add));
    await tester.tap(find.byKey(const ValueKey('dash_action_new')));
    await tester.ensureVisible(find.text('Continuar compra'));
    await tester.tap(find.text('Continuar compra'));
    await tester.tap(find.text('Abrir lista'));
    expect(calls, ['new', 'continue:week', 'open:week']);
    expect(find.text('1 de 2 itens comprados · 50%'), findsOneWidget);
  });

  testWidgets('missing budget is explicit and over-budget amount is accurate', (
    tester,
  ) async {
    await tester.pumpWidget(_app(lists: [_list.copyWith(budget: 20)]));
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data ?? '').startsWith('Acima do teto:') &&
            (widget.data ?? '').contains('15,00'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(_app(lists: [_list.copyWith(clearBudget: true)]));
    expect(find.text('Não definido'), findsOneWidget);
    expect(find.textContaining('do orçamento'), findsNothing);
  });

  testWidgets('dashboard mobile visual reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('dashboard-capture'), child: _app()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('dashboard-capture')),
      matchesGoldenFile('goldens/dashboard_stitch_390.png'),
    );
  });

  testWidgets(
    'small dark dashboard with long names and enlarged text has no overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        _app(
          dark: true,
          scale: 1.5,
          lists: [
            _list.copyWith(
              name: 'Compras da semana para a casa e produtos de limpeza',
            ),
          ],
        ),
      );
      await tester.ensureVisible(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

final _list = ShoppingListModel(
  id: 'week',
  name: 'Compras da semana',
  createdAt: DateTime(2026, 10, 9),
  updatedAt: DateTime(2026, 10, 9),
  budget: 50,
  items: const [
    ShoppingItem(
      id: 'rice',
      name: 'Arroz',
      quantity: 2,
      unitPrice: 10,
      isPurchased: true,
    ),
    ShoppingItem(
      id: 'coffee',
      name: 'Café',
      quantity: 1,
      unitPrice: 15,
      isPurchased: false,
    ),
  ],
);

Widget _app({
  List<ShoppingListModel>? lists,
  ValueChanged<String>? onAction,
  bool dark = false,
  double scale = 1,
}) {
  final data = lists ?? [_list];
  void action(String value) => onAction?.call(value);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dashboardTheme(dark ? ThemeData.dark() : ThemeData.light()),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Compras'),
        leading: const Icon(DashboardIcons.book),
        actions: const [
          Icon(DashboardIcons.synced),
          SizedBox(width: 16),
          Icon(DashboardIcons.profile),
          SizedBox(width: 16),
        ],
      ),
      body: DashboardContent(
        lists: data,
        catalogCount: 2,
        pantry: [],
        suggestions: [],
        activeList: data.isEmpty ? null : data.first,
        shortcuts: [
          DashboardShortcut(
            key: const ValueKey('dash_action_lists'),
            title: 'Minhas listas',
            subtitle: '${data.length} listas',
            icon: DashboardIcons.lists,
            onTap: () => action('lists'),
          ),
          DashboardShortcut(
            key: const ValueKey('dash_action_history'),
            title: 'Histórico mensal',
            subtitle: 'Compras finalizadas',
            icon: DashboardIcons.history,
            onTap: () => action('history'),
          ),
          DashboardShortcut(
            key: const ValueKey('dash_action_template'),
            title: 'Catálogo',
            subtitle: '2 produtos',
            icon: DashboardIcons.catalog,
            onTap: () => action('catalog'),
          ),
          DashboardShortcut(
            key: const ValueKey('dash_action_pantry'),
            title: 'Despensa',
            subtitle: 'Produtos para repor',
            icon: DashboardIcons.pantry,
            onTap: () => action('pantry'),
          ),
          DashboardShortcut(
            key: const ValueKey('dash_action_based'),
            title: 'Usar modelo',
            subtitle: 'Copie uma lista.',
            icon: DashboardIcons.copy,
            onTap: () => action('template'),
          ),
        ],
        onCreate: () => action('new'),
        onLists: () => action('lists'),
        onReplenish: () => action('replenish'),
        onPantry: () => action('pantry'),
        onOpenList: (list) => action('open:${list.id}'),
        onContinue: (list) => action('continue:${list.id}'),
      ),
    ),
  );
}
