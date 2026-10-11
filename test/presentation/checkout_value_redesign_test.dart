import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/purchase_checkout_dialog.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

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

  testWidgets('receipt adjustment uses real totals and editorial reference', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    await tester.ensureVisible(find.text('Alterar valor final'));
    await tester.tap(find.text('Alterar valor final'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Valor final pago'),
      '3500',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ajuste de R\$\u00a02,80'), findsOneWidget);
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/checkout_value_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.widgetWithText(FilledButton, 'Confirmar fechamento'))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Cancelar')).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('cancel and close discard receipt adjustments', (tester) async {
    for (final close in ['Cancelar', 'Fechar conferência']) {
      PurchaseCheckoutResult? result;
      var returned = false;
      await _open(
        tester,
        onResult: (value) {
          result = value;
          returned = true;
        },
      );
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor final pago'),
        '3500',
      );
      await tester.pumpAndSettle();
      await tester.tap(
        close == 'Cancelar' ? find.text(close) : find.byTooltip(close),
      );
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
      expect(find.byType(Dialog), findsNothing);
    }
  });

  testWidgets(
    'empty and zero block adjustment; valid value preserves item prices',
    (tester) async {
      PurchaseCheckoutResult? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      final input = find.widgetWithText(TextField, 'Valor final pago');
      final confirm = find.widgetWithText(FilledButton, 'Confirmar fechamento');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(input, '0');
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(input, '3500');
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(result!.finalTotalCents, 3500);
      expect(result!.reviewedItems.first.unitPrice, 18.9);
      expect(result!.sendToFinance, isFalse);
      expect(result!.financeAllocations, isEmpty);
    },
  );

  testWidgets(
    'disabling adjustment restores calculated total; reenabling retains entered value',
    (tester) async {
      PurchaseCheckoutResult? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Valor final pago'),
        '3500',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'R\$\u00a035,00',
      );
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar fechamento'));
      await tester.pumpAndSettle();
      expect(result!.finalTotalCents, isNull);
    },
  );

  testWidgets(
    'compact dark adjusted checkout supports keyboard and enlarged text',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _open(tester, dark: true, scale: 1.5);
      await tester.ensureVisible(find.text('Alterar valor final'));
      await tester.tap(find.text('Alterar valor final'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Valor final pago');
      await tester.ensureVisible(field);
      await tester.enterText(field, '3780');
      await tester.pumpAndSettle();
      expect(find.text('Valor final igual ao total dos itens'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final footer = find.widgetWithText(FilledButton, 'Confirmar fechamento');
      expect(tester.getBottomRight(footer).dy, lessThanOrEqualTo(388));
      expect(tester.widget<FilledButton>(footer).onPressed, isNotNull);
    },
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester tester, {
  FinanceWorkspace? workspace,
  String? error,
  ValueChanged<PurchaseCheckoutResult?>? onResult,
  bool dark = false,
  double scale = 1,
}) async {
  final theme = editorialWorkspaceTheme(
    dark ? ThemeData.dark() : ThemeData.light(),
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showPurchaseCheckoutDialog(
                  context,
                  list: _list(),
                  financeWorkspace: workspace,
                  financeLoadError: error,
                );
                onResult?.call(result);
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

ShoppingListModel _list() => ShoppingListModel(
  id: 'checkout',
  name: 'Compras da semana',
  createdAt: DateTime(2026, 10, 1),
  updatedAt: DateTime(2026, 10, 10),
  items: const [
    ShoppingItem(
      id: 'coffee',
      name: 'Café especial torrado e moído 250g',
      quantity: 2,
      unitPrice: 18.9,
      isPurchased: true,
    ),
    ShoppingItem(
      id: 'milk',
      name: 'Leite integral',
      quantity: 1,
      unitPrice: 6.9,
      isPurchased: false,
    ),
  ],
);
