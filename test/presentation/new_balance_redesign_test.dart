import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/payment_balances_editor_dialog.dart';

const _values = <PaymentBalance>[];
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
  testWidgets('new balance follows Stitch with real editable values', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('balance_entry_name')),
      'VR Alelo',
    );
    await tester.tap(find.byKey(const Key('balance_entry_type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vale refeição (VR)').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('balance_entry_amount')),
      '20000',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.text('Valor inicial para controle de compras'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/new_balance_stitch_390.png'),
    );
  });
  testWidgets(
    'invalid fields keep editor open then save trimmed values and type',
    (tester) async {
      PaymentBalancesEditorResult? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.tap(find.text('Novo saldo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
      await tester.pumpAndSettle();
      expect(find.text('Informe um nome.'), findsOneWidget);
      expect(find.text('Informe um saldo válido.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('balance_entry_name')),
        '  Reserva Pix  ',
      );
      await tester.enterText(
        find.byKey(const Key('balance_entry_amount')),
        '0',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
      await tester.pumpAndSettle();
      expect(find.text('Informe um saldo válido.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('balance_entry_type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pix').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('balance_entry_amount')),
        '12545',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      expect(result!.value!.single.name, 'Reserva Pix');
      expect(result!.value!.single.type, PaymentBalanceType.pix);
      expect(result!.value!.single.amount, 125.45);
      expect(result!.value!.single.financeSourceId, isNull);
    },
  );
  testWidgets('non finite amounts cannot be saved', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('balance_entry_name')),
      'Reserva',
    );
    final amount = tester.widget<TextFormField>(
      find.byKey(const Key('balance_entry_amount')),
    );
    amount.controller!.text = List.filled(400, '9').join();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
    await tester.pumpAndSettle();
    expect(find.text('Informe um saldo válido.'), findsOneWidget);
    expect(find.byKey(const Key('balance_entry_amount')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelled entry never adds a balance', (tester) async {
    PaymentBalancesEditorResult? result;
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('balance_entry_name')),
      'Rascunho',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum saldo configurado ainda.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();
    expect(result!.value, isEmpty);
  });
  testWidgets('all existing payment types remain available', (tester) async {
    await _open(tester);
    await tester.tap(find.text('Novo saldo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('balance_entry_type')));
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButton<PaymentBalanceType>>(
      find.byType(DropdownButton<PaymentBalanceType>),
    );
    expect(
      dropdown.items!.map((item) => item.value),
      PaymentBalanceType.values,
    );
    expect(find.text('Cartão de crédito'), findsWidgets);
    expect(find.text('Voucher'), findsOneWidget);
  });
  testWidgets(
    'linked edits retain source identity and leave originals unchanged',
    (tester) async {
      const original = PaymentBalance(
        id: 'linked',
        name: 'Conta',
        type: PaymentBalanceType.debit,
        amount: 80,
        financeSourceId: 'source',
        financeSourceKind: 'debit',
      );
      PaymentBalancesEditorResult? result;
      await _open(
        tester,
        values: [original],
        onResult: (value) => result = value,
      );
      await tester.tap(find.byTooltip('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('balance_entry_name')),
        'Conta atualizada',
      );
      await tester.enterText(
        find.byKey(const Key('balance_entry_amount')),
        '9000',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
      await tester.pumpAndSettle();
      final value = result!.value!.single;
      expect(value.id, original.id);
      expect(value.financeSourceId, original.financeSourceId);
      expect(value.financeSourceKind, original.financeSourceKind);
      expect(value.amount, 90);
      expect(original.amount, 80);
    },
  );
  testWidgets(
    'compact dark keyboard enlarged text keeps save and cancel usable',
    (tester) async {
      await _open(tester, size: const Size(320, 568), scale: 1.5, dark: true);
      await tester.tap(find.text('Novo saldo'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.widgetWithText(FilledButton, 'Salvar').last;
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(358));
      expect(tester.getSize(save).height, greaterThanOrEqualTo(48));
      await tester.ensureVisible(find.byKey(const Key('balance_entry_amount')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('balance_entry_amount')),
        '20000',
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('balance_entry_amount')), findsNothing);
    },
  );
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
