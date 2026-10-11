import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/shopping_item_editor_sheet.dart';

void main() {
  testWidgets(
    'botoes do editor de item respeitam a SafeArea e ficam acima dos botoes virtuais do sistema',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      // Simula uma barra de navegacao virtual de 48dp no rodape (botoes virtuais do Android)
      tester.view.padding = const FakeViewPadding(bottom: 48 * 2.5);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => showShoppingItemsEditorSheet(context),
                  child: const Text('Abrir Editor'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir Editor'));
      await tester.pumpAndSettle();

      final addBtnFinder = find.widgetWithText(FilledButton, 'Adicionar item');
      final continueBtnFinder = find.widgetWithText(
        OutlinedButton,
        'Adicionar e continuar',
      );

      expect(addBtnFinder, findsOneWidget);
      expect(continueBtnFinder, findsOneWidget);

      final addBtnRect = tester.getRect(addBtnFinder);
      final continueBtnRect = tester.getRect(continueBtnFinder);

      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final navBarTop = screenHeight - 48;

      // Os botoes devem estar completamente acima da barra virtual do Android
      expect(
        addBtnRect.bottom,
        lessThanOrEqualTo(navBarTop),
        reason:
            'O botao Adicionar item deve ficar acima dos botoes virtuais (navBarTop = $navBarTop, botao.bottom = ${addBtnRect.bottom})',
      );
      expect(
        continueBtnRect.bottom,
        lessThanOrEqualTo(navBarTop),
        reason:
            'O botao Adicionar e continuar deve ficar acima dos botoes virtuais (navBarTop = $navBarTop, botao.bottom = ${continueBtnRect.bottom})',
      );
    },
  );
}
