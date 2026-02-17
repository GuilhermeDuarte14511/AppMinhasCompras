import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/app/shopping_list_app.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';

void main() {
  testWidgets('Initial menu renders expected options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    expect(find.text('Minhas Compras'), findsOneWidget);
    expect(find.text('Começar nova lista de compras'), findsOneWidget);
    expect(find.text('Minhas listas de compras'), findsOneWidget);
    expect(find.text('Histórico mensal'), findsOneWidget);
    expect(find.text('Nova lista baseada em antiga'), findsOneWidget);
  });

  testWidgets('Create list, add item and edit item', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar nova lista de compras'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da lista'),
      'Mercado do mês',
    );
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

    expect(find.text('Mercado do mês'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produto'),
      'Arroz',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitario'),
      '1050',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Adicionar item'));
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.textContaining('Subtotal'), findsOneWidget);

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
    expect(find.textContaining('3 x'), findsOneWidget);
    expect(find.textContaining('28,50'), findsWidgets);
  });

  testWidgets('Prevent duplicate item names in the same list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar nova lista de compras'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da lista'),
      'Sem duplicados',
    );
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

    await _addItem(
      tester,
      name: 'Arroz',
      quantity: '1',
      unitValueDigits: '1000',
    );
    expect(find.text('Arroz'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Produto'),
      'Arroz',
    );
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

    expect(find.text('Esse produto já existe na lista.'), findsOneWidget);
  });

  testWidgets('Search and sort products in list editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar nova lista de compras'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da lista'),
      'Lista de teste',
    );
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

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

    await tester.enterText(find.byType(TextField), 'arr');
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijao'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ordenar itens'));
    await tester.pumpAndSettle();
    await tester.tap(
      find
          .widgetWithText(
            CheckedPopupMenuItem<ItemSortOption>,
            'Valor: maior primeiro',
          )
          .last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Maior valor'), findsOneWidget);

    expect(find.text('Arroz'), findsOneWidget);
  });

  testWidgets('Budget alert and price history are shown', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Começar nova lista de compras'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome da lista'),
      'Orçamento e histórico',
    );
    await tester.tap(find.text('Criar lista'));
    await tester.pumpAndSettle();

    await _openListEditorMenuAction(tester, 'Definir orçamento');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Orçamento da lista'),
      '1000',
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    await _addItem(
      tester,
      name: 'Cafe',
      quantity: '1',
      unitValueDigits: '2500',
    );

    expect(find.textContaining('Excesso'), findsOneWidget);
    expect(find.textContaining('acima do orçamento'), findsOneWidget);

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

    expect(find.text('Histórico de preço'), findsOneWidget);
    expect(find.textContaining('Inicial'), findsOneWidget);
  });

  testWidgets('Delete multiple lists from My Lists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await _createListFromDashboard(tester, 'Lista A');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _createListFromDashboard(tester, 'Lista B');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Minhas listas de compras'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Selecionar várias'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lista A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lista B'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Excluir selecionadas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Lista A'), findsNothing);
    expect(find.text('Lista B'), findsNothing);
    expect(find.text('Você ainda não tem listas'), findsOneWidget);
  });

  testWidgets('Finalize purchase stores entry in monthly history', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(ShoppingListApp(storage: _MemoryStorage()));
    await tester.pumpAndSettle();

    await _createListFromDashboard(tester, 'Fechamento mensal');

    await _addItem(
      tester,
      name: 'Leite',
      quantity: '2',
      unitValueDigits: '750',
    );

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('Comprado'), findsOneWidget);

    await _openListEditorMenuAction(tester, 'Fechar compra');
    await tester.tap(find.widgetWithText(FilledButton, 'Fechar compra'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Compra fechada'), findsOneWidget);
    expect(find.text('Minhas Compras'), findsOneWidget);

    await _pumpUntilFound(tester, find.text('Minhas listas de compras'));
    if (find.text('Minhas listas de compras').evaluate().isNotEmpty) {
      await tester.tap(find.text('Minhas listas de compras'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Histórico mensal'));
      await tester.pumpAndSettle();
    } else if (find.byTooltip('Histórico mensal').evaluate().isNotEmpty) {
      await tester.tap(find.byTooltip('Histórico mensal').first);
      await tester.pumpAndSettle();
    }

    expect(find.text('Histórico mensal'), findsOneWidget);
    expect(find.text('Fechamento mensal'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    if (find.text('Minhas listas de compras').evaluate().isNotEmpty) {
      await tester.tap(find.text('Minhas listas de compras'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('Reabrir lista').first);
    await tester.pumpAndSettle();
    if (find.byType(FloatingActionButton).evaluate().isEmpty) {
      await tester.tap(find.text('Fechamento mensal').first);
      await tester.pumpAndSettle();
    }
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}

Future<void> _addItem(
  WidgetTester tester, {
  required String name,
  required String quantity,
  required String unitValueDigits,
}) async {
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextFormField, 'Produto'), name);
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
  String actionLabel,
) async {
  final byTooltip = find.byTooltip('Ações da lista').hitTestable();
  if (byTooltip.evaluate().isNotEmpty) {
    await tester.tap(byTooltip.first);
  } else {
    final byIcon = find.byIcon(Icons.more_vert_rounded).hitTestable();
    expect(byIcon, findsWidgets);
    await tester.tap(byIcon.first);
  }
  await tester.pumpAndSettle();
  final target = find.text(actionLabel).hitTestable();
  if (target.evaluate().isEmpty) {
    final scrollables = find.byType(Scrollable).evaluate().toList();
    if (scrollables.isNotEmpty) {
      await tester.scrollUntilVisible(
        target,
        140,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
    }
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTries = 30,
}) async {
  for (var i = 0; i < maxTries; i++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _createListFromDashboard(
  WidgetTester tester,
  String listName,
) async {
  await tester.tap(find.text('Começar nova lista de compras'));
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
