import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/dialogs/list_name_dialog.dart';

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

  testWidgets(
    'editorial name dialog uses actual initial name and dynamic action',
    (tester) async {
      await _open(tester, initialValue: 'Feira de sábado');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/list_name_stitch_390.png'),
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('list_name_field')))
            .controller!
            .text,
        'Feira de sábado',
      );
      expect(
        tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode
            .hasFocus,
        isTrue,
      );
      for (final button in [
        find.byType(FilledButton),
        find.byType(OutlinedButton),
      ]) {
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
    },
  );

  testWidgets('create rename duplicate trim text through the same API', (
    tester,
  ) async {
    for (final entry in {
      'Nova lista de compras': 'Criar lista',
      'Renomear lista': 'Salvar',
      'Duplicar lista': 'Duplicar',
    }.entries) {
      String? result;
      await _open(
        tester,
        title: entry.key,
        confirmLabel: entry.value,
        initialValue: 'Nome atual',
        onResult: (value) => result = value,
      );
      expect(find.text(entry.key), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('list_name_field')),
        '  Compras da semana  ',
      );
      await tester.tap(find.widgetWithText(FilledButton, entry.value));
      await tester.pumpAndSettle();
      expect(result, 'Compras da semana');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'empty names validate on button and IME then IME returns trimmed value',
    (tester) async {
      String? result;
      await _open(tester, onResult: (value) => result = value);
      await tester.tap(find.text('Criar lista'));
      await tester.pumpAndSettle();
      expect(find.text('Digite um nome para a lista.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('list_name_field')), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Digite um nome para a lista.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(
        find.byKey(const Key('list_name_field')),
        '  Feira  ',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(result, 'Feira');
    },
  );

  testWidgets('cancel close and route back return null without saving', (
    tester,
  ) async {
    for (final mode in ['cancel', 'close', 'back']) {
      var called = false;
      String? result = 'untouched';
      await _open(
        tester,
        initialValue: 'Lista original',
        onResult: (value) {
          called = true;
          result = value;
        },
      );
      await tester.enterText(
        find.byKey(const Key('list_name_field')),
        'Alteração não salva',
      );
      if (mode == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(
          mode == 'close' ? find.byTooltip('Fechar') : find.text('Cancelar'),
        );
      }
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'compact dark long title enlarged text keyboard keeps footer reachable',
    (tester) async {
      String? result;
      await _open(
        tester,
        compact: true,
        title: 'Renomear a lista de compras compartilhada da família',
        confirmLabel: 'Salvar alterações',
        onResult: (value) => result = value,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final button in [
        find.byType(FilledButton),
        find.byType(OutlinedButton),
      ]) {
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(358));
      }
      await tester.ensureVisible(find.byKey(const Key('list_name_field')));
      await tester.enterText(
        find.byKey(const Key('list_name_field')),
        'Lista da família',
      );
      await tester.tap(find.text('Salvar alterações'));
      await tester.pumpAndSettle();
      expect(result, 'Lista da família');
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _open(
  WidgetTester tester, {
  bool compact = false,
  String title = 'Nova lista de compras',
  String confirmLabel = 'Criar lista',
  String initialValue = '',
  ValueChanged<String?>? onResult,
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
        brightness: compact ? Brightness.dark : Brightness.light,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(compact ? 1.5 : 1)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await showListNameDialog(
                  context,
                  title: title,
                  confirmLabel: confirmLabel,
                  initialValue: initialValue,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}
