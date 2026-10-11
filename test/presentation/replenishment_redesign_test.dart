import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';

final _items = [
  ReplenishmentSuggestion(
    name: 'Café torrado e moído 500g',
    category: ShoppingCategory.grocery,
    suggestedQuantity: 1,
    suggestedUnitPrice: 24.9,
    lastPurchasedAt: DateTime(2026, 9, 23),
    occurrences: 3,
    usageCount: 4,
    source: ReplenishmentSuggestionSource.recurring,
    barcode: '123',
  ),
  ReplenishmentSuggestion(
    name: 'Leite integral pasteurizado 1L',
    category: ShoppingCategory.dairy,
    suggestedQuantity: 2,
    suggestedUnitPrice: 6.89,
    lastPurchasedAt: DateTime(2026, 9, 28),
    occurrences: 2,
    usageCount: 3,
    source: ReplenishmentSuggestionSource.lastMonth,
  ),
  ReplenishmentSuggestion(
    name: 'Detergente neutro 500ml',
    category: ShoppingCategory.cleaning,
    suggestedQuantity: 1,
    suggestedUnitPrice: 3.29,
    lastPurchasedAt: DateTime(2026, 9, 15),
    occurrences: 1,
    usageCount: 1,
    source: ReplenishmentSuggestionSource.catalogFallback,
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

  testWidgets(
    'real modal matches editorial reference and preserves selected drafts',
    (tester) async {
      List<ReplenishmentSuggestion>? result;
      await _open(tester, onResult: (value) => result = value);
      expect(find.text('3 de 3 selecionados'), findsOneWidget);
      expect(find.text(formatCurrency(41.97)), findsOneWidget);
      expect(find.text('Ajuda'), findsNothing);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/replenishment_stitch_390.png'),
      );
      await tester.tap(find.byKey(const ValueKey('replenishment_1')));
      await tester.pumpAndSettle();
      expect(find.text('2 de 3 selecionados'), findsOneWidget);
      expect(find.text(formatCurrency(28.19)), findsOneWidget);
      await tester.tap(find.text('Criar lista (2)'));
      await tester.pumpAndSettle();
      expect(result, [_items[0], _items[2]]);
      expect(result!.first.toDraft().barcode, '123');
    },
  );

  testWidgets(
    'select all toggle disables empty confirmation and restores originals',
    (tester) async {
      await _open(tester);
      await tester.tap(find.text('Desmarcar tudo'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 3 selecionados'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Criar lista (0)'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Selecionar tudo'));
      await tester.pumpAndSettle();
      expect(find.text('3 de 3 selecionados'), findsOneWidget);
    },
  );

  testWidgets('empty state remains dismissible without inventing suggestions', (
    tester,
  ) async {
    List<ReplenishmentSuggestion>? result;
    await _open(tester, items: [], onResult: (value) => result = value);
    expect(
      find.text('Nenhuma sugestão de reposição disponível.'),
      findsOneWidget,
    );
    expect(find.text('Selecionar tudo'), findsNothing);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Reposição inteligente'), findsNothing);
  });

  testWidgets('close returns no selected suggestions', (tester) async {
    List<ReplenishmentSuggestion>? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.byTooltip('Fechar reposição'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Reposição inteligente'), findsNothing);
  });

  testWidgets(
    'compact dark enlarged sheet scrolls metadata and keeps actions visible',
    (tester) async {
      await _open(tester, compact: true);
      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(FilledButton, 'Criar lista (3)');
      expect(tester.getRect(button).bottom, lessThanOrEqualTo(568));
      expect(tester.getRect(button).height, greaterThanOrEqualTo(48));
      expect(
        tester.getRect(find.widgetWithText(OutlinedButton, 'Cancelar')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.scrollUntilVisible(
        find.text('Baseado no catálogo'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Baseado no catálogo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Reposição inteligente'), findsNothing);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  List<ReplenishmentSuggestion>? items,
  bool compact = false,
  ValueChanged<List<ReplenishmentSuggestion>?>? onResult,
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
        fontFamily: 'MercadoPublicSans',
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Minhas listas')),
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await showReplenishmentSuggestionsSheet(
                context,
                suggestions: items ?? _items,
              );
              onResult?.call(result);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
