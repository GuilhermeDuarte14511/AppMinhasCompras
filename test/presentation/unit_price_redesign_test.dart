import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/item_unit_price_sheet.dart';

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
  testWidgets('unit price editorial reference uses actual item and amount', (
    tester,
  ) async {
    await _open(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/unit_price_stitch_390.png'),
    );
    expect(find.text('Café torrado e moído 500g'), findsOneWidget);
    final field = tester.widget<TextFormField>(
      find.byKey(const Key('market_price_field')),
    );
    expect(field.controller!.text, contains('24,90'));
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Atualizar preço'))
          .height,
      greaterThanOrEqualTo(48),
    );
  });
  testWidgets('valid BRL price returns through update', (tester) async {
    double? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.enterText(find.byKey(const Key('market_price_field')), '1234');
    await tester.tap(find.text('Atualizar preço'));
    await tester.pumpAndSettle();
    expect(result, 12.34);
  });
  testWidgets('IME done validates empty zero and nonfinite before accepting', (
    tester,
  ) async {
    double? result;
    await _open(tester, onResult: (value) => result = value);
    final fieldFinder = find.byKey(const Key('market_price_field'));
    for (final invalid in ['', '0', List.filled(400, '9').join()]) {
      // Controller injection also verifies finite validation for values beyond keyboard input.
      tester.widget<TextFormField>(fieldFinder).controller!.text = invalid;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Informe um preço maior que zero.'), findsOneWidget);
      expect(result, isNull);
    }
    await tester.enterText(fieldFinder, '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result, 9.99);
  });
  testWidgets('both explicit dismissal paths return null', (tester) async {
    for (final close in [false, true]) {
      var called = false;
      double? result = 99;
      await _open(
        tester,
        onResult: (value) {
          called = true;
          result = value;
        },
      );
      await tester.tap(
        close ? find.byTooltip('Fechar') : find.text('Cancelar'),
      );
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
    }
  });
  testWidgets(
    'compact dark enlarged text and keyboard retain both footer actions',
    (tester) async {
      await _open(
        tester,
        compact: true,
        name:
            'Café torrado e moído com descrição completa embalagem econômica 500g',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Atualizar preço', 'Cancelar']) {
        expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(358));
      }
      await tester.ensureVisible(find.byKey(const Key('market_price_field')));
      await tester.enterText(
        find.byKey(const Key('market_price_field')),
        '1050',
      );
      await tester.tap(find.text('Atualizar preço'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Abrir'), findsOneWidget);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  bool compact = false,
  String name = 'Café torrado e moído 500g',
  ValueChanged<double?>? onResult,
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
                final result = await showItemUnitPriceSheet(
                  context,
                  name: name,
                  unitPrice: 24.90,
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
