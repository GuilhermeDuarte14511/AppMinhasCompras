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

    await _createListFromDashboard(tester, 'Mercado do mês');

    expect(find.text('Mercado do mês'), findsOneWidget);

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
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '950',
    );
    await _tapVisibleButton<FilledButton>(tester, 'Salvar item');

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
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '950',
    );
    await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');
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
      name: 'Feijão',
      quantity: '1',
      unitValueDigits: '1200',
    );
    await _addItem(
      tester,
      name: 'Macarrão',
      quantity: '1',
      unitValueDigits: '800',
    );

    await tester.enterText(find.byType(TextField).first, 'arr');
    await tester.pumpAndSettle();

    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Feijão'), findsNothing);

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

    await _createListFromDashboard(tester, 'Orçamento e histórico');

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
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '3000',
    );
    await _tapVisibleButton<FilledButton>(tester, 'Salvar item');

    await _tapItemActionIcon(
      tester,
      itemName: 'Cafe',
      icon: Icons.query_stats_rounded,
    );

    expect(_textContains('Inicial'), findsWidgets);
  });

  testWidgets('Add item searches every catalog product and applies details', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage(
        _buildCatalogProducts(
          extraProducts: [
            _catalogProduct(
              name: 'Lentilha Premium',
              barcode: '7890000009999',
              unitPrice: 12.34,
              usageCount: 1,
              updatedAt: DateTime(2026),
            ),
          ],
        ),
      ),
    );

    await _createListFromDashboard(tester, 'Catálogo completo');

    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'lent');
    await tester.pumpAndSettle();

    expect(find.text('Lentilha Premium'), findsOneWidget);

    await tester.tap(find.text('Lentilha Premium'));
    await tester.pumpAndSettle();
    await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

    expect(find.text('Lentilha Premium'), findsOneWidget);
    expect(find.text('7890000009999'), findsOneWidget);
    expect(_textContains('12,34'), findsWidgets);
  });

  testWidgets('Item editor shows rich catalog suggestions for partial text', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Tomate Italiano',
          barcode: '7890000001111',
          unitPrice: 10,
        ),
        _catalogProduct(
          name: 'Tomilho',
          barcode: '7890000002222',
          unitPrice: 5,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Compra guiada');
    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'to');
    await tester.pumpAndSettle();

    expect(find.text('Tomate Italiano'), findsOneWidget);
    expect(find.text('Tomilho'), findsOneWidget);
    expect(find.text('7890000001111'), findsOneWidget);
    expect(find.text('7890000002222'), findsOneWidget);
    expect(find.text('Produtos encontrados'), findsOneWidget);
  });

  testWidgets('Item editor ranks rich catalog suggestions and limits to 6', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Tomate Alfa',
          barcode: '7890000001101',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 8),
        ),
        _catalogProduct(
          name: 'Tomate Beta',
          barcode: '7890000001102',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 9),
        ),
        _catalogProduct(
          name: 'Tomate Gama',
          barcode: '7890000001103',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 10),
        ),
        _catalogProduct(
          name: 'Tomate Delta',
          barcode: '7890000001104',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 11),
        ),
        _catalogProduct(
          name: 'Tomate Epsilon',
          barcode: '7890000001105',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 12),
        ),
        _catalogProduct(
          name: 'Tomate Zeta',
          barcode: '7890000001106',
          unitPrice: 2,
          usageCount: 1,
          updatedAt: DateTime(2026, 4, 1, 13),
        ),
        _catalogProduct(
          name: 'Tomate Premium',
          barcode: '7890000001107',
          unitPrice: 2,
          usageCount: 90,
          updatedAt: DateTime(2026, 3, 1),
        ),
        _catalogProduct(
          name: 'Tomate Favorito',
          barcode: '7890000001108',
          unitPrice: 2,
          usageCount: 80,
          updatedAt: DateTime(2026, 2, 1),
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Ranking guiado');
    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'to');
    await tester.pumpAndSettle();

    expect(find.text('Tomate Premium'), findsOneWidget);
    expect(find.text('Tomate Favorito'), findsOneWidget);
    expect(find.text('Tomate Zeta'), findsOneWidget);
    expect(find.text('Tomate Epsilon'), findsOneWidget);
    expect(find.text('Tomate Delta'), findsOneWidget);
    expect(find.text('Tomate Gama'), findsOneWidget);
    expect(find.text('Tomate Beta'), findsNothing);
    expect(find.text('Tomate Alfa'), findsNothing);
    expect(find.text('7890000001107'), findsOneWidget);
    expect(find.text('7890000001108'), findsOneWidget);
  });

  testWidgets('Selecting a catalog suggestion overwrites manual item data', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Molho de Tomate',
          barcode: '7890000003333',
          unitPrice: 10,
          category: ShoppingCategory.cleaning,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Compra inteligente');
    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
      '1111111111111',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '999',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Molho de Tomate'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Item'))
          .controller
          ?.text,
      'Molho de Tomate',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
          )
          .controller
          ?.text,
      '7890000003333',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Valor unitário'),
          )
          .controller
          ?.text,
      'R\$\u00A010,00',
    );
    expect(
      tester
          .widget<DropdownButtonFormField<ShoppingCategory>>(
            find.byType(DropdownButtonFormField<ShoppingCategory>),
          )
          .initialValue,
      ShoppingCategory.cleaning,
    );
  });

  testWidgets(
    'Selecting a catalog suggestion clears stale manual price without saved price',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        catalogStorage: _MemoryProductCatalogStorage([
          CatalogProduct(
            id: uniqueId(),
            name: 'Molho de Tomate',
            category: ShoppingCategory.grocery,
            barcode: '7890000004444',
            unitPrice: null,
            usageCount: 10,
            updatedAt: DateTime(2026, 4, 1),
            priceHistory: const <PriceHistoryEntry>[],
          ),
        ]),
      );

      await _createListFromDashboard(tester, 'Compra sem preco');
      await _openAddItemSheet(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Item'),
        'molho',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor unitário'),
        '999',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Molho de Tomate'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Valor unitário'),
            )
            .controller
            ?.text,
        isEmpty,
      );
    },
  );

  testWidgets('Changing suggested price shows live price insight label', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Molho de Tomate',
          barcode: '7890000003333',
          unitPrice: 10,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Insight de preco');
    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Molho de Tomate'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '850',
    );
    await tester.pumpAndSettle();

    expect(_textContains('menor que o ultimo preco salvo'), findsOneWidget);
  });

  testWidgets('Equal suggested price shows neutral label', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Molho de Tomate',
          barcode: '7890000003333',
          unitPrice: 10,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Insight neutro');
    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Molho de Tomate'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '850',
    );
    await tester.pumpAndSettle();

    expect(_textContains('menor que o ultimo preco salvo'), findsOneWidget);
    expect(_textContains('Mesmo preco da ultima compra'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '1000',
    );
    await tester.pumpAndSettle();

    expect(_textContains('Mesmo preco da ultima compra'), findsOneWidget);
    expect(_textContains('menor que o ultimo preco salvo'), findsNothing);
    expect(_textContains('maior que o ultimo preco salvo'), findsNothing);
  });

  testWidgets(
    'Editing existing catalog-backed item shows live price insight label',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        catalogStorage: _MemoryProductCatalogStorage([
          _catalogProduct(
            name: 'Molho de Tomate',
            barcode: '7890000003333',
            unitPrice: 10,
          ),
        ]),
      );

      await _createListFromDashboard(tester, 'Insight ao editar');
      await _openAddItemSheet(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Molho de Tomate'));
      await tester.pumpAndSettle();
      await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

      await _tapItemActionIcon(
        tester,
        itemName: 'Molho de Tomate',
        icon: Icons.edit_rounded,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor unitário'),
        '850',
      );
      await tester.pumpAndSettle();

      expect(_textContains('menor que o ultimo preco salvo'), findsOneWidget);
    },
  );

  testWidgets(
    'Editing existing manual same-name item does not show live price insight label',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        catalogStorage: _MemoryProductCatalogStorage([
          _catalogProduct(
            name: 'Molho de Tomate',
            barcode: '7890000003333',
            unitPrice: 10,
          ),
        ]),
      );

      await _createListFromDashboard(tester, 'Item manual');
      await _addItem(
        tester,
        name: 'Molho de Tomate',
        quantity: '1',
        unitValueDigits: '1000',
      );

      await _tapItemActionIcon(
        tester,
        itemName: 'Molho de Tomate',
        icon: Icons.edit_rounded,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor unitário'),
        '850',
      );
      await tester.pumpAndSettle();

      expect(_textContains('menor que o ultimo preco salvo'), findsNothing);
      expect(_textContains('Preço sugerido:'), findsNothing);
    },
  );

  testWidgets(
    'Clearing barcode while editing removes live price insight label',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        catalogStorage: _MemoryProductCatalogStorage([
          _catalogProduct(
            name: 'Molho de Tomate',
            barcode: '7890000003333',
            unitPrice: 10,
          ),
        ]),
      );

      await _createListFromDashboard(tester, 'Insight invalido por codigo');
      await _openAddItemSheet(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Molho de Tomate'));
      await tester.pumpAndSettle();
      await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

      await _tapItemActionIcon(
        tester,
        itemName: 'Molho de Tomate',
        icon: Icons.edit_rounded,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor unitário'),
        '850',
      );
      await tester.pumpAndSettle();

      expect(_textContains('menor que o ultimo preco salvo'), findsOneWidget);
      expect(_textContains('Preço sugerido:'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
        '',
      );
      await tester.pumpAndSettle();

      expect(_textContains('menor que o ultimo preco salvo'), findsNothing);
      expect(_textContains('Preço sugerido:'), findsNothing);
    },
  );

  testWidgets(
    'Add and continue keeps rich catalog flow for multiple items',
    (WidgetTester tester) async {
      await _pumpApp(
        tester,
        catalogStorage: _MemoryProductCatalogStorage([
          _catalogProduct(
            name: 'Banana Prata',
            barcode: '7890000001111',
            unitPrice: 6.99,
          ),
          _catalogProduct(
            name: 'Leite Integral',
            barcode: '7890000002222',
            unitPrice: 4.79,
          ),
        ]),
      );

      await _createListFromDashboard(tester, 'Compra guiada em fila');
      await _openAddItemSheet(tester);
      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'ban');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banana Prata'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
            )
            .controller
            ?.text,
        '7890000001111',
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Valor unitário'),
            )
            .controller
            ?.text,
        isNotEmpty,
      );
      expect(_textContains('Preço sugerido:'), findsOneWidget);

      await _tapVisibleButton<OutlinedButton>(tester, 'Adicionar e continuar');

      expect(_textContains('1 item pronto: Banana Prata'), findsOneWidget);
      expect(
        _textContains('Banana Prata adicionado. Continue com o próximo.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Item'))
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Valor unitário'),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(_textContains('Preço sugerido:'), findsNothing);
      expect(find.text('Banana Prata'), findsNothing);

      await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'lei');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leite Integral'));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Código de barras (opcional)'),
            )
            .controller
            ?.text,
        '7890000002222',
      );
      expect(_textContains('Preço sugerido:'), findsOneWidget);

      await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

      expect(find.text('Banana Prata'), findsOneWidget);
      expect(find.text('Leite Integral'), findsOneWidget);
    },
  );

  testWidgets('Manual item still saves without using catalog suggestion', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Cafe Tradicional',
          barcode: '7890000003333',
          unitPrice: 10,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Fluxo manual');
    await _openAddItemSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Cafe',
    );
    await tester.pumpAndSettle();

    expect(find.text('Produtos encontrados'), findsOneWidget);
    expect(find.text('Cafe Tradicional'), findsOneWidget);
    expect(_textContains('Preço sugerido:'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '1234',
    );
    await tester.pumpAndSettle();

    await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

    expect(find.text('Cafe'), findsOneWidget);
    expect(_textContains('2 x'), findsOneWidget);
    expect(_textContains('24,68'), findsWidgets);
  });

  testWidgets('Add item sheet can add multiple catalog products', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Banana Prata',
          barcode: '7890000001111',
          unitPrice: 6.99,
        ),
        _catalogProduct(
          name: 'Leite Integral',
          barcode: '7890000002222',
          unitPrice: 4.79,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Compra da semana');

    await _openAddItemSheet(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'ban');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana Prata'));
    await tester.pumpAndSettle();
    await _tapVisibleButton<OutlinedButton>(tester, 'Adicionar e continuar');
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'lei');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leite Integral'));
    await tester.pumpAndSettle();
    await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');
    await tester.pumpAndSettle();

    expect(find.text('Banana Prata'), findsOneWidget);
    expect(find.text('Leite Integral'), findsOneWidget);
    expect(find.text('7890000001111'), findsOneWidget);
    expect(find.text('7890000002222'), findsOneWidget);
  });

  testWidgets('Catalog lookup feedback clears after name diverges', (
    WidgetTester tester,
  ) async {
    await _pumpApp(
      tester,
      catalogStorage: _MemoryProductCatalogStorage([
        _catalogProduct(
          name: 'Banana Prata',
          barcode: '7890000001111',
          unitPrice: 6.99,
        ),
      ]),
    );

    await _createListFromDashboard(tester, 'Limpeza de feedback');

    await _openAddItemSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Banana Prata',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.manage_search_rounded));
    await tester.pumpAndSettle();

    expect(_textContains('Sugestão local aplicada'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Arroz',
    );
    await tester.pumpAndSettle();

    expect(_textContains('Sugestão local aplicada'), findsNothing);
  });

  testWidgets('Add item sheet can add and continue from keyboard', (
    WidgetTester tester,
  ) async {
    await _pumpApp(tester);

    await _createListFromDashboard(tester, 'Compra rápida');

    await _openAddItemSheet(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Tomate',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '2',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '399',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(_textContains('1 item pronto'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Item'))
          .controller
          ?.text,
      isEmpty,
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Item'),
      'Cebola',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Quantidade'),
      '1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Valor unitário'),
      '250',
    );
    await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

    expect(find.text('Tomate'), findsOneWidget);
    expect(find.text('Cebola'), findsOneWidget);
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

    await tester.tap(find.byType(Checkbox).first, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_textContains('Comprado'), findsWidgets);

    await _openListEditorMenuAction(tester, 'Fechar compra');
    await tester.tap(find.widgetWithText(FilledButton, 'Fechar compra'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas Compras'), findsOneWidget);

    final historyAction = find.byKey(const ValueKey('dash_action_history'));
    await tester.tap(historyAction, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Fechamento mensal'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  ProductCatalogStorage? catalogStorage,
}) async {
  await tester.pumpWidget(
    ShoppingListApp(storage: _MemoryStorage(), catalogStorage: catalogStorage),
  );
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
  await _openAddItemSheet(tester);

  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), name);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Quantidade'),
    quantity,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Valor unitário'),
    unitValueDigits,
  );
  await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');
}

Future<void> _openAddItemSheet(WidgetTester tester) async {
  final addItemFab = find.widgetWithText(
    FloatingActionButton,
    'Adicionar item',
  );
  if (addItemFab.evaluate().isNotEmpty) {
    await tester.tap(addItemFab.first);
  } else {
    await tester.tap(find.byIcon(Icons.add_shopping_cart_rounded).first);
  }
  await tester.pumpAndSettle();
}

Future<void> _tapVisibleButton<T extends ButtonStyleButton>(
  WidgetTester tester,
  String label,
) async {
  final finder = find.widgetWithText(T, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
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

class _MemoryProductCatalogStorage implements ProductCatalogStorage {
  _MemoryProductCatalogStorage([List<CatalogProduct> products = const []])
    : _products = _cloneProducts(products);

  List<CatalogProduct> _products;

  @override
  Future<List<CatalogProduct>> loadProducts() async {
    return _cloneProducts(_products);
  }

  @override
  Future<void> saveProducts(List<CatalogProduct> products) async {
    _products = _cloneProducts(products);
  }

  static List<CatalogProduct> _cloneProducts(List<CatalogProduct> source) {
    return source
        .map(
          (product) => product.copyWith(
            priceHistory: List<PriceHistoryEntry>.from(product.priceHistory),
            updatedAt: product.updatedAt,
          ),
        )
        .toList(growable: false);
  }
}

List<CatalogProduct> _buildCatalogProducts({
  List<CatalogProduct> extraProducts = const [],
}) {
  return [
    for (var index = 0; index < 24; index++)
      _catalogProduct(
        name: 'Produto Recente $index',
        barcode: '789000100${index.toString().padLeft(4, '0')}',
        unitPrice: 2.0 + index,
        usageCount: 50 - index,
        updatedAt: DateTime(2026, 4, 1, 12, index),
      ),
    ...extraProducts,
  ];
}

CatalogProduct _catalogProduct({
  required String name,
  required String barcode,
  required double unitPrice,
  ShoppingCategory category = ShoppingCategory.grocery,
  int usageCount = 10,
  DateTime? updatedAt,
}) {
  final recordedAt = updatedAt ?? DateTime(2026, 4, 1);
  return CatalogProduct(
    id: uniqueId(),
    name: name,
    category: category,
    unitPrice: unitPrice,
    barcode: barcode,
    usageCount: usageCount,
    updatedAt: recordedAt,
    priceHistory: [PriceHistoryEntry(price: unitPrice, recordedAt: recordedAt)],
  );
}
