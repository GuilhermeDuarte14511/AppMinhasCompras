import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/item_actions_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

const _item = ShoppingItem(
  id: 'coffee',
  name: 'Café torrado e moído 500g',
  quantity: 2,
  unitPrice: 24.90,
);

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

  testWidgets('three real actions match Stitch and retain item context', (
    tester,
  ) async {
    _size(tester, const Size(390, 844));
    await _open(tester);
    expect(
      find.descendant(
        of: find.byType(ItemActionsSheet),
        matching: find.byType(ListTile),
      ),
      findsNWidgets(3),
    );
    expect(find.bySemanticsLabel('Ações de ${_item.name}'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/item_actions_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'Editar item': ItemAction.edit,
    'Duplicar item': ItemAction.duplicate,
    'Excluir item': ItemAction.delete,
  }.entries) {
    testWidgets('${entry.key} returns action without changing source', (
      tester,
    ) async {
      ItemAction? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(result, entry.value);
      expect(find.byType(ItemActionsSheet), findsNothing);
      expect(_item.quantity, 2);
      expect(_item.unitPrice, 24.90);
      expect(_item.isPurchased, isFalse);
    });
  }

  testWidgets('barrier and drag dismiss return null', (tester) async {
    for (final drag in [false, true]) {
      var completed = false;
      ItemAction? result = ItemAction.edit;
      await _open(
        tester,
        onResult: (value) {
          completed = true;
          result = value;
        },
      );
      if (drag) {
        await tester.drag(find.byType(ItemActionsSheet), const Offset(0, 400));
      } else {
        await tester.tapAt(const Offset(20, 100));
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
    }
  });

  testWidgets('keyboard navigation activates a focused action', (tester) async {
    ItemAction? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(result, ItemAction.edit);
    expect(find.byType(ItemActionsSheet), findsNothing);
  });

  testWidgets('compact dark enlarged text with keyboard remains operable', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    ItemAction? result;
    await _open(
      tester,
      dark: true,
      scale: 1.8,
      keyboard: 220,
      onResult: (value) => result = value,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Excluir item'),
      80,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('item_actions_scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.widgetWithText(ListTile, 'Excluir item')).height,
      greaterThanOrEqualTo(48),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/item_actions_dark_keyboard_320.png'),
    );
    await tester.tap(find.text('Excluir item'));
    await tester.pumpAndSettle();
    expect(result, ItemAction.delete);
    expect(tester.takeException(), isNull);
  });
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(
  WidgetTester tester, {
  bool dark = false,
  double scale = 1,
  double keyboard = 0,
  ValueChanged<ItemAction?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        dark
            ? ThemeData.dark(useMaterial3: true)
            : ThemeData(useMaterial3: true),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
        ),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Compras da semana')),
        body: Builder(
          builder: (context) => Column(
            children: [
              ListTile(
                title: Text(_item.name),
                subtitle: Text('2 un · R\$ 24,90/un'),
                trailing: Text('R\$ 49,80'),
              ),
              TextButton(
                onPressed: () async {
                  final result = await showItemActionsSheet(
                    context,
                    item: _item,
                  );
                  onResult?.call(result);
                },
                child: const Text('Abrir ações'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir ações'));
  await tester.pumpAndSettle();
}
