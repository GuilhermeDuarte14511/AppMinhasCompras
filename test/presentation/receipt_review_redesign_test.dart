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
    'review reference exposes real categories and accessible actions',
    (tester) async {
      await _open(tester);
      await _review(tester);
      expect(find.text('Revisar compra'), findsOneWidget);
      expect(find.text(ShoppingCategory.grainsAndPasta.label), findsWidgets);
      for (final label in ['Editar texto', 'Confirmar compra']) {
        expect(tester.getSize(find.text(label)).height, greaterThan(0));
        final target = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      }
      await expectLater(
        find.byType(FiscalReceiptImportSheet),
        matchesGoldenFile('goldens/receipt_review_stitch_390.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('no selection disables confirmation and totals remain truthful', (
    tester,
  ) async {
    await _open(tester);
    await _review(tester);
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    expect(find.text('0 itens selecionados'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar compra'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Selecionar todos'));
    await tester.pumpAndSettle();
    expect(find.text('2 itens selecionados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('missing receipt total gives real reconciliation warning', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Texto do cupom'),
      'AR001 ARROZ TIPO 1 1 UND9 20,00 20,00',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar 1 item'));
    await tester.pumpAndSettle();
    expect(
      find.text('O total do cupom não foi identificado. Confira os valores.'),
      findsOneWidget,
    );
    expect(find.text('Total declarado'), findsNothing);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(FiscalReceiptImportSheet), findsNothing);
  });
  testWidgets('compact dark editing and keyboard preserve reachable footer', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
    await _review(tester);
    await tester.ensureVisible(find.text('Editar').first);
    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getBottomRight(find.widgetWithText(FilledButton, 'Confirmar compra'))
          .dy,
      lessThanOrEqualTo(358),
    );
    await tester.tap(find.text('Editar texto'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Texto do cupom'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
