import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/market_mode_page.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor_page.dart';

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

  testWidgets('detailed list mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await _openEditor(tester);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ShoppingListEditorPage),
      matchesGoldenFile('goldens/list_editor_stitch_390.png'),
    );
  });

  testWidgets('market mobile visual reference', (tester) async {
    _size(tester, const Size(390, 884));
    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingMarketModePage(
          initialList: _list(),
          onSave: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ShoppingMarketModePage),
      matchesGoldenFile('goldens/market_mode_stitch_390.png'),
    );
  });

  testWidgets(
    'detailed list small screen enlarged text keeps add action reachable',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _openEditor(tester, scale: 1.5);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('editor_add_item')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Item'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'closed detailed list retains read-only state and reopen action',
    (tester) async {
      _size(tester, const Size(390, 884));
      await _openEditor(tester, closed: true);
      expect(find.byKey(const ValueKey('editor_add_item')), findsNothing);
      await tester.tap(find.text('Reabrir lista'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('editor_add_item')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'market search and filters retain purchased items without changing data',
    (tester) async {
      _size(tester, const Size(390, 884));
      ShoppingListModel? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: ShoppingMarketModePage(
            initialList: _list(),
            onSave: (list) async => saved = list,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos (5)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'OVOS');
      await tester.pumpAndSettle();
      final toggle = find.byKey(const ValueKey('market_toggle_eggs'));
      await tester.scrollUntilVisible(
        toggle,
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        saved!.items.singleWhere((item) => item.id == 'eggs').isPurchased,
        isFalse,
      );
      expect(saved!.isClosed, isFalse);
      expect(saved!.items.length, 5);
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

Future<void> _openEditor(
  WidgetTester tester, {
  double scale = 1,
  bool closed = false,
}) async {
  await tester.pumpWidget(
    ShoppingListApp(
      storage: _MemoryStorage(_list().copyWith(isClosed: closed)),
    ),
  );
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.byKey(const ValueKey('dash_action_lists')));
  await tester.tap(find.byKey(const ValueKey('dash_action_lists')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compras da semana'));
  await tester.pumpAndSettle();
  if (scale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
  }
}

ShoppingListModel _list() => ShoppingListModel(
  id: 'weekly',
  name: 'Compras da semana',
  createdAt: DateTime(2026, 10, 9),
  updatedAt: DateTime(2026, 10, 9),
  budget: 250,
  items: const [
    ShoppingItem(
      id: 'rice',
      name: 'Arroz agulhinha tipo 1 5kg',
      quantity: 1,
      unitPrice: 29.90,
      isPurchased: false,
    ),
    ShoppingItem(
      id: 'milk',
      name: 'Leite integral pasteurizado tipo A',
      quantity: 2,
      unitPrice: 6.90,
      isPurchased: false,
    ),
    ShoppingItem(
      id: 'coffee',
      name: 'Café torrado e moído 500g',
      quantity: 2,
      unitPrice: 24.90,
      isPurchased: false,
    ),
    ShoppingItem(
      id: 'oil',
      name: 'Azeite de oliva extravirgem 500ml',
      quantity: 1,
      unitPrice: 38.90,
      isPurchased: false,
    ),
    ShoppingItem(
      id: 'eggs',
      name: 'Ovos caipiras (dúzia)',
      quantity: 1,
      unitPrice: 14,
      isPurchased: true,
    ),
  ],
);

class _MemoryStorage implements ShoppingListsStorage {
  _MemoryStorage(this.list);
  ShoppingListModel list;
  @override
  Future<List<ShoppingListModel>> loadLists() async => [list];
  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    list = lists.first;
  }
}
