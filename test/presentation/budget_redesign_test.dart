import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/budget_editor_dialog.dart';

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
  testWidgets('budget editorial reference uses existing amount', (
    tester,
  ) async {
    await _open(tester, initial: 250);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/budget_stitch_390.png'),
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('budget_field')))
          .controller!
          .text,
      contains('250,00'),
    );
    for (final type in [FilledButton, OutlinedButton, TextButton]) {
      final finder = type == FilledButton
          ? find.widgetWithText(FilledButton, 'Salvar')
          : type == OutlinedButton
          ? find.widgetWithText(OutlinedButton, 'Cancelar')
          : find.widgetWithText(TextButton, 'Remover limite');
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
    }
  });
  testWidgets('save returns formatted positive budget', (tester) async {
    BudgetEditorResult? result;
    await _open(tester, onResult: (value) => result = value);
    expect(find.text('Remover limite'), findsNothing);
    await tester.enterText(find.byKey(const Key('budget_field')), '12345');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(result?.value, 123.45);
    expect(result?.clear, isFalse);
  });
  testWidgets('IME done rejects empty zero nonfinite and saves positive', (
    tester,
  ) async {
    BudgetEditorResult? result;
    await _open(tester, onResult: (value) => result = value);
    final finder = find.byKey(const Key('budget_field'));
    await tester.tap(finder);
    for (final raw in ['', '0', List.filled(400, '9').join()]) {
      tester.widget<TextFormField>(finder).controller!.text = raw;
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor válido.'), findsOneWidget);
      expect(result, isNull);
    }
    await tester.enterText(finder, '999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result?.value, 9.99);
  });
  testWidgets('remove returns clear and dismissal returns null', (
    tester,
  ) async {
    BudgetEditorResult? result;
    await _open(tester, initial: 250, onResult: (value) => result = value);
    await tester.tap(find.text('Remover limite'));
    await tester.pumpAndSettle();
    expect(result?.clear, isTrue);
    expect(result?.value, isNull);
    for (final close in [true, false]) {
      var called = false;
      await _open(
        tester,
        initial: 250,
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
    'compact dark enlarged keyboard keeps actions visible with error',
    (tester) async {
      await _open(tester, initial: 250, compact: true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final finder = find.byKey(const Key('budget_field'));
      tester.widget<TextFormField>(finder).controller!.text = '';
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Salvar', 'Cancelar', 'Remover limite']) {
        expect(tester.getRect(find.text(label)).bottom, lessThanOrEqualTo(358));
      }
      await tester.ensureVisible(finder);
      await tester.enterText(finder, '1050');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Abrir'), findsOneWidget);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  double? initial,
  bool compact = false,
  ValueChanged<BudgetEditorResult?>? onResult,
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
                final result = await showBudgetEditorDialog(
                  context,
                  initialValue: initial,
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
