import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/shopping_list_editor_models.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/editor_items_toolbar.dart';

void main() {
  testWidgets(
    'search and all filters are directly available with real counts',
    (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var visibility = EditorItemsVisibility.pending;
      ShoppingCategory? category;
      var sort = ItemSortOption.defaultOrder;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ItemsToolsBar(
                controller: controller,
                selectedSort: sort,
                selectedCategory: category,
                visibilityFilter: visibility,
                marketModeEnabled: false,
                visibleCount: 2,
                totalCount: 3,
                pendingCount: 2,
                purchasedCount: 1,
                hasActiveFilters: false,
                onSortChanged: (value) => setState(() => sort = value),
                onCategoryChanged: (value) => setState(() => category = value),
                onVisibilityChanged: (value) =>
                    setState(() => visibility = value),
                onClearFilters: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Pendentes (2)'), findsOneWidget);
      expect(find.text('Todos (3)'), findsOneWidget);
      expect(find.text('Comprados (1)'), findsOneWidget);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('editor_filter_pending')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.text('Todos (3)'));
      await tester.pumpAndSettle();
      expect(visibility, EditorItemsVisibility.all);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('editor_filter_all')))
            .selected,
        isTrue,
      );

      await tester.tap(find.byTooltip('Filtrar categoria'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(ShoppingCategory.grocery.label),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text(ShoppingCategory.grocery.label),
              matching: find.byWidgetPredicate(
                (widget) => widget is CheckedPopupMenuItem,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(category, ShoppingCategory.grocery);
      expect(find.text(ShoppingCategory.grocery.label), findsOneWidget);

      await tester.tap(find.byTooltip('Ordenar itens'));
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .ancestor(
              of: find.text(ItemSortOption.nameAsc.label),
              matching: find.byWidgetPredicate(
                (widget) => widget is CheckedPopupMenuItem,
              ),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(sort, ItemSortOption.nameAsc);
      expect(find.text(ItemSortOption.nameAsc.shortLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'search and active filters remain visible and clear independently',
    (tester) async {
      final controller = TextEditingController(text: 'arroz');
      addTearDown(controller.dispose);
      var clearCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItemsToolsBar(
              controller: controller,
              selectedSort: ItemSortOption.nameAsc,
              selectedCategory: ShoppingCategory.grocery,
              visibilityFilter: EditorItemsVisibility.all,
              marketModeEnabled: true,
              visibleCount: 1,
              totalCount: 4,
              pendingCount: 3,
              purchasedCount: 1,
              hasActiveFilters: true,
              onSortChanged: (_) {},
              onCategoryChanged: (_) {},
              onVisibilityChanged: (_) {},
              onClearFilters: () => clearCount++,
            ),
          ),
        ),
      );

      expect(find.text('Todos (4)'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'arroz',
      );
      expect(find.text(ShoppingCategory.grocery.label), findsOneWidget);
      expect(find.text(ItemSortOption.nameAsc.shortLabel), findsOneWidget);
      expect(find.text('Ordenação de mercado ativa'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'feijão');
      await tester.pump();
      expect(controller.text, 'feijão');
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(find.byTooltip('Limpar busca'), findsNothing);
      expect(find.text(ShoppingCategory.grocery.label), findsOneWidget);
      await tester.tap(find.text('Limpar filtros'));
      await tester.pump();
      expect(clearCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
