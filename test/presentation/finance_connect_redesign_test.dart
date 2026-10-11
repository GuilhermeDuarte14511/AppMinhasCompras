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
  testWidgets('screen 51 matches pairing form with no fabricated workspace', (
    tester,
  ) async {
    await _open(tester, _Repository(connected: false));
    await expectLater(
      find.byType(FinanceIntegrationPage),
      matchesGoldenFile('goldens/finance_connect_51_stitch_390.png'),
    );
    expect(find.text('Integração externa'), findsNothing);
    expect(find.text('Casa'), findsNothing);
    expect(find.text('CÓDIGO DE CONEXÃO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'pasted lowercase unformatted code normalizes and connects once',
    (tester) async {
      final repo = _Repository(connected: false);
      await _open(tester, repo);
      final field = find.byKey(const Key('finance_connection_code'));
      await tester.enterText(field, 'abcd efgh ijkl');
      expect(
        tester.widget<TextField>(field).controller!.text,
        'ABCD-EFGH-IJKL',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(repo.receivedCode, 'ABCD-EFGH-IJKL');
      expect(find.text('Conectado'), findsOneWidget);
    },
  );
  testWidgets('caret remains between groups when editing code in the middle', (
    tester,
  ) async {
    await _open(tester, _Repository(connected: false));
    final field = find.byKey(const Key('finance_connection_code'));
    await tester.tap(field);
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'abcdEFGHijkl',
        selection: TextSelection.collapsed(offset: 6),
      ),
    );
    await tester.pump();
    final value = tester.widget<TextField>(field).controller!.value;
    expect(value.text, 'ABCD-EFGH-IJKL');
    expect(value.selection.extentOffset, 7);
  });
  testWidgets('expired code preserves input and enables corrected retry', (
    tester,
  ) async {
    final repo = _Repository(connected: false)..failConnect = true;
    await _open(tester, repo);
    final field = find.byKey(const Key('finance_connection_code'));
    await tester.enterText(field, 'ABCDEFGHIJKL');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.text('Código expirado. Gere outro código.'), findsOneWidget);
    expect(tester.widget<TextField>(field).controller!.text, 'ABCD-EFGH-IJKL');
    repo.failConnect = false;
    await _tap(tester, 'Conectar');
    expect(find.text('Conectado'), findsOneWidget);
  });
  testWidgets(
    'credentials saved before workspace failure retain connected retry',
    (tester) async {
      final repo = _Repository(connected: false)..failLoad = true;
      await _open(tester, repo);
      await tester.enterText(
        find.byKey(const Key('finance_connection_code')),
        'ABCDEFGHIJKL',
      );
      await tester.tap(find.text('Conectar'));
      await tester.pumpAndSettle();
      expect(repo.connected, isTrue);
      expect(find.text('Conectar'), findsNothing);
      expect(find.text('Conectado'), findsOneWidget);
      expect(
        find.text('Finanças indisponível. Tente novamente.'),
        findsOneWidget,
      );
      repo.failLoad = false;
      await _tap(tester, 'Atualizar meios');
      expect(find.text('Casa'), findsOneWidget);
    },
  );
  testWidgets(
    'unexpected disconnect failure keeps controls available for retry',
    (tester) async {
      final repo = _Repository()..failDisconnect = true;
      await _open(tester, repo);
      await _tap(tester, 'Desconectar deste aparelho');
      expect(
        find.text('Não foi possível desconectar. Tente novamente.'),
        findsOneWidget,
      );
      expect(repo.connected, isTrue);
      repo.failDisconnect = false;
      await _tap(tester, 'Desconectar deste aparelho');
      expect(find.text('Conectar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unexpected retry failure preserves queue and permits recovery', (
    tester,
  ) async {
    final repo = _Repository(pending: 2)..failRetry = true;
    await _open(tester, repo);
    await _tap(tester, 'Tentar novamente');
    expect(
      find.text('Não foi possível sincronizar. Tente novamente.'),
      findsOneWidget,
    );
    expect(repo.pending, 2);
    repo.failRetry = false;
    await _tap(tester, 'Tentar novamente');
    expect(repo.pending, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact dark enlarged pairing is operable with keyboard', (
    tester,
  ) async {
    final repo = _Repository(connected: false);
    await _open(
      tester,
      repo,
      size: const Size(320, 568),
      dark: true,
      scale: 1.5,
    );
    final field = find.byKey(const Key('finance_connection_code'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    await tester.pumpAndSettle();
    await tester.enterText(field, 'abcdefghijkl');
    await expectLater(
      find.byType(FinanceIntegrationPage),
      matchesGoldenFile('goldens/finance_connect_51_dark_keyboard_320.png'),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('generic workspace failure after exchange reports data failure', (
    tester,
  ) async {
    final repo = _Repository(connected: false)..failLoadUnexpected = true;
    await _open(tester, repo);
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABCDEFGHIJKL',
    );
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsOneWidget);
    expect(
      find.text(
        'Não foi possível carregar os dados financeiros. Atualize para tentar novamente.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Não foi possível conectar os aplicativos.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('confirmed missing credentials returns to pairing', (
    tester,
  ) async {
    final repo = _Repository(connected: false)..missingCredentials = true;
    await _open(tester, repo);
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABCDEFGHIJKL',
    );
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();
    expect(find.text('Conectado'), findsNothing);
    expect(find.text('Conectar'), findsOneWidget);
    expect(find.text('Aplicativos conectados com segurança.'), findsNothing);
    expect(find.text('Conexão ausente.'), findsOneWidget);
  });
  testWidgets('back cancels pairing without persisting a connection', (
    tester,
  ) async {
    final repo = _Repository(connected: false);
    await _open(tester, repo);
    await tester.enterText(
      find.byKey(const Key('finance_connection_code')),
      'ABCD',
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir finanças'), findsOneWidget);
    expect(repo.receivedCode, isNull);
    expect(repo.connected, isFalse);
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
  bool failLoadUnexpected = false;
  bool missingCredentials = false;
  bool failDisconnect = false;
  bool failRetry = false;
  bool failConnect = false;
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
    if (failLoadUnexpected) throw StateError('network');
    if (missingCredentials) {
      throw const FinanceIntegrationException(
        'Conexão ausente.',
        retryable: false,
        code: 'NOT_CONNECTED',
      );
    }
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
    if (failRetry) throw StateError('offline');
    final count = pending;
    pending = 0;
    return count;
  }

  @override
  Future<void> disconnect() async {
    if (failDisconnect) throw StateError('storage');
    connected = false;
  }

  @override
  Future<FinanceIntegrationConnection> connect(String code) async {
    if (failConnect) {
      throw const FinanceIntegrationException(
        'Código expirado. Gere outro código.',
        retryable: false,
      );
    }
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
