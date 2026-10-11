import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/onboarding_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('three steps preserve content, navigation and gated completion', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    expect(
      find.text('Listas separadas por contexto (mercado, farmácia, casa).'),
      findsOneWidget,
    );
    expect(find.text('Concluir'), findsNothing);
    expect(find.text('Claro'), findsNothing);
    await _next(tester, 'Próximo: Produtos');
    expect(find.text('Passo 2 de 3'), findsOneWidget);
    expect(
      find.text('Scanner de código de barras com preenchimento automático.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    await _last(tester);
    expect(find.text('Passo 3 de 3'), findsOneWidget);
    expect(
      find.text('Modo offline-first com sincronização automática.'),
      findsOneWidget,
    );
    expect(find.text('Pular'), findsNothing);
    expect(find.text('Concluir'), findsOneWidget);
  });

  testWidgets('swiping retains existing step navigation', (tester) async {
    await tester.pumpWidget(_app());
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 3'), findsOneWidget);
  });

  testWidgets('skip delegates once and disables controls while saving', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<void>();
    await tester.pumpWidget(
      _app(
        onSkip: () {
          calls++;
          return pending.future;
        },
      ),
    );
    await tester.tap(find.text('Pular'));
    await tester.pump();
    expect(calls, 1);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Pular'))
          .onPressed,
      isNull,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    pending.complete();
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  for (final create in [false, true]) {
    testWidgets(
      'complete passes createFirstList=$create and locks both actions',
      (tester) async {
        final pending = Completer<void>();
        final choices = <bool>[];
        await tester.pumpWidget(
          _app(
            onComplete: ({required createFirstList}) {
              choices.add(createFirstList);
              return pending.future;
            },
          ),
        );
        await _last(tester);
        await tester.tap(
          find.text(create ? 'Concluir e Criar Lista' : 'Concluir'),
        );
        await tester.pump();
        expect(choices, [create]);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Concluir'),
              )
              .onPressed,
          isNull,
        );
        pending.complete();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('theme selection updates the app preference on final step', (
    tester,
  ) async {
    final selected = <ThemeMode>[];
    await tester.pumpWidget(_app(onTheme: selected.add));
    await _last(tester);
    await tester.ensureVisible(find.text('Escuro'));
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(selected, [ThemeMode.dark]);
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(selected, [ThemeMode.dark, ThemeMode.light]);
  });

  testWidgets('first and final steps have mobile visual references', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 884);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      RepaintBoundary(key: const ValueKey('onboarding-capture'), child: _app()),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byKey(const ValueKey('onboarding-capture')),
      matchesGoldenFile('goldens/onboarding_first_stitch_390.png'),
    );
    await _last(tester);
    await expectLater(
      find.byKey(const ValueKey('onboarding-capture')),
      matchesGoldenFile('goldens/onboarding_last_stitch_390.png'),
    );
  });

  testWidgets(
    'dark theme and enlarged text remain scrollable on small screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_app(initialTheme: ThemeMode.dark, scale: 1.5));
      await _last(tester);
      await tester.ensureVisible(find.text('Escuro'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Concluir'), findsOneWidget);
    },
  );
}

Future<void> _next(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _last(WidgetTester tester) async {
  await _next(tester, 'Próximo: Produtos');
  await _next(tester, 'Próximo: Segurança');
}

Widget _app({
  Future<void> Function()? onSkip,
  OnboardingCompleteCallback? onComplete,
  ValueChanged<ThemeMode>? onTheme,
  ThemeMode initialTheme = ThemeMode.light,
  double scale = 1,
}) {
  var mode = initialTheme;
  return StatefulBuilder(
    builder: (context, setState) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: mode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: OnboardingPage(
        themeMode: mode,
        onThemeModeChanged: (value) {
          onTheme?.call(value);
          setState(() => mode = value);
        },
        onSkip: onSkip ?? () async {},
        onComplete: onComplete ?? ({required createFirstList}) async {},
      ),
    ),
  );
}
