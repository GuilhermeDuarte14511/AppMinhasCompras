import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/delete_item_dialog.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

const _item = ShoppingItem(
  id: 'coffee',
  name: 'Café especial',
  quantity: 1,
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

  testWidgets('delete item matches Stitch with actual item name', (
    tester,
  ) async {
    await _open(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/delete_item_stitch_390.png'),
    );
    expect(
      find.text('Deseja remover ‘Café especial’ da lista?'),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Cancelar')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Excluir')).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  for (final action in ['Excluir', 'Cancelar', 'barrier', 'back']) {
    testWidgets('$action returns only the explicit decision', (tester) async {
      bool? result;
      var completed = false;
      await _open(
        tester,
        onResult: (value) {
          completed = true;
          result = value;
        },
      );
      if (action == 'barrier') {
        await tester.tapAt(const Offset(4, 100));
      } else if (action == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(
        result,
        action == 'Excluir'
            ? true
            : action == 'Cancelar'
            ? false
            : null,
      );
      expect(_item.name, 'Café especial');
      expect(_item.unitPrice, 24.90);
      expect(find.text('Excluir item?'), findsNothing);
    });
  }

  testWidgets('long names wrap fully and can be cancelled', (tester) async {
    final name = List.filled(12, 'Café especial de torra artesanal').join(' ');
    await _open(tester, item: _item.copyWith(name: name));
    expect(find.text('Deseja remover ‘$name’ da lista?'), findsOneWidget);
    await tester.ensureVisible(find.text('Cancelar'));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Excluir item?'), findsNothing);
  });

  testWidgets('compact dark enlarged text and keyboard remain operable', (
    tester,
  ) async {
    bool? result;
    await _open(tester, compact: true, onResult: (value) => result = value);
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Excluir'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/delete_item_dark_keyboard_320.png'),
    );
    expect(tester.getRect(find.text('Excluir')).bottom, lessThan(358));
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(
  WidgetTester tester, {
  ShoppingItem item = _item,
  bool compact = false,
  ValueChanged<bool?>? onResult,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: compact ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Compras da semana')),
          body: Column(
            children: [
              ListTile(
                title: Text(item.name),
                subtitle: const Text('1 unidade'),
                trailing: const Text('R\$ 24,90'),
              ),
              TextButton(
                onPressed: () async {
                  final result = await showDeleteItemDialog(
                    context,
                    item: item,
                  );
                  onResult?.call(result);
                },
                child: const Text('Abrir'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
