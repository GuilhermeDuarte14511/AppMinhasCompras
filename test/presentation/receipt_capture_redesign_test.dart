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
  testWidgets(
    'capture empty state has no fabricated total and cancel is reachable',
    (tester) async {
      await _open(tester);
      expect(find.text('Total declarado'), findsNothing);
      expect(find.text('Limpar texto'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Revisar itens'),
            )
            .onPressed,
        isNull,
      );
      for (final label in ['Cancelar', 'Revisar itens']) {
        final target = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byType(FiscalReceiptImportSheet), findsNothing);
    },
  );
  testWidgets(
    'clipboard empty and denied are recoverable without losing typed text',
    (tester) async {
      var denied = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method != 'Clipboard.getData') return null;
          if (denied) throw PlatformException(code: 'denied');
          return {'text': '   '};
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Texto do cupom'),
        _receipt,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Colar texto'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nenhum texto para colar. Copie o texto do cupom e tente novamente.',
        ),
        findsOneWidget,
      );
      denied = true;
      await tester.tap(find.text('Colar texto'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Não foi possível colar. Digite o texto ou escolha uma foto.',
        ),
        findsOneWidget,
      );
      expect(find.text('Revisar 2 itens'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        _receipt,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'capture counts raw lines separately from items and does not infer declared total',
    (tester) async {
      await _open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Texto do cupom'),
        'MERCADO\nAR001 ARROZ TIPO 1 1 UND9 20,00 20,00\nObrigado',
      );
      await tester.pumpAndSettle();
      expect(find.text('3 linhas de texto'), findsOneWidget);
      expect(find.text('Revisar 1 item'), findsOneWidget);
      expect(find.text('Total declarado'), findsNothing);
      expect(find.textContaining('sucesso'), findsNothing);
    },
  );
  testWidgets(
    'compact dark capture with enlarged text and keyboard preserves footer',
    (tester) async {
      await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
      await tester.enterText(
        find.widgetWithText(TextField, 'Texto do cupom'),
        _receipt,
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester
            .getBottomRight(
              find.widgetWithText(FilledButton, 'Revisar 2 itens'),
            )
            .dy,
        lessThanOrEqualTo(368),
      );
      await tester.tap(find.text('Revisar 2 itens'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar compra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
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
