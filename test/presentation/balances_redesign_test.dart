import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/payment_balances_editor_dialog.dart';

const _values = [
  PaymentBalance(
    id: 'a',
    name: 'Vale alimentação',
    type: PaymentBalanceType.foodVoucher,
    amount: 412.80,
  ),
  PaymentBalance(
    id: 'b',
    name: 'Conta corrente',
    type: PaymentBalanceType.debit,
    amount: 1850.50,
  ),
  PaymentBalance(
    id: 'c',
    name: 'Cartão de crédito',
    type: PaymentBalanceType.card,
    amount: 3420,
    financeSourceId: 'source-c',
    financeSourceKind: 'credit',
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
  testWidgets('renders ordered real balances in editorial dialog', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Arraste para ordenar'), findsNothing);
    expect(find.text('1ª prioridade'), findsOneWidget);
    expect(find.text('Vale alimentação'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/balances_stitch_390.png'),
    );
  });
  testWidgets('reorders removes and saves immutable working copy', (
    tester,
  ) async {
    PaymentBalancesEditorResult? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.byTooltip('Mover para baixo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remover').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(result!.value!.map((e) => e.id), ['a', 'c']);
    expect(_values.map((e) => e.id), ['a', 'b', 'c']);
    expect(() => result!.value!.clear(), throwsUnsupportedError);
  });
  testWidgets('cancel and close discard mutations while clear returns clear', (
    tester,
  ) async {
    for (final close in ['Cancelar', 'Fechar', 'Limpar saldos']) {
      PaymentBalancesEditorResult? result;
      var called = false;
      await _open(
        tester,
        onResult: (value) {
          called = true;
          result = value;
        },
      );
      await tester.tap(
        close == 'Fechar' ? find.byTooltip(close) : find.text(close),
      );
      await tester.pumpAndSettle();
      expect(called, true);
      if (close == 'Limpar saldos') {
        expect(result!.clear, true);
      } else {
        expect(result, isNull);
      }
    }
  });
  testWidgets('empty manual add validates and returns actual input', (
    tester,
  ) async {
    PaymentBalancesEditorResult? result;
    await _open(tester, values: [], onResult: (value) => result = value);
    expect(find.text('Nenhum saldo configurado ainda.'), findsOneWidget);
    expect(find.text('Limpar saldos'), findsNothing);
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
    await tester.pumpAndSettle();
    expect(find.text('Informe um nome.'), findsOneWidget);
    expect(find.text('Informe um saldo válido.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '  Reserva  ');
    await tester.enterText(find.byType(TextFormField).last, '12000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(result!.value!.single.name, 'Reserva');
    expect(result!.value!.single.amount, 120);
  });
  testWidgets('editing linked balance preserves financial identity', (
    tester,
  ) async {
    PaymentBalancesEditorResult? result;
    await _open(
      tester,
      values: [_values.last],
      onResult: (value) => result = value,
    );
    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Crédito atualizado',
    );
    await tester.enterText(find.byType(TextFormField).last, '50000');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    final balance = result!.value!.single;
    expect(balance.id, 'c');
    expect(balance.financeSourceId, 'source-c');
    expect(balance.financeSourceKind, 'credit');
    expect(balance.amount, 500);
  });
  testWidgets('compact dark enlarged text keyboard keeps footer reachable', (
    tester,
  ) async {
    await _open(
      tester,
      size: const Size(320, 568),
      scale: 1.5,
      dark: true,
      values: [
        _values.first.copyWith(
          name:
              'Vale alimentação para todas as compras da família e itens da semana',
        ),
      ],
    );
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final button in [
      find.widgetWithText(FilledButton, 'Salvar'),
      find.widgetWithText(OutlinedButton, 'Cancelar'),
    ]) {
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(358));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}

Future<void> _open(
  WidgetTester tester, {
  List<PaymentBalance> values = _values,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  ValueChanged<PaymentBalancesEditorResult?>? onResult,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? ThemeData.dark() : ThemeData.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final result = await showPaymentBalancesEditorDialog(
                context,
                initialValues: values,
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
