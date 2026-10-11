import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/my_lists/my_lists_layout.dart';
import 'package:lista_compras_material/src/presentation/my_lists/list_ledger_row.dart';
import 'package:lista_compras_material/src/presentation/theme/mercado_editorial_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('search ignores case and status filters use real lists', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'SÁBADO');
    await tester.pumpAndSettle();
    expect(find.text('Feira de sábado'), findsOneWidget);
    expect(find.text('Churrasco'), findsNothing);
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my_lists_filter_closed')));
    await tester.pumpAndSettle();
    expect(find.text('Churrasco'), findsOneWidget);
    expect(find.text('Feira de sábado'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('my_lists_filter_shared')),
    );
    await tester.tap(find.byKey(const ValueKey('my_lists_filter_shared')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma lista encontrada'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros').first);
    await tester.pumpAndSettle();
    expect(find.text('Feira de sábado'), findsOneWidget);
    expect(find.text('Churrasco'), findsOneWidget);
  });

  testWidgets('single delete uses confirmation and can be undone', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Opções da lista').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir lista'));
    await tester.pumpAndSettle();
    expect(find.text('Feira de sábado'), findsWidgets);
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    expect(find.text('Feira de sábado'), findsNothing);
    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    expect(find.text('Feira de sábado'), findsOneWidget);
  });

  testWidgets('closed list can reopen through existing action', (tester) async {
    await _open(tester);
    await tester.ensureVisible(find.text('Churrasco'));
    final row = find.ancestor(
      of: find.text('Churrasco'),
      matching: find.byType(ListLedgerRow),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byTooltip('Opções da lista')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reabrir lista'));
    await tester.pumpAndSettle();
    expect(find.text('Abertas (2)'), findsOneWidget);
    expect(find.text('Fechadas (0)'), findsOneWidget);
  });

  testWidgets('long press selects a row without opening the editor', (
    tester,
  ) async {
    await _open(tester);
    await tester.longPress(find.text('Feira de sábado'));
    await tester.pumpAndSettle();
    expect(find.text('1 selecionada'), findsOneWidget);
    expect(find.byTooltip('Excluir selecionadas'), findsOneWidget);
    await tester.tap(find.byTooltip('Cancelar seleção'));
    await tester.pumpAndSettle();
    expect(find.text('Minhas listas'), findsOneWidget);
  });

  testWidgets('mobile ledger visual reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('lists-capture'), child: _visual()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('lists-capture')),
      matchesGoldenFile('goldens/my_lists_stitch_390.png'),
    );
  });

  testWidgets('dark small ledger supports keyboard and enlarged text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_visual(dark: true, scale: 1.5));
    await tester.ensureVisible(find.text('Churrasco'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

final _lists = [
  ShoppingListModel(
    id: 'fair',
    name: 'Feira de sábado',
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
  ),
  ShoppingListModel(
    id: 'bbq',
    name: 'Churrasco',
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
    isClosed: true,
    closedAt: DateTime(2026, 10, 8),
    items: const [
      ShoppingItem(
        id: 'meat',
        name: 'Carne',
        quantity: 2,
        unitPrice: 30,
        isPurchased: true,
      ),
    ],
  ),
];

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('dash_action_lists')));
  await tester.tap(find.byKey(const ValueKey('dash_action_lists')));
  await tester.pumpAndSettle();
}

Widget _visual({bool dark = false, double scale = 1}) {
  final controller = TextEditingController();
  void noop() {}
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: mercadoEditorialTheme(dark ? ThemeData.dark() : ThemeData.light()),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Minhas listas'),
        actions: const [
          Icon(Icons.delete_outline),
          SizedBox(width: 16),
          Icon(Icons.more_vert),
          SizedBox(width: 16),
        ],
      ),
      body: MyListsLayout(
        lists: _lists,
        sharedCount: 0,
        visibleCount: 2,
        controller: controller,
        filter: MyListsFilter.all,
        selectionMode: false,
        onFilter: (_) {},
        onClear: noop,
        onCreate: noop,
        onTemplate: noop,
        onHistory: noop,
        onReplenishment: noop,
        rows: _lists
            .map(
              (list) => ListLedgerRow(
                list: list,
                selectionMode: false,
                isSelected: false,
                onToggleSelection: noop,
                onLongPress: noop,
                onOpen: noop,
                onReopen: noop,
                onCreateFromThis: noop,
                onDelete: noop,
              ),
            )
            .toList(),
      ),
    ),
  );
}

class _MemoryStorage implements ShoppingListsStorage {
  List<ShoppingListModel> lists = List.of(_lists);
  @override
  Future<List<ShoppingListModel>> loadLists() async => lists;
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    this.lists = List.of(lists);
  }
}
