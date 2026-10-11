import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/purchase_checkout_completion_dialog.dart';

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

  testWidgets('editorial completion confirms only explicit finance success', (
    tester,
  ) async {
    await _open(
      tester,
      message: 'Compra fechada e lançada no Minhas Finanças.',
    );
    expect(find.text('Compra concluída'), findsOneWidget);
    expect(find.text('Lançada'), findsOneWidget);
    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text('Sincronizado'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/completion_stitch_390.png'),
    );
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Concluir')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('local completion has no unverified financial success', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Integração financeira'), findsNothing);
    expect(find.text('Em segundo plano'), findsOneWidget);
    expect(
      find.text(
        'Compra salva no histórico. A sincronização da conta continua em segundo plano.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('real partial allocation response is pending instead of complete', (
    tester,
  ) async {
    const message =
        'Compra fechada. 1 de 2 pagamentos sincronizados. Confira o histórico.';
    await _open(tester, message: message);
    expect(find.text('Compra salva · envio pendente'), findsOneWidget);
    expect(find.text('Envio parcial'), findsOneWidget);
    expect(find.text('Compra concluída'), findsNothing);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets(
    'monthly and shared completion preserve actual history messages',
    (tester) async {
      for (final message in [
        'Compra fechada e salva no histórico mensal.',
        'Compra fechada e salva no histórico compartilhado.',
      ]) {
        await _open(tester, message: message);
        expect(find.text(message), findsOneWidget);
        expect(find.text('Compra concluída'), findsOneWidget);
        expect(find.text('Integração financeira'), findsNothing);
        expect(find.text('Lançada'), findsNothing);
        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
      }
    },
  );
  testWidgets('zero synchronized or explicitly pending remains pending', (
    tester,
  ) async {
    await _open(
      tester,
      message:
          'Compra fechada. O envio ao Finanças está pendente; confira o histórico.',
    );
    expect(find.text('Envio pendente'), findsOneWidget);
    expect(find.text('Compra salva · envio pendente'), findsOneWidget);
  });

  testWidgets(
    'failure and invalid total preserve recorded purchase and attention',
    (tester) async {
      for (final message in [
        'Compra fechada, mas não foi lançada no Finanças: conexão indisponível.',
        'Compra fechada, mas o total precisa ser maior que zero para lançar no Finanças.',
      ]) {
        await _open(tester, message: message);
        expect(find.text('Compra salva com atenção'), findsOneWidget);
        expect(find.text('Requer atenção'), findsOneWidget);
        expect(find.text('Registrado'), findsOneWidget);
        expect(find.text(message), findsOneWidget);
        await tester.tap(find.text('Concluir'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'modal barrier stays blocked and platform back retains original behavior',
    (tester) async {
      await _open(tester);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets(
    'compact dark enlarged message scrolls while conclude remains visible',
    (tester) async {
      await _open(
        tester,
        compact: true,
        message:
            'Compra fechada, mas não foi lançada no Finanças: ${List.filled(30, 'Serviço indisponível; confira sua conexão.').join(' ')}',
      );
      expect(tester.takeException(), isNull);
      final action = find.widgetWithText(FilledButton, 'Concluir');
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(568));
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  String? message,
  bool compact = false,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'MercadoPublicSans',
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showPurchaseCompletionDialog(context, financeMessage: message),
            child: const Text('Fechar compra'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Fechar compra'));
  await tester.pumpAndSettle();
}
