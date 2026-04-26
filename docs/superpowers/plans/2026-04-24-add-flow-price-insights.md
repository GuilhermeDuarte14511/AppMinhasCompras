# Add Flow Price Insights Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the add-item sheet feel catalog-first by showing rich partial-match suggestions, autofilling product data on tap, and displaying a live price-change label while preserving the current project design and multi-add flow.

**Architecture:** Keep the existing modal sheet and store flow intact, but enrich the editor with a richer suggestion source and a UI-only price insight helper. Reuse the current catalog repository as the source of truth and update tests around the existing widget harness instead of introducing a parallel screen or new persistence rules.

**Tech Stack:** Flutter, Dart, Material 3, existing `ShoppingListApp` widget tests, current `CatalogProduct` domain model, `ProductCatalogRepository`, `showAppModalBottomSheet`

---

### Task 1: Add a reusable price insight helper

**Files:**
- Create: `lib/src/presentation/utils/item_price_insight.dart`
- Create: `test/presentation/utils/item_price_insight_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/utils/item_price_insight.dart';

void main() {
  test('buildPriceInsight returns decrease copy', () {
    final insight = buildPriceInsight(
      currentPrice: 8.5,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.down);
    expect(insight.label, contains('menor'));
    expect(insight.label, contains('ultimo preco salvo'));
  });

  test('buildPriceInsight returns increase copy', () {
    final insight = buildPriceInsight(
      currentPrice: 12,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.up);
    expect(insight.label, contains('maior'));
  });

  test('buildPriceInsight returns neutral copy', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 10,
    );

    expect(insight, isNotNull);
    expect(insight!.direction, PriceInsightDirection.same);
    expect(insight.label, 'Mesmo preco da ultima compra');
  });

  test('buildPriceInsight returns null with invalid reference', () {
    final insight = buildPriceInsight(
      currentPrice: 10,
      referencePrice: 0,
    );

    expect(insight, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/utils/item_price_insight_test.dart`
Expected: FAIL with `Target of URI doesn't exist` for `item_price_insight.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
enum PriceInsightDirection { down, same, up }

class ItemPriceInsight {
  const ItemPriceInsight({
    required this.direction,
    required this.percentDelta,
    required this.label,
  });

  final PriceInsightDirection direction;
  final double percentDelta;
  final String label;
}

ItemPriceInsight? buildPriceInsight({
  required double currentPrice,
  required double referencePrice,
}) {
  if (referencePrice <= 0 || currentPrice <= 0) {
    return null;
  }

  final percentDelta = ((currentPrice - referencePrice) / referencePrice) * 100;
  if (percentDelta.abs() < 0.0001) {
    return const ItemPriceInsight(
      direction: PriceInsightDirection.same,
      percentDelta: 0,
      label: 'Mesmo preco da ultima compra',
    );
  }

  final roundedPercent = percentDelta.abs().round();
  if (percentDelta.isNegative) {
    return ItemPriceInsight(
      direction: PriceInsightDirection.down,
      percentDelta: percentDelta,
      label: '$roundedPercent% menor que o ultimo preco salvo',
    );
  }

  return ItemPriceInsight(
    direction: PriceInsightDirection.up,
    percentDelta: percentDelta,
    label: '$roundedPercent% maior que o ultimo preco salvo',
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/presentation/utils/item_price_insight_test.dart`
Expected: PASS with 4 passing tests

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/utils/item_price_insight.dart test/presentation/utils/item_price_insight_test.dart
git commit -m "feat: add item price insight helper"
```

### Task 2: Replace plain string chips with rich catalog suggestions

**Files:**
- Modify: `lib/src/presentation/dialogs_and_sheets.dart`
- Modify: `lib/src/presentation/pages.dart`
- Modify: `lib/src/presentation/shared_lists_pages.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test for partial-match suggestions**

```dart
testWidgets('Item editor shows catalog suggestions for partial text', (
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
  expect(find.text('Produtos encontrados'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "Item editor shows catalog suggestions for partial text"`
Expected: FAIL because the current suggestion UI is still based on plain chips and the richer suggestion structure has not been wired

- [ ] **Step 3: Write minimal implementation**

```dart
Future<ShoppingItemDraft?> showShoppingItemEditorSheet(
  BuildContext context, {
  ShoppingItem? existingItem,
  Set<String> blockedNormalizedNames = const <String>{},
  List<CatalogProduct> catalogProducts = const <CatalogProduct>[],
  Future<ProductLookupResult> Function(String barcode)? onLookupBarcode,
  Future<CatalogProduct?> Function(String name)? onLookupCatalogByName,
  ShoppingItemEditorMode mode = ShoppingItemEditorMode.listItem,
}) {
  return showAppModalBottomSheet<ShoppingItemDraft>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) {
      return _ShoppingItemEditorSheet(
        existingItem: existingItem,
        blockedNormalizedNames: blockedNormalizedNames,
        catalogProducts: catalogProducts,
        onLookupBarcode: onLookupBarcode,
        onLookupCatalogByName: onLookupCatalogByName,
        mode: mode,
        allowMultiple: false,
      );
    },
  );
}

class _ShoppingItemEditorSheet extends StatefulWidget {
  const _ShoppingItemEditorSheet({
    required this.existingItem,
    required this.blockedNormalizedNames,
    required this.catalogProducts,
    required this.onLookupBarcode,
    required this.onLookupCatalogByName,
    required this.mode,
    required this.allowMultiple,
  });

  final ShoppingItem? existingItem;
  final Set<String> blockedNormalizedNames;
  final List<CatalogProduct> catalogProducts;
  final Future<ProductLookupResult> Function(String barcode)? onLookupBarcode;
  final Future<CatalogProduct?> Function(String name)? onLookupCatalogByName;
  final ShoppingItemEditorMode mode;
  final bool allowMultiple;
}

List<CatalogProduct> get _matchingCatalogSuggestions {
  final query = normalizeQuery(_nameController.text);
  final suggestions = <CatalogProduct>[];
  for (final product in widget.catalogProducts) {
    final normalized = normalizeQuery(product.name);
    final shouldInclude = query.isEmpty ? true : normalized.contains(query);
    if (!shouldInclude ||
        normalized == query ||
        _blockedNormalizedNames.contains(normalized)) {
      continue;
    }
    suggestions.add(product);
    if (suggestions.length >= 6) {
      break;
    }
  }
  return suggestions;
}

class _CatalogSuggestionTile extends StatelessWidget {
  const _CatalogSuggestionTile({
    required this.product,
    required this.onTap,
  });

  final CatalogProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.inventory_2_rounded),
      title: Text(product.name),
      subtitle: Text(product.barcode ?? 'Sem codigo'),
      onTap: onTap,
    );
  }
}
```

Update each caller to pass the live catalog instead of only names:

```dart
final draft = await showShoppingItemEditorSheet(
  context,
  blockedNormalizedNames: blockedNames,
  catalogProducts: widget.store.catalogProducts,
  onLookupBarcode: widget.store.lookupProductByBarcode,
  onLookupCatalogByName: widget.store.lookupCatalogProductByName,
);
```

Also update multi-add call sites:

```dart
final drafts = await showShoppingItemsEditorSheet(
  context,
  blockedNormalizedNames: blockedNames,
  catalogProducts: widget.store.catalogProducts,
  onLookupBarcode: widget.store.lookupProductByBarcode,
  onLookupCatalogByName: widget.store.lookupCatalogProductByName,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "Item editor shows catalog suggestions for partial text"`
Expected: PASS and both partial matches appear after typing `to`

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/dialogs_and_sheets.dart lib/src/presentation/pages.dart lib/src/presentation/shared_lists_pages.dart test/widget_test.dart
git commit -m "feat: show rich partial catalog suggestions in item editor"
```

### Task 3: Autofill full product data when a suggestion is selected

**Files:**
- Modify: `lib/src/presentation/dialogs_and_sheets.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test for full autofill**

```dart
testWidgets('Selecting a catalog suggestion autofills item data', (
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

  await _createListFromDashboard(tester, 'Compra inteligente');
  await _openAddItemSheet(tester);
  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
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
  expect(_textContains('10,00'), findsWidgets);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "Selecting a catalog suggestion autofills item data"`
Expected: FAIL because the current autofill keeps the barcode conditional and does not expose a stable rich-selection flow

- [ ] **Step 3: Write minimal implementation**

```dart
void _applyCatalogProduct(CatalogProduct product) {
  _catalogMatch = product;
  final productName = product.name.trim();

  _nameController
    ..text = productName
    ..selection = TextSelection.collapsed(offset: productName.length);

  _selectedCategory = product.category;

  final barcode = product.barcode;
  _barcodeController
    ..text = barcode ?? ''
    ..selection = TextSelection.collapsed(offset: (barcode ?? '').length);

  final price = product.unitPrice;
  if (price != null && price > 0) {
    _priceController.text = _currencyFormatter.formatValue(price);
  }
}
```

Render richer suggestion rows inside the existing sheet:

```dart
if (_matchingCatalogSuggestions.isNotEmpty) ...[
  const SizedBox(height: 10),
  Text(
    'Produtos encontrados',
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  ),
  const SizedBox(height: 6),
  Column(
    children: [
      for (final product in _matchingCatalogSuggestions)
        _CatalogSuggestionTile(
          product: product,
          onTap: () => _applyCatalogProduct(product),
        ),
    ],
  ),
],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "Selecting a catalog suggestion autofills item data"`
Expected: PASS and the item, barcode, and suggested value fields are populated from the catalog

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/dialogs_and_sheets.dart test/widget_test.dart
git commit -m "feat: autofill item editor from selected catalog suggestion"
```

### Task 4: Add activation copy and live price-change label

**Files:**
- Modify: `lib/src/presentation/dialogs_and_sheets.dart`
- Modify: `lib/src/presentation/utils/item_price_insight.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test for live price insight**

```dart
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
    find.widgetWithText(TextFormField, 'Valor unitario'),
    '850',
  );
  await tester.pumpAndSettle();

  expect(_textContains('menor que o ultimo preco salvo'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "Changing suggested price shows live price insight label"`
Expected: FAIL because the current sheet only shows the static catalog hint and does not react to price edits

- [ ] **Step 3: Write minimal implementation**

Add activation copy near the sheet header:

```dart
Text(
  'Digite parte do nome para buscar no catálogo, toque numa sugestão e ajuste o valor para comparar o preço na hora.',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
),
```

Add UI-only state:

```dart
ItemPriceInsight? get _currentPriceInsight {
  final product = _catalogMatch;
  final currentPrice = BrlCurrencyInputFormatter.tryParse(_priceController.text);
  final referencePrice = product?.unitPrice;
  if (product == null || currentPrice == null || referencePrice == null) {
    return null;
  }
  return buildPriceInsight(
    currentPrice: currentPrice,
    referencePrice: referencePrice,
  );
}
```

Render the live label under the price field:

```dart
final priceInsight = _currentPriceInsight;
if (priceInsight != null) ...[
  const SizedBox(height: 10),
  _ItemPriceInsightBanner(insight: priceInsight),
]
```

Add the banner widget in the same file:

```dart
class _ItemPriceInsightBanner extends StatelessWidget {
  const _ItemPriceInsightBanner({required this.insight});

  final ItemPriceInsight insight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = switch (insight.direction) {
      PriceInsightDirection.down => colorScheme.primaryContainer,
      PriceInsightDirection.same => colorScheme.surfaceContainerHighest,
      PriceInsightDirection.up => colorScheme.errorContainer,
    };

    final foregroundColor = switch (insight.direction) {
      PriceInsightDirection.down => colorScheme.onPrimaryContainer,
      PriceInsightDirection.same => colorScheme.onSurfaceVariant,
      PriceInsightDirection.up => colorScheme.onErrorContainer,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          insight.label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
```

Invalidate the selected product when the edited name no longer matches the selected catalog item:

```dart
void _handleNameChanged() {
  final currentName = normalizeQuery(_nameController.text);
  final catalogName = _catalogMatch == null
      ? ''
      : normalizeQuery(_catalogMatch!.name);
  if (_catalogMatch != null && currentName != catalogName) {
    _catalogMatch = null;
  }
  if (mounted) {
    setState(() {});
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/widget_test.dart --plain-name "Changing suggested price shows live price insight label"`
Expected: PASS and the sheet shows the live comparison label after editing the suggested price

- [ ] **Step 5: Commit**

```bash
git add lib/src/presentation/dialogs_and_sheets.dart lib/src/presentation/utils/item_price_insight.dart test/widget_test.dart
git commit -m "feat: add live item price insight in editor"
```

### Task 5: Verify multi-add flow and regression coverage

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write the failing widget test for multi-add with catalog suggestions**

```dart
testWidgets('Add and continue keeps rich catalog flow for multiple items', (
  WidgetTester tester,
) async {
  await _pumpApp(
    tester,
    catalogStorage: _MemoryProductCatalogStorage([
      _catalogProduct(
        name: 'Tomate',
        barcode: '7890000004444',
        unitPrice: 10,
      ),
      _catalogProduct(
        name: 'Tomilho',
        barcode: '7890000005555',
        unitPrice: 6,
      ),
    ]),
  );

  await _createListFromDashboard(tester, 'Compra rapida');
  await _openAddItemSheet(tester);

  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'tom');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tomate'));
  await tester.pumpAndSettle();
  await _tapVisibleButton<OutlinedButton>(tester, 'Adicionar e continuar');

  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'tomi');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Tomilho'));
  await tester.pumpAndSettle();
  await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

  expect(find.text('Tomate'), findsOneWidget);
  expect(find.text('Tomilho'), findsOneWidget);
  expect(find.text('7890000004444'), findsOneWidget);
  expect(find.text('7890000005555'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart --plain-name "Add and continue keeps rich catalog flow for multiple items"`
Expected: FAIL until the suggestion selection, queue reset, and pending draft flow all work together

- [ ] **Step 3: Write minimal implementation**

Keep the queue reset logic, but ensure it clears the selected catalog state and preserves activation copy:

```dart
void _resetFormAfterQueuedDraft(String productName) {
  _formKey.currentState?.reset();
  _nameController.clear();
  _barcodeController.clear();
  _quantityController.text = '1';
  _priceController.clear();
  setState(() {
    _selectedCategory = ShoppingCategory.grocery;
    _catalogMatch = null;
    _lookupFeedback = '$productName adicionado. Continue com o proximo.';
  });
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) {
      _nameFocusNode.requestFocus();
    }
  });
}
```

Add two focused regression tests in the same file:

```dart
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

  await _createListFromDashboard(tester, 'Preco estavel');
  await _openAddItemSheet(tester);
  await tester.enterText(find.widgetWithText(TextFormField, 'Item'), 'molho');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Molho de Tomate'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Valor unitário'),
    '1000',
  );
  await tester.pumpAndSettle();

  expect(find.text('Mesmo preco da ultima compra'), findsOneWidget);
});

testWidgets('Manual item still saves without using catalog suggestion', (
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

  await _createListFromDashboard(tester, 'Fluxo manual');
  await _openAddItemSheet(tester);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Item'),
    'Cebola Roxa',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Quantidade'),
    '2',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Valor unitário'),
    '799',
  );
  await _tapVisibleButton<FilledButton>(tester, 'Adicionar item');

  expect(find.text('Cebola Roxa'), findsOneWidget);
});
```

- [ ] **Step 4: Run the focused and broad test suite**

Run: `flutter test test/widget_test.dart`
Expected: PASS including the new rich-suggestion, autofill, live-insight, and multi-add scenarios

Then run:

Run: `flutter analyze`
Expected: PASS with no new analyzer errors

- [ ] **Step 5: Commit**

```bash
git add test/widget_test.dart
git commit -m "test: cover rich add-item flow and price insight"
```
