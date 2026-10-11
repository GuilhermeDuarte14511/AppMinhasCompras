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

  testWidgets('financial section follows Stitch with real available amount', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await _open(tester);
    await _visible(tester, 'checkout_finance_category');
    expect(_available(tester), 'Disponível: R\$ 500,00');
    expect(find.textContaining('Dinheiro'), findsNothing);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('checkout_send_to_finance')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('checkout_payment_source')))
            .dy,
      ),
    );
    await expectLater(
      find.byType(Dialog),
      matchesGoldenFile('goldens/checkout_finance_redesign_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selects real benefit and category and returns exact allocation',
    (tester) async {
      PurchaseCheckoutResult? result;
      await _open(tester, onResult: (value) => result = value);
      await _visible(tester, 'checkout_payment_source');
      await tester.tap(find.byKey(const ValueKey('checkout_payment_source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VR Alelo (VR)').last);
      await tester.pumpAndSettle();
      expect(_available(tester), 'Disponível: R\$ 250,00');
      expect(find.textContaining('VA e VR atualizam apenas'), findsOneWidget);
      await _visible(tester, 'checkout_finance_category');
      await tester.tap(find.byKey(const ValueKey('checkout_finance_category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casa').last);
      await tester.pumpAndSettle();
      await _confirm(tester);
      expect(result?.financePaymentSourceId, 'vr');
      expect(result?.financePaymentSourceKind, 'mealVoucher');
      expect(result?.financeCategoryId, 'home');
      expect(result?.financeAllocations.single.amountCents, 2000);
    },
  );

  testWidgets(
    'insufficient funds block finance but consent off permits local closing',
    (tester) async {
      PurchaseCheckoutResult? result;
      await _open(
        tester,
        sources: [
          _source('poor', FinancePaymentSourceKind.debit, 'Saldo pequeno', 100),
        ],
        onResult: (value) => result = value,
      );
      await _visible(tester, 'checkout_payment_source');
      expect(
        find.text('O valor disponível não cobre esta compra.'),
        findsOneWidget,
      );
      expect(_confirmButton(tester).onPressed, isNull);
      await _visible(tester, 'checkout_send_to_finance');
      await tester.tap(find.byKey(const ValueKey('checkout_send_to_finance')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('checkout_payment_source')),
        findsNothing,
      );
      expect(
        find.text('Nenhum lançamento será enviado ao Minhas Finanças.'),
        findsOneWidget,
      );
      await _confirm(tester);
      expect(result?.sendToFinance, isFalse);
      expect(result?.financeAllocations, isEmpty);
      expect(result?.financeCategoryId, isNull);
    },
  );

  testWidgets('split amounts flow through actual checkout and mixed impact', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    await _open(tester, onResult: (value) => result = value);
    await _visible(tester, 'checkout_split_payment');
    await tester.tap(find.byKey(const ValueKey('checkout_split_payment')));
    await tester.pumpAndSettle();
    await _visible(tester, 'split-amount-0');
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-0')),
      '1000',
    );
    await tester.pumpAndSettle();
    expect(_confirmButton(tester).onPressed, isNull);
    await tester.ensureVisible(find.text('Adicionar pagamento'));
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A parte em crédito ou débito'), findsOneWidget);
    await _confirm(tester);
    expect(result?.financeAllocations.map((value) => value.amountCents), [
      1000,
      1000,
    ]);
    expect(result?.financeAllocations.map((value) => value.sourceId), [
      'debit',
      'vr',
    ]);
  });

  testWidgets(
    'empty workspace explains local closure without fabricated sources',
    (tester) async {
      PurchaseCheckoutResult? result;
      await _open(tester, sources: [], onResult: (value) => result = value);
      expect(
        find.textContaining('Nenhum meio de pagamento disponível.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('checkout_payment_source')),
        findsNothing,
      );
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('checkout_send_to_finance')),
            )
            .onChanged,
        isNull,
      );
      await _confirm(tester);
      expect(result?.sendToFinance, isFalse);
    },
  );

  testWidgets('load failure stays actionable for local closing', (
    tester,
  ) async {
    PurchaseCheckoutResult? result;
    await _open(tester, unavailable: true, onResult: (value) => result = value);
    expect(
      find.textContaining(
        'Falha ao carregar. A compra ainda pode ser fechada.',
      ),
      findsOneWidget,
    );
    await _confirm(tester);
    expect(result?.sendToFinance, isFalse);
  });

  testWidgets(
    'compact dark finance remains operable with large text and keyboard',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _open(tester, dark: true, scale: 1.5);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await _visible(tester, 'checkout_payment_source');
      await expectLater(
        find.byType(Dialog),
        matchesGoldenFile('goldens/checkout_finance_redesign_dark_320.png'),
      );
      await tester.tap(find.byKey(const ValueKey('checkout_payment_source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('VR Alelo (VR)').last);
      await tester.pumpAndSettle();
      await _visible(tester, 'checkout_send_to_finance');
      await tester.tap(find.byKey(const ValueKey('checkout_send_to_finance')));
      await tester.pumpAndSettle();
      expect(
        tester
            .getBottomRight(
              find.widgetWithText(FilledButton, 'Confirmar fechamento'),
            )
            .dy,
        lessThanOrEqualTo(388),
      );
      expect(
        tester
            .getSize(find.widgetWithText(FilledButton, 'Confirmar fechamento'))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

FilledButton _confirmButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
String _available(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const ValueKey('checkout_source_available')))
    .data!
    .replaceAll('\u00a0', ' ');
Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Confirmar fechamento'));
  await tester.pumpAndSettle();
}

Future<void> _visible(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

FinancePaymentSource _source(
  String id,
  FinancePaymentSourceKind kind,
  String name,
  int amount,
) => FinancePaymentSource(
  id: id,
  kind: kind,
  name: name,
  availableCents: amount,
  colorHex: '#1F412D',
);
Future<void> _open(
  WidgetTester tester, {
  List<FinancePaymentSource>? sources,
  bool unavailable = false,
  bool dark = false,
  double scale = 1,
  ValueChanged<PurchaseCheckoutResult?>? onResult,
}) async {
  final workspace = FinanceWorkspace(
    householdId: 'home',
    householdName: 'Casa',
    cards: const [],
    paymentSources:
        sources ??
        [
          _source(
            'debit',
            FinancePaymentSourceKind.debit,
            'Conta da casa',
            50000,
          ),
          _source(
            'vr',
            FinancePaymentSourceKind.mealVoucher,
            'VR Alelo',
            25000,
          ),
        ],
    categories: const [
      FinanceCategory(
        id: 'food',
        name: 'Alimentação',
        iconKey: 'shopping_cart',
        colorHex: '#1F412D',
      ),
      FinanceCategory(
        id: 'home',
        name: 'Casa',
        iconKey: 'home',
        colorHex: '#1F412D',
      ),
    ],
    asOf: DateTime(2026, 10, 10),
  );
  final list = ShoppingListModel(
    id: 'list',
    name: 'Compras da semana',
    createdAt: DateTime(2026, 10, 10),
    updatedAt: DateTime(2026, 10, 10),
    items: const [
      ShoppingItem(
        id: 'coffee',
        name: 'Café especial',
        quantity: 2,
        unitPrice: 10,
        isPurchased: true,
      ),
    ],
  );
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        dark ? ThemeData.dark() : ThemeData.light(),
      ),
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
                  list: list,
                  financeWorkspace: unavailable ? null : workspace,
                  financeLoadError: unavailable ? 'Falha ao carregar.' : null,
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
