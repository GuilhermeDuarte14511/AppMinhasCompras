import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/core/utils/format_utils.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs_and_sheets.dart';

final _lists = [
  _list('semana', 'Compras da semana', 14, 184.30),
  _list('feira', 'Feira de sábado', 8, 64.50),
  _list('despensa', 'Reposição de despensa', 12, 142.80),
  _list('churrasco', 'Churrasco', 16, 215.90),
];

ShoppingListModel _list(String id, String name, int quantity, double total) =>
    ShoppingListModel(
      id: id,
      name: name,
      createdAt: DateTime(2026, 10, 10),
      updatedAt: DateTime(2026, 10, 10),
      items: [
        ShoppingItem(
          id: '$id-item',
          name: 'Produto',
          quantity: quantity,
          unitPrice: total / quantity,
        ),
      ],
    );

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

  testWidgets('editorial sheet shows actual names quantities and values', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Usar lista como modelo'), findsOneWidget);
    expect(find.text('14 itens'), findsOneWidget);
    expect(find.text(formatCurrency(_lists.first.totalValue)), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Compras da semana')).dy,
      lessThan(tester.getTopLeft(find.text('Feira de sábado')).dy),
    );
    expect(
      tester.getSize(find.byTooltip('Fechar')).height,
      greaterThanOrEqualTo(48),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/template_picker_stitch_390.png'),
    );
  });

  testWidgets('selection returns same real list without mutation', (
    tester,
  ) async {
    ShoppingListModel? result;
    final before = _lists.map((list) => list.toJson()).toList();
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Feira de sábado'));
    await tester.pumpAndSettle();
    expect(identical(result, _lists[1]), isTrue);
    expect(_lists.map((list) => list.toJson()).toList(), before);
  });

  testWidgets('close and barrier return null without selecting', (
    tester,
  ) async {
    var results = <ShoppingListModel?>[];
    await _open(tester, onResult: results.add);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(results, [null]);
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, [null, null]);
  });

  testWidgets('empty data conveys unavailability and can be closed', (
    tester,
  ) async {
    await _open(tester, lists: []);
    expect(find.text('Não há listas para usar como modelo.'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(find.text('Usar lista como modelo'), findsNothing);
  });

  testWidgets('compact dark enlarged text scrolls long content and selects', (
    tester,
  ) async {
    final many = List.generate(
      20,
      (index) =>
          _list('$index', 'Lista $index com nome extenso para leitura', 1, 8),
    );
    ShoppingListModel? result;
    await _open(
      tester,
      compact: true,
      lists: many,
      onResult: (value) => result = value,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('1 item'), findsWidgets);
    await tester.scrollUntilVisible(find.text(many.last.name), 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(many.last.name));
    await tester.tap(find.text(many.last.name));
    await tester.pumpAndSettle();
    expect(identical(result, many.last), isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _open(
  WidgetTester tester, {
  List<ShoppingListModel>? lists,
  bool compact = false,
  ValueChanged<ShoppingListModel?>? onResult,
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
                final value = await showTemplatePickerSheet(
                  context,
                  lists: lists ?? _lists,
                );
                onResult?.call(value);
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
