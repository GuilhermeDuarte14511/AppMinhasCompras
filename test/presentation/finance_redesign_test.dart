import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/finance_integration_page.dart';

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

  testWidgets('finance connected editorial reference retains invoice detail', (
    tester,
  ) async {
    await _open(tester, _Repository());
    await expectLater(
      find.byType(FinanceIntegrationPage),
      matchesGoldenFile('goldens/finance_stitch_390.png'),
    );
    expect(find.text('Casa'), findsOneWidget);
    expect(find.text('Fecha dia 20 • vence dia 27'), findsOneWidget);
    expect(find.textContaining('Fatura atual:'), findsOneWidget);
    expect(find.textContaining('Limite:'), findsOneWidget);
    expect(find.text('VA'), findsOneWidget);
    expect(find.text('VR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnected reference and code validation preserve pairing', (
    tester,
  ) async {
    final repo = _Repository(connected: false);
    await _open(tester, repo);
    await expectLater(
      find.byType(FinanceIntegrationPage),
      matchesGoldenFile('goldens/finance_connect_stitch_390.png'),
    );
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABC',
    );
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o código de 12 caracteres.'), findsOneWidget);
    expect(repo.receivedCode, isNull);
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABCD-EFGH-IJKL',
    );
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(repo.receivedCode, 'ABCD-EFGH-IJKL');
    expect(find.text('Aplicativos conectados com segurança.'), findsOneWidget);
    expect(find.text('Casa'), findsOneWidget);
  });

  testWidgets(
    'optional credit details are omitted when remote data is absent',
    (tester) async {
      final repo = _Repository();
      repo.workspace = FinanceWorkspace(
        householdId: 'household',
        householdName: 'Casa',
        cards: const [],
        categories: const [],
        asOf: DateTime(2026, 10, 10),
        paymentSources: const [
          FinancePaymentSource(
            id: 'credit',
            kind: FinancePaymentSourceKind.credit,
            name: 'Cartão sem detalhes',
            availableCents: 12345,
            colorHex: '#234431',
          ),
        ],
      );
      await _open(tester, repo);
      expect(find.textContaining('123,45'), findsOneWidget);
      expect(find.textContaining('Limite:'), findsNothing);
      expect(find.textContaining('Fatura atual:'), findsNothing);
      expect(find.textContaining('Fecha dia'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'pending retries, refresh and local disconnect call real interfaces',
    (tester) async {
      final repo = _Repository(pending: 2);
      await _open(tester, repo);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(repo.pending, 0);
      expect(find.text('2 lançamentos sincronizados.'), findsOneWidget);
      await _tap(tester, 'Atualizar meios');
      expect(repo.loads, 3);
      await _tap(tester, 'Desconectar deste aparelho');
      expect(repo.connected, isFalse);
      expect(find.text('Conexão removida deste dispositivo.'), findsOneWidget);
      expect(find.text('Conectar'), findsOneWidget);
    },
  );

  testWidgets(
    'load error is visible and refresh recovers without fake sync claim',
    (tester) async {
      final repo = _Repository()..failLoad = true;
      await _open(tester, repo);
      expect(
        find.text('Finanças indisponível. Tente novamente.'),
        findsOneWidget,
      );
      expect(find.text('0 disponíveis'), findsNothing);
      expect(
        find.textContaining('Meios indisponíveis no momento.'),
        findsOneWidget,
      );
      repo.failLoad = false;
      await _tap(tester, 'Atualizar meios');
      expect(find.text('Casa'), findsOneWidget);
      expect(
        find.text('Finanças indisponível. Tente novamente.'),
        findsNothing,
      );
      expect(find.text('3 disponíveis'), findsOneWidget);
    },
  );

  testWidgets('new payment source opens existing form under editorial theme', (
    tester,
  ) async {
    await _open(tester, _Repository());
    await _tap(tester, 'Novo meio no Finanças');
    expect(find.text('Novo meio de pagamento'), findsOneWidget);
    expect(find.byKey(const Key('payment_source_name_field')), findsOneWidget);
    final fieldContext = tester.element(
      find.byKey(const Key('payment_source_name_field')),
    );
    expect(
      Theme.of(fieldContext).textTheme.bodySmall?.fontFamily,
      'MercadoPublicSans',
    );
    await tester.tap(find.text('Débito'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('payment_source_name_field')),
      'Conta nova',
    );
    await tester.enterText(
      find.byKey(const Key('payment_source_amount_field')),
      '50000',
    );
    await tester.ensureVisible(find.text('Criar e usar'));
    await tester.tap(find.text('Criar e usar'));
    await tester.pumpAndSettle();
    expect(find.text('Débito criado no Minhas Finanças.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact dark enlarged text keeps actions reachable', (
    tester,
  ) async {
    await _open(
      tester,
      _Repository(),
      size: const Size(320, 568),
      dark: true,
      scale: 1.5,
    );
    await _tap(tester, 'Atualizar meios');
    await tester.scrollUntilVisible(
      find.text('Desconectar deste aparelho'),
      200,
    );
    expect(
      find.text('Desconectar deste aparelho').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('pairing with keyboard and enlarged text remains scrollable', (
    tester,
  ) async {
    await _open(
      tester,
      _Repository(connected: false),
      size: const Size(320, 568),
      dark: true,
      scale: 1.5,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('finance_connection_code')),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('finance_connection_code')));
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABCD-EFGH-IJKL',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Casa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  expect(find.text(text).hitTestable(), findsOneWidget);
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  _Repository repo, {
  Size size = const Size(390, 884),
  bool dark = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FinanceIntegrationPage(repository: repo),
              ),
            ),
            child: const Text('Abrir finanças'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir finanças'));
  await tester.pumpAndSettle();
}

class _Repository implements FinanceIntegrationRepository {
  _Repository({this.connected = true, this.pending = 0});
  bool connected;
  int pending;
  int loads = 0;
  bool failLoad = false;
  String? receivedCode;
  FinanceWorkspace workspace = FinanceWorkspace(
    householdId: 'household',
    householdName: 'Casa',
    cards: const [],
    categories: const [],
    asOf: DateTime(2026, 10, 10),
    paymentSources: const [
      FinancePaymentSource(
        id: 'credit',
        kind: FinancePaymentSourceKind.credit,
        name: 'Cartão principal',
        availableCents: 342000,
        colorHex: '#234431',
        lastDigits: '1234',
        limitCents: 800000,
        usedCents: 458000,
        closingDay: 20,
        dueDay: 27,
      ),
      FinancePaymentSource(
        id: 'va',
        kind: FinancePaymentSourceKind.foodVoucher,
        name: 'Alimentação',
        availableCents: 41280,
        colorHex: '#234431',
      ),
      FinancePaymentSource(
        id: 'vr',
        kind: FinancePaymentSourceKind.mealVoucher,
        name: 'Refeição',
        availableCents: 185050,
        colorHex: '#234431',
      ),
    ],
  );
  @override
  Future<bool> isConnected() async => connected;
  @override
  Future<FinanceWorkspace> loadWorkspace() async {
    loads++;
    if (failLoad) {
      throw const FinanceIntegrationException(
        'Finanças indisponível. Tente novamente.',
        retryable: true,
      );
    }
    return workspace;
  }

  @override
  Future<int> pendingPurchaseCount() async => pending;
  @override
  Future<int> retryPendingPurchases() async {
    final count = pending;
    pending = 0;
    return count;
  }

  @override
  Future<void> disconnect() async {
    connected = false;
  }

  @override
  Future<FinanceIntegrationConnection> connect(String code) async {
    receivedCode = code;
    connected = true;
    return const FinanceIntegrationConnection(
      id: 'integration',
      householdId: 'household',
      householdName: 'Casa',
      ownerName: 'Gui',
      permissions: [],
    );
  }

  @override
  Future<FinancePaymentSource> createPaymentSource(
    FinancePaymentSourceRequest request,
  ) async => FinancePaymentSource(
    id: 'created',
    kind: request.kind,
    name: request.name,
    availableCents: request.availableCents,
    colorHex: request.colorHex,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
