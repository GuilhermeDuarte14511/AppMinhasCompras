import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/authentication.dart';
import 'package:lista_compras_material/src/presentation/auth_page.dart';

void main() {
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
}

Widget _app(AuthenticationGateway gateway) {
  return MaterialApp(
    home: AuthPage(
      themeMode: ThemeMode.light,
      onThemeModeChanged: (_) {},
      authenticationGateway: gateway,
    ),
  );
}

class _FakeAuthenticationGateway implements AuthenticationGateway {
  _FakeAuthenticationGateway({this.failure});

  final AuthenticationFailure? failure;
  int emailSignInCalls = 0;
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
  Future<void> sendPasswordResetEmail({required String email}) async {}

  @override
  Future<void> signInWithGoogle() async {}
}
