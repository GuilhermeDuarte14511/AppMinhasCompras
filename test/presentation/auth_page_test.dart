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
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('email login delegates credentials through application port', (
    tester,
  ) async {
    final gateway = _FakeAuthenticationGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), ' pessoa@example.com ');
    await tester.enterText(fields.at(1), 'senha-segura');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(gateway.email, ' pessoa@example.com ');
    expect(gateway.password, 'senha-segura');
    expect(gateway.emailSignInCalls, 1);
  });

  testWidgets('typed authentication failure is shown without Firebase in UI', (
    tester,
  ) async {
    final gateway = _FakeAuthenticationGateway(
      failure: const AuthenticationFailure(
        code: 'invalid-credential',
        userMessage: 'E-mail ou senha incorretos.',
      ),
    );
    await tester.pumpWidget(_app(gateway));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'pessoa@example.com');
    await tester.enterText(fields.at(1), 'senha-segura');
    await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
    await tester.pump();

    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
  });

  testWidgets('Google sign-in delegates once and locks actions while pending', (
    tester,
  ) async {
    final pending = Completer<void>();
    final gateway = _FakeAuthenticationGateway(googlePending: pending.future);
    await tester.pumpWidget(_app(gateway));
    await tester.tap(find.text('Continuar com Google'));
    await tester.pump();
    expect(gateway.googleSignInCalls, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    final google = find.ancestor(
      of: find.text('Continuar com Google'),
      matching: find.byType(OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(google).onPressed, isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<OutlinedButton>(google).onPressed, isNotNull);
  });

  testWidgets('recovery uses entered email and password visibility toggles', (
    tester,
  ) async {
    final gateway = _FakeAuthenticationGateway();
    await tester.pumpWidget(_app(gateway));
    await tester.enterText(
      find.byType(TextFormField).first,
      'pessoa@example.com',
    );
    await tester.tap(find.text('Recuperar senha'));
    await tester.pump();
    expect(gateway.resetEmail, 'pessoa@example.com');
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
      isFalse,
    );
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('create account opens existing signup page', (tester) async {
    await tester.pumpWidget(_app(_FakeAuthenticationGateway()));
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Criar conta'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Criar conta'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateAccountPage), findsOneWidget);
  });

  testWidgets('Stitch login mobile visual reference', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('login-capture'),
        child: _app(_FakeAuthenticationGateway()),
      ),
    );
    await tester.enterText(
      find.byType(TextFormField).first,
      'helena.ramos@exemplo.com.br',
    );
    await tester.enterText(find.byType(TextFormField).last, 'mercado2024');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('login-capture')),
      matchesGoldenFile('goldens/login_stitch_390.png'),
    );
  });

  testWidgets(
    'small screen with keyboard and enlarged text keeps actions reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      tester.view.viewInsets = const FakeViewPadding(bottom: 220);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: AuthPage(
            themeMode: ThemeMode.dark,
            onThemeModeChanged: (_) {},
            authenticationGateway: _FakeAuthenticationGateway(),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Criar conta'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Continuar com Google'), findsOneWidget);
    },
  );
}

Widget _app(AuthenticationGateway gateway) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AuthPage(
      themeMode: ThemeMode.light,
      onThemeModeChanged: (_) {},
      authenticationGateway: gateway,
    ),
  );
}

class _FakeAuthenticationGateway implements AuthenticationGateway {
  _FakeAuthenticationGateway({this.failure, this.googlePending});

  final AuthenticationFailure? failure;
  final Future<void>? googlePending;
  int emailSignInCalls = 0;
  int googleSignInCalls = 0;
  String? resetEmail;
  String? email;
  String? password;

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    emailSignInCalls++;
    this.email = email;
    this.password = password;
    final failure = this.failure;
    if (failure != null) {
      throw failure;
    }
  }

  @override
  Future<void> createAccount({
    required String name,
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    resetEmail = email;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalls++;
    await googlePending;
  }
}
