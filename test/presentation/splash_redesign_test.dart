import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/launch.dart';
import 'package:lista_compras_material/src/presentation/splash/notebook_painter.dart';

void main() {
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MercadoSymbols': 'assets/fonts/MaterialSymbolsOutlined.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  testWidgets('editorial splash golden and honest indeterminate loading', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Minhas Compras'), findsOneWidget);
    expect(find.text('Preparando sua lista...'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Planeje. Marque. Leve.'), findsOneWidget);
    final notebook = find.descendant(
      of: find.byKey(const ValueKey('splash-notebook')),
      matching: find.byType(CustomPaint),
    );
    expect(
      (tester.widget<CustomPaint>(notebook).painter! as SplashNotebookPainter)
          .progress,
      inExclusiveRange(0, 1),
    );
    await tester.pump(const Duration(milliseconds: 1800));
    expect(
      (tester.widget<CustomPaint>(notebook).painter! as SplashNotebookPainter)
          .progress,
      1,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/splash_stitch_390.png'),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('real ready hint changes state without a simulated sequence', (
    tester,
  ) async {
    await _open(tester);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Preparando sua lista...'), findsOneWidget);
    await _open(tester, ready: true);
    expect(find.text('Sincronizando compras'), findsOneWidget);
    expect(find.byKey(const ValueKey('splash-ready')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'compact dark enlarged text and reduced motion keep identity visible',
    (tester) async {
      await _open(tester, compact: true);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Minhas Compras'), findsOneWidget);
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.descendant(
                      of: find.byKey(const ValueKey('splash-notebook')),
                      matching: find.byType(CustomPaint),
                    ),
                  )
                  .painter!
              as SplashNotebookPainter;
      expect(painter.progress, 1);
      expect(
        tester.getBottomRight(find.text('Preparando sua lista...')).dy,
        lessThan(568),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'completion obeys duration exactly once and dispose cancels timer',
    (tester) async {
      var completions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            displayDuration: const Duration(milliseconds: 600),
            onCompleted: () => completions++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 599));
      expect(completions, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(completions, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(completions, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(
          home: SplashPage(
            displayDuration: const Duration(milliseconds: 600),
            onCompleted: () => completions++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(completions, 1);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  bool compact = false,
  bool ready = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(compact ? 1.5 : 1),
          disableAnimations: compact,
        ),
        child: child!,
      ),
      home: SplashPage(showReadyHint: ready),
    ),
  );
  await tester.pump(const Duration(milliseconds: 200));
}
