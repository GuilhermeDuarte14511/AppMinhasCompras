import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/editor_price_history_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';
import 'package:lista_compras_material/src/presentation/utils/app_modal.dart';

final _records = [
  PriceHistoryEntry(price: 20.40, recordedAt: DateTime(2024, 9, 22, 11, 5)),
  PriceHistoryEntry(price: 24.90, recordedAt: DateTime(2024, 10, 28, 9, 15)),
  PriceHistoryEntry(price: 17.50, recordedAt: DateTime(2024, 8, 5, 10, 20)),
  PriceHistoryEntry(price: 18.90, recordedAt: DateTime(2024, 10, 14, 16, 40)),
];
final _item = ShoppingItem(
  id: 'coffee',
  name: 'Café especial torrado e moído 250g',
  quantity: 1,
  unitPrice: 24.90,
  priceHistory: _records,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets(
    'Stitch renders real newest first prices and chronological deltas without mutation',
    (tester) async {
      _size(tester, const Size(390, 844));
      final before = List<PriceHistoryEntry>.of(_records);
      await _open(tester);
      expect(find.text(_item.name), findsOneWidget);
      expect(find.text('+${formatCurrency(6)}'), findsOneWidget);
      expect(find.text('−${formatCurrency(1.5)}'), findsOneWidget);
      expect(find.text('+${formatCurrency(2.9)}'), findsOneWidget);
      expect(find.text('Inicial'), findsOneWidget);
      expect(find.text('28 de outubro de 2024, 09:15'), findsOneWidget);
      final prices = [24.90, 18.90, 20.40, 17.50]
          .map(
            (price) => tester.getTopLeft(find.text(formatCurrency(price))).dy,
          )
          .toList();
      expect(prices, orderedEquals([...prices]..sort()));
      expect(_records, orderedEquals(before));
      expect(_item.unitPrice, 24.90);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/price_history_stitch_390.png'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('equal price is neutral and first record remains initial', (
    tester,
  ) async {
    final item = _item.copyWith(
      priceHistory: [
        PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 2)),
        PriceHistoryEntry(price: 10, recordedAt: DateTime(2026, 1, 1)),
      ],
    );
    await _open(tester, item: item);
    expect(find.text('Sem alteração'), findsOneWidget);
    expect(find.text('Inicial'), findsOneWidget);
    final text = tester.widget<Text>(find.text('Sem alteração'));
    final context = tester.element(find.text('Sem alteração'));
    expect(text.style!.color, Theme.of(context).colorScheme.onSurfaceVariant);
  });

  testWidgets('empty history shows no fabricated records', (tester) async {
    await _open(tester, item: _item.copyWith(priceHistory: []));
    expect(find.text('Sem histórico registrado ainda.'), findsOneWidget);
    expect(find.text('Inicial'), findsNothing);
    expect(find.text(formatCurrency(24.90)), findsNothing);
    await tester.tap(find.byTooltip('Fechar histórico de preços'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorPriceHistorySheet), findsNothing);
  });

  for (final dismissal in ['close', 'back', 'barrier']) {
    testWidgets('$dismissal dismisses without altering source history', (
      tester,
    ) async {
      final before = List<PriceHistoryEntry>.of(_records);
      _size(tester, const Size(390, 844));
      await _open(tester);
      if (dismissal == 'close') {
        await tester.tap(find.byTooltip('Fechar histórico de preços'));
      } else if (dismissal == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tapAt(const Offset(15, 100));
      }
      await tester.pumpAndSettle();
      expect(find.byType(EditorPriceHistorySheet), findsNothing);
      expect(_records, orderedEquals(before));
    });
  }

  testWidgets(
    'dark compact keyboard long name and enlarged text scroll without overflow',
    (tester) async {
      _size(tester, const Size(320, 568));
      final item = _item.copyWith(
        name:
            'Café especial torrado e moído com embalagem de edição familiar para compras do mês',
      );
      await _open(tester, item: item, dark: true, scale: 1.8, keyboard: 220);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Inicial'),
        80,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('price_history_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/price_history_dark_keyboard_320.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byTooltip('Fechar histórico de preços'),
        -80,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('price_history_scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byTooltip('Fechar histórico de preços')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byTooltip('Fechar histórico de preços'));
      await tester.pumpAndSettle();
      expect(find.byType(EditorPriceHistorySheet), findsNothing);
    },
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _open(
  WidgetTester tester, {
  ShoppingItem? item,
  bool dark = false,
  double scale = 1,
  double keyboard = 0,
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
          builder: (context) => TextButton(
            onPressed: () => showAppModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              useSafeArea: true,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerLowest,
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.sizeOf(context).height * .85 -
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: EditorPriceHistorySheet(item: item ?? _item),
                ),
              ),
            ),
            child: const Text('Abrir histórico'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir histórico'));
  await tester.pumpAndSettle();
}
