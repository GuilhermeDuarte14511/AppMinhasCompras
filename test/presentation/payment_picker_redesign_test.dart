import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/payment_source_picker_sheet.dart';
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

  testWidgets('picker editorial reference and source reservation result', (
    tester,
  ) async {
    PaymentSourcePickerResult? result;
    await _open(
      tester,
      _Repository(twoSources: true),
      onResult: (value) => result = value,
    );
    await tester.tap(find.text('Cartão principal'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('finance_source_amount_field')),
      '25000',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 600));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/payment_picker_stitch_390.png'),
    );
    expect(find.textContaining('Limite:'), findsOneWidget);
    expect(find.text('Ajuda'), findsNothing);
    await tester.tap(find.text('Usar nesta lista'));
    await tester.pumpAndSettle();
    expect(result!.balance!.amount, 250);
    expect(result!.balance!.financeSourceId, 'credit');
    expect(result!.balance!.financeSourceKind, 'credit');
  });

  testWidgets('reservation cannot exceed real available amount', (
    tester,
  ) async {
    await _open(tester, _Repository());
    await tester.tap(find.text('Conta corrente'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('finance_source_amount_field')),
      '999999',
    );
    await tester.tap(find.text('Usar nesta lista'));
    await tester.pumpAndSettle();
    expect(
      find.text('O valor da lista não pode superar o disponível neste meio.'),
      findsOneWidget,
    );
    expect(find.text('Adicionar saldo'), findsOneWidget);
  });

  testWidgets(
    'disconnected state preserves manual alternative and cancellation',
    (tester) async {
      PaymentSourcePickerResult? result;
      await _open(
        tester,
        _Repository(connected: false),
        onResult: (value) => result = value,
      );
      expect(
        find.text('Conecte o Minhas Finanças para usar meios sincronizados.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Usar nesta lista'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Adicionar manualmente'));
      await tester.pumpAndSettle();
      expect(result!.addManually, isTrue);
    },
  );

  testWidgets(
    'empty state and absent optional details do not fabricate amounts',
    (tester) async {
      await _open(tester, _Repository(empty: true));
      expect(find.text('Nenhum meio sincronizado ainda.'), findsOneWidget);
      await tester.tap(find.byTooltip('Fechar'));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar saldo'), findsNothing);
    },
  );

  testWidgets('failed source loading can recover with real workspace date', (
    tester,
  ) async {
    final repository = _Repository(failFirst: true);
    await _open(tester, repository);
    expect(find.text('Não foi possível carregar seus meios.'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.loads, 2);
    expect(find.text('Dados de 10/10/2026'), findsOneWidget);
    expect(find.text('Atualizado'), findsNothing);
    expect(find.text('Cartão principal'), findsOneWidget);
  });

  testWidgets(
    'refresh revalidates selected source against new available cents',
    (tester) async {
      final repository = _Repository();
      await _open(tester, repository);
      await tester.tap(find.text('Cartão principal'));
      await tester.pumpAndSettle();
      repository.creditAvailable = 10000;
      await tester.tap(find.byTooltip('Atualizar fontes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar nesta lista'));
      await tester.pumpAndSettle();
      expect(
        find.text('O valor da lista não pode superar o disponível neste meio.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Criar no Finanças'),
            )
            .onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid unlimited amount is rejected without losing manual recovery',
    (tester) async {
      await _open(tester, _Repository());
      await tester.tap(find.text('Cartão principal'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('finance_source_amount_field')),
        '9' * 400,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar nesta lista'));
      await tester.pumpAndSettle();
      expect(find.text('Informe um valor maior que zero.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('compact dark enlarged picker keeps actions above keyboard', (
    tester,
  ) async {
    await _open(tester, _Repository(), compact: true);
    await tester.tap(find.text('Cartão principal'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 210);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester
          .getBottomRight(find.widgetWithText(FilledButton, 'Usar nesta lista'))
          .dy,
      lessThanOrEqualTo(358),
    );
    expect(
      tester
          .getBottomRight(
            find.widgetWithText(OutlinedButton, 'Adicionar manualmente'),
          )
          .dy,
      lessThanOrEqualTo(358),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Adicionar manualmente'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar saldo'), findsNothing);
  });
}

Future<void> _open(
  WidgetTester tester,
  _Repository repository, {
  ValueChanged<PaymentSourcePickerResult?>? onResult,
  bool compact = false,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 884);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: compact ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final value = await showPaymentSourcePickerSheet(
                  context,
                  repository: repository,
                );
                onResult?.call(value);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  // Await even when the caller does not capture the returned result.
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

class _Repository implements FinanceIntegrationRepository {
  _Repository({
    this.connected = true,
    this.empty = false,
    this.failFirst = false,
    this.twoSources = false,
  });
  final bool failFirst;
  final bool twoSources;
  int loads = 0;
  int creditAvailable = 342000;
  final bool connected;
  final bool empty;
  @override
  Future<bool> isConnected() async => connected;
  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    loads++;
    if (failFirst && loads == 1) throw StateError('offline');
    return FinanceWorkspace(
      householdId: 'home',
      householdName: 'Casa',
      cards: const [],
      categories: const [],
      asOf: DateTime(2026, 10, 10),
      paymentSources: empty
          ? const []
          : [
              FinancePaymentSource(
                id: 'credit',
                kind: FinancePaymentSourceKind.credit,
                name: 'Cartão principal',
                availableCents: creditAvailable,
                limitCents: 800000,
                colorHex: '#365943',
              ),
              FinancePaymentSource(
                id: 'debit',
                kind: FinancePaymentSourceKind.debit,
                name: 'Conta corrente',
                availableCents: 185050,
                colorHex: '#365943',
              ),
              if (!twoSources)
                FinancePaymentSource(
                  id: 'va',
                  kind: FinancePaymentSourceKind.foodVoucher,
                  name: 'Vale alimentação',
                  availableCents: 41280,
                  colorHex: '#365943',
                ),
            ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
