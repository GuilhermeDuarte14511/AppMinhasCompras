import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/launch.dart';

void main() {
  testWidgets('SplashPage presents animated shopping copy and loading cue', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashPage()));

    expect(
      find.byKey(const ValueKey('splash-animation-stage')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('splash-shopping-bag')), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-checklist')), findsOneWidget);
    expect(find.text('Minha Lista de Compras'), findsOneWidget);
    expect(find.text('Organize suas compras de forma simples'), findsOneWidget);
    expect(find.text('Abrindo seu painel...'), findsOneWidget);
  });

  testWidgets('SplashPage updates copy while local data is syncing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SplashPage(showReadyHint: true)),
    );

    expect(find.text('Sincronizando suas compras...'), findsOneWidget);
  });

  testWidgets(
    'SplashPage calls completion callback after configured duration',
    (WidgetTester tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            displayDuration: const Duration(milliseconds: 600),
            onCompleted: () => completed = true,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 599));
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 1));
      expect(completed, isTrue);
    },
  );

  testWidgets('LoadingScreen uses the modern SplashPage experience', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoadingScreen(showReadyHint: false)),
    );

    expect(find.byType(SplashPage), findsOneWidget);
    expect(find.text('Minha Lista de Compras'), findsOneWidget);
  });
}
