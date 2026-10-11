import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/pending_drafts_review_sheet.dart';

const _drafts = [
  ShoppingItemDraft(
    name: 'Café torrado e moído 500g',
    quantity: 1,
    unitPrice: 24.90,
    category: ShoppingCategory.grocery,
  ),
  ShoppingItemDraft(
    name: 'Queijo minas frescal',
    quantity: 1,
    unitPrice: 14.50,
    category: ShoppingCategory.grocery,
  ),
  ShoppingItemDraft(
    name: 'Azeite de oliva 500ml',
    quantity: 1,
    unitPrice: 38.90,
    category: ShoppingCategory.grocery,
  ),
];

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

  testWidgets('pending review editorial visual reference', (tester) async {
    await _open(tester, _drafts);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pending_review_stitch_390.png'),
    );
    expect(find.text('3 itens rascunhados'), findsOneWidget);
    expect(find.textContaining('78,30'), findsOneWidget);
    final button = find.widgetWithText(FilledButton, 'Continuar adicionando');
    expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    expect(find.text('Café torrado e moído 500g'), findsOneWidget);
  });

  testWidgets(
    'deletion emits immutable copy immediately and closing keeps result',
    (tester) async {
      final original = List<ShoppingItemDraft>.of(_drafts);
      List<ShoppingItemDraft>? changed;
      await _open(tester, original, onChanged: (value) => changed = value);
      await tester.tap(find.byTooltip('Excluir Queijo minas frescal'));
      await tester.pumpAndSettle();
      expect(changed!.map((item) => item.name), [
        'Café torrado e moído 500g',
        'Azeite de oliva 500ml',
      ]);
      expect(original.length, 3);
      expect(() => changed!.clear(), throwsUnsupportedError);
      await tester.tap(find.byTooltip('Fechar revisão'));
      await tester.pumpAndSettle();
      expect(find.text('Revisar itens'), findsNothing);
      expect(changed!.length, 2);
    },
  );

  testWidgets('empty selection retains return action and real zero total', (
    tester,
  ) async {
    await _open(tester, const []);
    expect(find.textContaining('Nenhum item na seleção.'), findsOneWidget);
    expect(find.text('0 itens rascunhados'), findsOneWidget);
    expect(find.textContaining('0,00'), findsOneWidget);
    await tester.tap(find.text('Continuar adicionando'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
  });

  testWidgets(
    'small dark screen enlarged text preserves long names and footer',
    (tester) async {
      final drafts = List.generate(
        12,
        (index) => ShoppingItemDraft(
          name:
              'Produto com descrição completa e embalagem grande número $index',
          quantity: 2,
          unitPrice: 1599.90,
          category: ShoppingCategory.grocery,
        ),
      );
      await _open(tester, drafts, compact: true);
      expect(tester.takeException(), isNull);
      expect(find.text(drafts.first.name), findsOneWidget);
      expect(find.text('2 un'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byTooltip('Excluir ${drafts.last.name}'),
        250,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(tester.takeException(), isNull);
      final footer = find.widgetWithText(FilledButton, 'Continuar adicionando');
      expect(tester.getRect(footer).bottom, lessThanOrEqualTo(568));
      await tester.tap(footer);
      await tester.pumpAndSettle();
      expect(find.text('Abrir'), findsOneWidget);
    },
  );

  testWidgets(
    'nested price editor with keyboard preserves cancel and unchanged data',
    (tester) async {
      var updates = 0;
      await _open(
        tester,
        [_drafts.first],
        compact: true,
        onChanged: (_) => updates++,
      );
      await tester.tap(find.byTooltip('Editar preço de ${_drafts.first.name}'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final cancel = find.text('Cancelar');
      await tester.ensureVisible(cancel);
      await tester.pumpAndSettle();
      expect(tester.getRect(cancel).bottom, lessThanOrEqualTo(358));
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(updates, 0);
      expect(find.text('Revisar itens'), findsOneWidget);
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  List<ShoppingItemDraft> drafts, {
  bool compact = false,
  ValueChanged<List<ShoppingItemDraft>>? onChanged,
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
        fontFamily: 'MercadoPublicSans',
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
              onPressed: () => showPendingDraftsReviewSheet(
                context,
                drafts: drafts,
                onChanged: onChanged ?? (_) {},
              ),
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
