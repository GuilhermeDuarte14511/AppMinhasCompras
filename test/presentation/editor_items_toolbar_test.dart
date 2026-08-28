import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/shopping_list_editor_models.dart';
import 'package:lista_compras_material/src/presentation/shopping_list_editor/widgets/editor_items_toolbar.dart';

void main() {
  testWidgets('item tools start collapsed and can reveal all filters', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ItemsToolsBar(
                controller: controller,
                selectedSort: ItemSortOption.defaultOrder,
                selectedCategory: null,
                visibilityFilter: EditorItemsVisibility.pending,
                marketModeEnabled: false,
                visibleCount: 2,
                totalCount: 3,
                pendingCount: 2,
                purchasedCount: 1,
                hasActiveFilters: false,
                onSortChanged: (_) {},
                onCategoryChanged: (_) {},
                onVisibilityChanged: (_) {},
                onClearFilters: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('items_tools_compact')), findsOneWidget);
    expect(find.text('Pendentes 2'), findsOneWidget);
    expect(find.text('2 de 3 itens'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    final collapsedHeight = tester.getSize(find.byType(ItemsToolsBar)).height;

    await tester.tap(find.byTooltip('Expandir busca e filtros'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Todos 3'), findsOneWidget);
    expect(find.text('Comprados 1'), findsOneWidget);
    expect(find.byTooltip('Recolher busca e filtros'), findsOneWidget);
    final expandedHeight = tester.getSize(find.byType(ItemsToolsBar)).height;
    expect(expandedHeight, greaterThan(collapsedHeight + 100));
  });

  testWidgets('collapsing preserves search text and active filters', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'arroz');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ItemsToolsBar(
                controller: controller,
                selectedSort: ItemSortOption.nameAsc,
                selectedCategory: ShoppingCategory.grocery,
                visibilityFilter: EditorItemsVisibility.all,
                marketModeEnabled: false,
                visibleCount: 1,
                totalCount: 4,
                pendingCount: 3,
                purchasedCount: 1,
                hasActiveFilters: true,
                onSortChanged: (_) {},
                onCategoryChanged: (_) {},
                onVisibilityChanged: (_) {},
                onClearFilters: () {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Todos 4'), findsOneWidget);
    expect(find.text('Busca: arroz'), findsOneWidget);
    expect(controller.text, 'arroz');

    await tester.tap(find.byTooltip('Expandir busca e filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Recolher busca e filtros'));
    await tester.pumpAndSettle();

    expect(find.text('Busca: arroz'), findsOneWidget);
    expect(controller.text, 'arroz');
  });
}
