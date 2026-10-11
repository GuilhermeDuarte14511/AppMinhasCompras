import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/fiscal_receipt_import.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/fiscal_receipt_import_sheet.dart';

const _receipt =
    'AR001 ARROZ TIPO 1 1 UND9 20,00 20,00\nAR002 CAFE TORRADO 1 UND9 18,90 18,90\nValor total R\$ 38,90';

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
  testWidgets('fiscal capture mobile visual reference', (tester) async {
    await _open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Texto do cupom'),
      _receipt,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(FiscalReceiptImportSheet),
      matchesGoldenFile('goldens/fiscal_capture_stitch_390.png'),
    );
    expect(find.text('Ler cupom fiscal'), findsOneWidget);
    expect(find.textContaining('QRCode'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('fiscal review mobile visual reference', (tester) async {
    await _open(tester);
    await _review(tester);
    await expectLater(
      find.byType(FiscalReceiptImportSheet),
      matchesGoldenFile('goldens/fiscal_review_stitch_390.png'),
    );
    expect(find.text('Revisar compra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('paste parses real text and clear removes parsed data', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': _receipt} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Colar texto'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar 2 itens'), findsOneWidget);
    await tester.tap(find.text('Limpar texto'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar 2 itens'), findsNothing);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Revisar itens'),
    );
    expect(button.onPressed, isNull);
  });
  testWidgets(
    'gallery and camera preserve image selection cancellation and failures',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/image_picker');
      final sources = <int>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        sources.add((call.arguments as Map)['source'] as int);
        if (sources.length == 2) {
          throw PlatformException(code: 'permission_denied');
        }
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await _open(tester);
      await tester.tap(find.text('Escolher foto'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma imagem selecionada.'), findsOneWidget);
      await tester.tap(find.text('Fotografar'));
      await tester.pumpAndSettle();
      expect(sources, [1, 0]);
      expect(
        find.text(
          'Não foi possível ler a imagem. Escolha outra foto e tente novamente.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'selection and finalize switch submit reviewed items without finalizing',
    (tester) async {
      FiscalReceiptReviewSubmission? result;
      await _open(tester, onResult: (value) => result = value);
      await _review(tester);
      await tester.tap(find.text('Desmarcar todos'));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar à lista'));
      await tester.pumpAndSettle();
      expect(result!.finalizePurchase, isFalse);
      expect(result!.items, hasLength(1));
      expect(result!.items.single.plannedItemId, 'rice');
      expect(result!.declaredTotal, 38.9);
    },
  );
  testWidgets(
    'invalid edit blocks submit and editing raw text remains available',
    (tester) async {
      await _open(tester);
      await _review(tester);
      await tester.tap(find.text('Editar').first);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade').first,
        '0',
      );
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(find.text('Use 1 ou mais.'), findsOneWidget);
      expect(
        find.text('Revise os campos destacados antes de continuar.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Editar texto'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Texto do cupom'), findsOneWidget);
    },
  );
  testWidgets(
    'compact dark enlarged text and keyboard keep both stages usable',
    (tester) async {
      await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
      await _review(tester);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    },
  );
}

Future<void> _review(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Texto do cupom'),
    _receipt,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Revisar 2 itens'));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester, {
  Size size = const Size(390, 884),
  bool dark = false,
  double scale = 1,
  void Function(FiscalReceiptReviewSubmission?)? onResult,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetViewInsets);
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
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showFiscalReceiptImportSheet(
                  context,
                  currentItems: [
                    ShoppingItem(
                      id: 'rice',
                      name: 'ARROZ TIPO 1',
                      quantity: 1,
                      unitPrice: 19,
                      isPurchased: false,
                      category: ShoppingCategory.grainsAndPasta,
                      priceHistory: const [],
                    ),
                  ],
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
