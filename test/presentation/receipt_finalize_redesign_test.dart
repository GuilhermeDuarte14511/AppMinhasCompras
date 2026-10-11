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

  testWidgets('receipt completion reference uses real totals and matching', (
    tester,
  ) async {
    await _open(tester);
    await _review(tester);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      find.text('A soma dos itens confere com o total do cupom.'),
      findsOneWidget,
    );
    expect(find.text('Total declarado'), findsOneWidget);
    await expectLater(
      find.byType(FiscalReceiptImportSheet),
      matchesGoldenFile('goldens/receipt_finalize_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'confirm closes purchase and preserves linked drafts and declared total',
    (tester) async {
      FiscalReceiptReviewSubmission? result;
      await _open(tester, onResult: (value) => result = value);
      await _review(tester);
      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();
      expect(result!.finalizePurchase, isTrue);
      expect(result!.declaredTotal, 38.90);
      expect(result!.items, hasLength(2));
      expect(result!.items.first.plannedItemId, 'rice');
      expect(result!.items.first.draft.unitPrice, 20);
    },
  );
  testWidgets('apply only preserves selection and does not finalize purchase', (
    tester,
  ) async {
    FiscalReceiptReviewSubmission? result;
    await _open(tester, onResult: (value) => result = value);
    await _review(tester);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.text('1 item selecionado'), findsOneWidget);
    expect(find.textContaining('A soma difere do cupom em'), findsOneWidget);
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Aplicar à lista'), findsOneWidget);
    await tester.tap(find.text('Aplicar à lista'));
    await tester.pumpAndSettle();
    expect(result!.finalizePurchase, isFalse);
    expect(result!.items, hasLength(1));
    expect(result!.items.single.plannedItemId, 'rice');
    expect(result!.declaredTotal, 38.90);
  });
  testWidgets('header edits selected items without clearing entered values', (
    tester,
  ) async {
    await _open(tester);
    await _review(tester);
    await tester.tap(find.byTooltip('Editar itens selecionados'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produto').first,
      'Arroz integral',
    );
    await tester.tap(find.byTooltip('Editar itens selecionados'));
    await tester.pumpAndSettle();
    expect(find.text('Arroz integral'), findsOneWidget);
    await tester.tap(find.byTooltip('Editar itens selecionados'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Produto').first,
          )
          .controller!
          .text,
      'Arroz integral',
    );
  });
  testWidgets('no selection disables both header editing and confirmation', (
    tester,
  ) async {
    await _open(tester);
    await _review(tester);
    await tester.tap(find.text('Desmarcar todos'));
    await tester.pumpAndSettle();
    final header = find.ancestor(
      of: find.byTooltip('Editar itens selecionados'),
      matching: find.byType(TextButton),
    );
    expect(tester.widget<TextButton>(header).onPressed, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar compra'),
          )
          .onPressed,
      isNull,
    );
  });
  testWidgets('compact dark keyboard keeps final action reachable', (
    tester,
  ) async {
    await _open(tester, size: const Size(320, 568), dark: true, scale: 1.5);
    await _review(tester);
    await tester.tap(find.byTooltip('Editar itens selecionados'));
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
