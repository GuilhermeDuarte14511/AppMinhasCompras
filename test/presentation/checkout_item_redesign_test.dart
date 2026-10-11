import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/purchase_checkout/checkout_item_editor_dialog.dart';

final _item = ShoppingItem(
  id: 'coffee',
  name: 'Café especial',
  quantity: 2,
  unitPrice: 18.9,
  isPurchased: true,
  barcode: '7891234567890',
  priceHistory: [
    PriceHistoryEntry(price: 17.5, recordedAt: DateTime(2026, 9, 1)),
  ],
);
final _quantity = find.byKey(const Key('checkout_item_quantity'));
final _price = find.byKey(const Key('checkout_item_price'));

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
  testWidgets('editorial correction shows real fields and accessible actions', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Corrigir Café especial'), findsOneWidget);
    expect(tester.widget<TextFormField>(_quantity).controller!.text, '2');
    expect(
      tester.widget<TextFormField>(_price).controller!.text,
      contains('18,90'),
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );
    for (final finder in [
      find.widgetWithText(FilledButton, 'Aplicar correção'),
      find.widgetWithText(TextButton, 'Cancelar'),
      find.byTooltip('Fechar'),
    ]) {
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/checkout_item_stitch_390.png'),
    );
  });
  testWidgets(
    'apply creates copy with edited quantity price state and intact metadata',
    (tester) async {
      ShoppingItem? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.enterText(_quantity, '3');
      await tester.enterText(_price, '2050');
      await tester.tap(find.text('Item comprado'));
      await tester.tap(find.text('Aplicar correção'));
      await tester.pumpAndSettle();
      expect(result, isNot(same(_item)));
      expect(result!.quantity, 3);
      expect(result!.unitPrice, 20.5);
      expect(result!.isPurchased, isFalse);
      expect(result!.id, _item.id);
      expect(result!.name, _item.name);
      expect(result!.barcode, _item.barcode);
      expect(result!.category, _item.category);
      expect(result!.priceHistory, same(_item.priceHistory));
      expect(_item.quantity, 2);
      expect(_item.unitPrice, 18.9);
      expect(_item.isPurchased, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'invalid quantities and zero empty infinite prices cannot apply',
    (tester) async {
      var returned = false;
      await _open(tester, onResult: (_) => returned = true);
      for (final raw in ['', '0', '999999999999999999999999']) {
        tester.widget<TextFormField>(_quantity).controller!.text = raw;
        await tester.tap(find.text('Aplicar correção'));
        await tester.pumpAndSettle();
        expect(find.text('Informe uma quantidade válida.'), findsOneWidget);
        expect(returned, isFalse);
      }
      tester.widget<TextFormField>(_quantity).controller!.text = '1';
      for (final raw in ['', '0', List.filled(400, '9').join()]) {
        tester.widget<TextFormField>(_price).controller!.text = raw;
        await tester.tap(find.text('Aplicar correção'));
        await tester.pumpAndSettle();
        expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
        expect(returned, isFalse);
      }
    },
  );
  testWidgets(
    'IME done saves and cancel close discard edits without disposal errors',
    (tester) async {
      ShoppingItem? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.enterText(_price, '2400');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result!.unitPrice, 24);
      expect(tester.takeException(), isNull);
      for (final close in [false, true]) {
        var returned = false;
        await _open(
          tester,
          onResult: (value) {
            returned = true;
            result = value;
          },
        );
        await tester.enterText(_quantity, '9');
        await tester.tap(
          close ? find.byTooltip('Fechar') : find.text('Cancelar'),
        );
        await tester.pumpAndSettle();
        expect(returned, isTrue);
        expect(result, isNull);
        expect(_item.quantity, 2);
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets(
    'compact dark enlarged keyboard keeps actions visible and field scrollable',
    (tester) async {
      await _open(tester, compact: true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar correção'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Reopen to inspect and edit with the keyboard present.
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (final label in ['Aplicar correção', 'Cancelar']) {
        expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(358));
      }
      await tester.ensureVisible(_price);
      await tester.enterText(_price, '2590');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  bool compact = false,
  ValueChanged<ShoppingItem?>? onResult,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await showCheckoutItemEditor(
                  context,
                  item: _item,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
