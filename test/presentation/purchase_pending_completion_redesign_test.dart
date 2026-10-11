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

  testWidgets('pending modal follows centered Stitch with actual response', (
    tester,
  ) async {
    const message =
        'Compra fechada. O envio ao Finanças está pendente; confira o histórico.';
    await _open(tester, message);
    expect(find.text('Compra salva · envio pendente'), findsOneWidget);
    expect(find.text('Salva no histórico'), findsOneWidget);
    expect(
      find.text('Sincronização da conta em segundo plano'),
      findsOneWidget,
    );
    expect(find.text(message), findsOneWidget);
    expect(find.textContaining('sem duplicar'), findsNothing);
    expect(find.textContaining('R\$'), findsNothing);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/purchase_pending_completion_stitch_390.png'),
    );
    final panel = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Padding))
        .first;
    expect(tester.getCenter(panel).dy, closeTo(422, 1));
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Concluir')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();
    expect(find.text('Retorno concluído'), findsOneWidget);
  });

  testWidgets('partial actual payment response remains visible and selectable', (
    tester,
  ) async {
    const message =
        'Compra fechada. 1 de 2 pagamentos sincronizados. Confira o histórico.';
    await _open(tester, message);
    expect(find.text('Envio parcial'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, message), findsOneWidget);
    expect(find.text('Compra concluída'), findsNothing);
  });

  testWidgets('complete allocations stay in existing completed variant', (
    tester,
  ) async {
    await _open(
      tester,
      'Compra fechada. 2 de 2 pagamentos sincronizados. Confira o histórico.',
    );
    expect(find.text('Compra concluída'), findsOneWidget);
    expect(find.text('Compra salva · envio pendente'), findsNothing);
  });

  testWidgets('attention outranks pending and keeps supplied error', (
    tester,
  ) async {
    const message =
        'Compra fechada, mas não foi lançada no Finanças: envio pendente.';
    await _open(tester, message);
    expect(find.text('Compra salva com atenção'), findsOneWidget);
    expect(find.text('Requer atenção'), findsOneWidget);
    expect(find.text(message), findsOneWidget);
  });

  testWidgets('pending blocks outside tap and preserves platform back return', (
    tester,
  ) async {
    await _open(tester, 'Envio pendente.');
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Retorno concluído'), findsOneWidget);
  });

  testWidgets(
    'dark compact enlarged pending message scrolls with keyboard and fixed action',
    (tester) async {
      await _open(
        tester,
        'Envio pendente. ${List.filled(35, 'Confira os pagamentos no histórico.').join(' ')}',
        compact: true,
      );
      expect(tester.takeException(), isNull);
      final action = find.widgetWithText(FilledButton, 'Concluir');
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(388));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Retorno concluído'), findsOneWidget);
    },
  );
}

Future<void> _open(
  WidgetTester tester,
  String message, {
  bool compact = false,
}) async {
  tester.view.physicalSize = compact
      ? const Size(320, 568)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var returned = false;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'MercadoPublicSans',
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(compact ? 1.5 : 1),
          viewInsets: EdgeInsets.only(bottom: compact ? 180 : 0),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            if (returned) return const Text('Retorno concluído');
            return TextButton(
              onPressed: () async {
                await showPurchaseCompletionDialog(
                  context,
                  financeMessage: message,
                );
                if (context.mounted) setState(() => returned = true);
              },
              child: const Text('Fechar compra'),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.text('Fechar compra'));
  await tester.pumpAndSettle();
}
