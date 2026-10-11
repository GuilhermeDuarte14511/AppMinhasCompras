import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/authentication.dart';
import 'package:lista_compras_material/src/presentation/auth_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
    }.entries) {
      final loader = FontLoader(font.key)..addFont(rootBundle.load(font.value));
      if (font.key == 'MercadoNewsreader') {
        loader.addFont(rootBundle.load('assets/fonts/Newsreader-Italic.ttf'));
      }
      await loader.load();
    }
  });

  testWidgets(
    'six-character signup delegates credentials and returns to login',
    (tester) async {
      final gateway = _Gateway();
      await _open(tester, gateway);
      await _fill(tester, password: '123456');
      await _submit(tester);
      expect(gateway.calls, 1);
      expect(gateway.name, 'Maria Clara');
      expect(gateway.email, 'maria@example.com');
      expect(gateway.password, '123456');
      expect(find.byType(CreateAccountPage), findsNothing);
      expect(find.byType(AuthPage), findsOneWidget);
    },
  );

  testWidgets('invalid fields and mismatched passwords never submit', (
    tester,
  ) async {
    final gateway = _Gateway();
    await _open(tester, gateway);
    await _submit(tester);
    expect(find.text('Informe seu nome.'), findsOneWidget);
    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Senha mínima de 6 caracteres.'), findsOneWidget);
    expect(gateway.calls, 0);
    await _fill(tester);
    await tester.enterText(find.byType(TextFormField).last, 'diferente');
    await _submit(tester);
    expect(find.text('As senhas não conferem.'), findsOneWidget);
    expect(gateway.calls, 0);
  });

  testWidgets('password fields toggle independently', (tester) async {
    await _open(tester, _Gateway());
    await tester.ensureVisible(find.byTooltip('Mostrar senha'));
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    final fields = find.byType(EditableText);
    expect(tester.widget<EditableText>(fields.at(2)).obscureText, isFalse);
    expect(tester.widget<EditableText>(fields.at(3)).obscureText, isTrue);
    await tester.ensureVisible(find.byTooltip('Mostrar confirmação de senha'));
    await tester.tap(find.byTooltip('Mostrar confirmação de senha'));
    await tester.pump();
    expect(tester.widget<EditableText>(fields.at(3)).obscureText, isFalse);
  });

  testWidgets('authentication failure preserves signup and allows retry', (
    tester,
  ) async {
    final gateway = _Gateway(
      failure: const AuthenticationFailure(
        code: 'email-already-in-use',
        userMessage: 'Este e-mail já está em uso.',
      ),
    );
    await _open(tester, gateway);
    await _fill(tester);
    await _submit(tester);
    expect(find.text('Este e-mail já está em uso.'), findsOneWidget);
    expect(find.byType(CreateAccountPage), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('pending signup cannot submit twice and may return safely', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = _Gateway(pending: pending.future);
    await _open(tester, gateway);
    await _fill(tester);
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Criar conta'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Criar conta'));
    await tester.pump();
    expect(find.text('Criando conta...'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(gateway.calls, 1);
    await tester.tap(find.text('Voltar'));
    await tester.pump(const Duration(seconds: 1));
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('signup matches mobile visual reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('signup-capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: CreateAccountPage(
            authenticationGateway: _Gateway(),
            onThemeModeChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('signup-capture')),
      matchesGoldenFile('goldens/create_account_stitch_390.png'),
    );
  });

  testWidgets(
    'dark signup with enlarged text and keyboard scrolls without overflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: CreateAccountPage(
            authenticationGateway: _Gateway(),
            onThemeModeChanged: (_) {},
          ),
        ),
      );
      await tester.ensureVisible(find.text('Já tem uma conta? Entrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(WidgetTester tester, _Gateway gateway) async {
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthPage(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        authenticationGateway: gateway,
      ),
    ),
  );
  await tester.ensureVisible(
    find.widgetWithText(OutlinedButton, 'Criar conta'),
  );
  await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, {String password = 'senha123'}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Maria Clara');
  await tester.enterText(fields.at(1), 'maria@example.com');
  await tester.enterText(fields.at(2), password);
  await tester.enterText(fields.at(3), password);
}

Future<void> _submit(WidgetTester tester) async {
  final button = find.widgetWithText(FilledButton, 'Criar conta');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _Gateway implements AuthenticationGateway {
  _Gateway({this.failure, this.pending});
  final AuthenticationFailure? failure;
  final Future<void>? pending;
  int calls = 0;
  String? name, email, password;

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    calls++;
    this.name = name;
    this.email = email;
    this.password = password;
    await pending;
    if (failure != null) throw failure!;
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> sendPasswordResetEmail({required String email}) async {}
}
