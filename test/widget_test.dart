import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  testWidgets('Initial menu renders expected options', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    expect(find.text('Minhas Compras'), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_action_new')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_action_lists')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_action_history')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_action_template')), findsOneWidget);
    expect(find.byKey(const ValueKey('dash_action_based')), findsOneWidget);
  });

  testWidgets('Create list, add item and edit item', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Mercado do mes');

    expect(find.text('Mercado do mes'), findsOneWidget);

    await _addItem(
      tester,
      name: 'Arroz',
      quantity: '2',
      unitValueDigits: '1050',
    );

    expect(find.text('Arroz'), findsOneWidget);
    expect(_textContains('Subtotal'), findsOneWidget);

    await _tapItemActionIcon(
      tester,
      itemName: 'Arroz',
      icon: Icons.edit_rounded,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '3',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitario'),
      '950',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar item'));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(_textContains('3 x'), findsOneWidget);
    expect(_textContains('28,50'), findsWidgets);
  });

  testWidgets('Prevent duplicate item names in the same list', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Sem duplicados');

    await _addItem(
      tester,
      name: 'Arroz',
      quantity: '1',
      unitValueDigits: '1000',
    );
    expect(find.text('Arroz'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'Arroz');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitario'),
      '950',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar item'));
    await tester.pumpAndSettle();

    expect(_textContains('existe na lista'), findsOneWidget);
  });

  testWidgets('Search and sort products in list editor', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Lista de teste');

    await _addItem(
      tester,
      name: 'Arroz',
      quantity: '1',
      unitValueDigits: '3000',
    );
    await _addItem(
      tester,
      name: 'Feijao',
      quantity: '1',
      unitValueDigits: '1200',
    );
    await _addItem(
      tester,
      name: 'Macarrao',
      quantity: '1',
      unitValueDigits: '800',
    );

    await tester.enterText(find.byType(TextField).first, 'arr');
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijao'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ordenar itens'));
    await tester.pumpAndSettle();
    final byDescendingValue = _textContains('maior primeiro').last;
    await tester.tap(byDescendingValue, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(_textContains('Maior valor'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
  });

  testWidgets('Budget alert and price history are shown', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Orcamento e historico');

    await _openListEditorMenuAction(tester, 'Definir or');
    await tester.enterText(find.byType(TextFormField).last, '1000');
    await tester.tap(find.text('Salvar').last);
    await tester.pumpAndSettle();

    await _addItem(
      tester,
      name: 'Cafe',
      quantity: '1',
      unitValueDigits: '2500',
    );

    expect(_textContains('Excesso'), findsOneWidget);
    expect(_textContains('acima do'), findsWidgets);

    await _tapItemActionIcon(
      tester,
      itemName: 'Cafe',
      icon: Icons.edit_rounded,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitario'),
      '3000',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar item'));
    await tester.pumpAndSettle();

    await _tapItemActionIcon(
      tester,
      itemName: 'Cafe',
      icon: Icons.query_stats_rounded,
    );

    expect(_textContains('Inicial'), findsWidgets);
  });

  testWidgets('Delete multiple lists from My Lists', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Lista A');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await _createListFromDashboard(tester, 'Lista B');
    await tester.pageBack();
    await tester.pumpAndSettle();

    final myListsByText = find.text('Minhas listas de compras');
    if (myListsByText.evaluate().isNotEmpty) {
      await tester.tap(myListsByText.first);
    } else {
      await tester.tap(find.byKey(const ValueKey('dash_action_lists')));
    }
    await tester.pumpAndSettle();

    final menuRounded = find.byIcon(Icons.more_vert_rounded);
    final menuDefault = find.byIcon(Icons.more_vert);
    if (menuRounded.evaluate().isNotEmpty) {
      await tester.tap(menuRounded.first);
    } else {
      await tester.tap(menuDefault.first);
    }
    await tester.pumpAndSettle();
    await tester.tap(_textContains('Selecionar v').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lista A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lista B'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir selecionadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();

    expect(find.text('Lista A'), findsNothing);
    expect(find.text('Lista B'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Criar primeira lista'),
      findsOneWidget,
    );
  });

  testWidgets('Finalize purchase stores entry in monthly history', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Fechamento mensal');

    await _addItem(
      tester,
      name: 'Leite',
      quantity: '2',
      unitValueDigits: '750',
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(_textContains('Comprado'), findsWidgets);

    await _openListEditorMenuAction(tester, 'Fechar compra');
    await tester.tap(find.widgetWithText(FilledButton, 'Fechar compra'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas Compras'), findsOneWidget);

    final historyAction = find.byKey(const ValueKey('dash_action_history'));
    await tester.tap(historyAction);
    await tester.pumpAndSettle();

    expect(find.text('Fechamento mensal'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
  await tester.pumpAndSettle();
}

Finder _textContains(String snippet) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data ?? '').contains(snippet),
    description: 'Text containing "$snippet"',
  );
}

Future<void> _addItem(
  WidgetTester tester, {
  required String name,
  required String quantity,
  required String unitValueDigits,
}) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), name);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Quantidade'),
    quantity,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Valor unitario'),
    unitValueDigits,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Adicionar item'));
  await tester.pumpAndSettle();
}

Future<void> _openListEditorMenuAction(
  WidgetTester tester,
  String actionLabelSnippet,
) async {
  await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
  await tester.pumpAndSettle();

  var target = _textContains(actionLabelSnippet).hitTestable();
  if (target.evaluate().isEmpty) {
    final scrollable = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(target, 180, scrollable: scrollable);
    await tester.pumpAndSettle();
    target = _textContains(actionLabelSnippet).hitTestable();
  }

  expect(target, findsWidgets);
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _createListFromDashboard(
  WidgetTester tester,
  String listName,
) async {
  final fabByLabel = find.widgetWithText(FloatingActionButton, 'Nova lista');
  if (fabByLabel.evaluate().isNotEmpty) {
    await tester.tap(fabByLabel.first);
  } else {
    await tester.tap(find.byKey(const ValueKey('dash_action_new')).first);
  }
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome da lista'),
    listName,
  );
  await tester.tap(find.text('Criar lista'));
  await tester.pumpAndSettle();
}

Future<void> _tapItemActionIcon(
  WidgetTester tester, {
  required String itemName,
  required IconData icon,
}) async {
  final itemText = find.text(itemName).first;
  final card = find.ancestor(of: itemText, matching: find.byType(Card)).first;
  final target = find.descendant(of: card, matching: find.byIcon(icon)).first;
  final iconButton = tester.widget<IconButton>(
    find.ancestor(of: target, matching: find.byType(IconButton)).first,
  );
  iconButton.onPressed?.call();
  await tester.pumpAndSettle();
}

class _MemoryStorage implements ShoppingListsStorage {
  List<ShoppingListModel> _lists = const [];

  @override
  Future<List<ShoppingListModel>> loadLists() async {
    return _lists.map((list) => list.deepCopy()).toList(growable: false);
  }

  @override
  Future<void> saveLists(List<ShoppingListModel> lists) async {
    _lists = lists.map((list) => list.deepCopy()).toList(growable: false);
  }
}
