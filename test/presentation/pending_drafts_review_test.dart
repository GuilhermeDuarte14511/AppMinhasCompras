import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/pending_drafts_review_sheet.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/shopping_item_editor_sheet.dart';
import 'package:lista_compras_material/src/presentation/dialogs/widgets/item_editor_support_widgets.dart';

void main() {
  testWidgets('resumo acessível como botão e acionável pelo teclado', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PendingDraftsPreview(
            drafts: const [
              ShoppingItemDraft(
                name: 'Arroz',
                quantity: 1,
                unitPrice: 10,
                category: ShoppingCategory.grocery,
              ),
            ],
            onReview: () => opened = true,
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(PendingDraftsPreview)),
      matchesSemantics(
        label: '1 item pronto: Arroz\nRevisar itens',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    semantics.dispose();
  });
  testWidgets('revisa preços e exclusões sem perder o produto em edição', (
    tester,
  ) async {
    List<ShoppingItemDraft>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showShoppingItemsEditorSheet(context);
                },
                child: const Text('Abrir'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await _queue(tester, 'Arroz', '1000');
    await _queue(tester, 'Feijão', '800');
    await tester.enterText(_field('Item'), 'Café');
    await tester.enterText(_field('Valor unitário'), '1250');
    await _tap(tester, find.textContaining('2 itens prontos:'));
    expect(
      find.text('Altere preços ou exclua itens antes de concluir.'),
      findsOneWidget,
    );
    await _tap(tester, find.byTooltip('Editar preço de Arroz'));
    await tester.enterText(_field('Preço unitário'), '2590');
    await _tap(tester, find.text('Atualizar preço'));
    await _tap(tester, find.byTooltip('Excluir Feijão'));
    await _tap(tester, find.text('Continuar adicionando'));
    expect(tester.widget<TextField>(_field('Item')).controller!.text, 'Café');
    expect(
      tester.widget<TextField>(_field('Valor unitário')).controller!.text,
      contains('12,50'),
    );
    await _tap(tester, find.widgetWithText(FilledButton, 'Adicionar item'));
    expect(result!.map((item) => item.name), ['Arroz', 'Café']);
    expect(result!.first.unitPrice, 25.90);
    expect(result!.last.unitPrice, 12.50);
  });

  testWidgets('excluir todos permite adicionar novamente o mesmo produto', (
    tester,
  ) async {
    List<ShoppingItemDraft>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showShoppingItemsEditorSheet(context);
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await _tap(tester, find.text('Abrir'));
    await _queue(tester, 'Arroz', '1000');
    await _tap(tester, find.textContaining('1 item pronto:'));
    await _tap(tester, find.byTooltip('Excluir Arroz'));
    expect(find.textContaining('Nenhum item na seleção.'), findsOneWidget);
    // Voltar pelo sistema também mantém as exclusões.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.textContaining('1 item pronto:'), findsNothing);
    await _queue(tester, 'Arroz', '1500');
    await _tap(tester, find.text('Concluir seleção'));
    expect(result!.single.name, 'Arroz');
    expect(result!.single.unitPrice, 15);
  });

  testWidgets('valida preço, permite cancelar e preserva os demais dados', (
    tester,
  ) async {
    const draft = ShoppingItemDraft(
      name: 'Café',
      quantity: 3,
      unitPrice: 10,
      category: ShoppingCategory.grocery,
      barcode: '7891234567895',
      isPurchased: true,
    );
    List<ShoppingItemDraft> result = [draft];
    await _openReview(tester, [draft], (value) => result = value);
    await _tap(tester, find.byTooltip('Editar preço de Café'));
    await tester.enterText(_field('Preço unitário'), '0');
    await _tap(tester, find.text('Atualizar preço'));
    expect(find.text('Informe um preço maior que zero.'), findsOneWidget);
    expect(result.single.unitPrice, 10);
    await _tap(tester, find.text('Cancelar'));
    expect(result.single, same(draft));
    await _tap(tester, find.byTooltip('Editar preço de Café'));
    await tester.enterText(_field('Preço unitário'), '1250');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(result.single.unitPrice, 12.50);
    expect(result.single.quantity, 3);
    expect(result.single.category, draft.category);
    expect(result.single.barcode, draft.barcode);
    expect(result.single.isPurchased, isTrue);
    expect(find.textContaining('37,50'), findsNWidgets(2));
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result.single.unitPrice, 12.50);
  });

  for (final width in [320.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('revisão com muitos itens e texto ampliado em $width px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final drafts = List.generate(
        25,
        (index) => ShoppingItemDraft(
          name: 'Produto com nome comprido número $index',
          quantity: 2,
          unitPrice: 19.90,
          category: ShoppingCategory.grocery,
        ),
      );
      List<ShoppingItemDraft> result = drafts;
      await _openReview(
        tester,
        drafts,
        (value) => result = value,
        textScale: 1.5,
      );
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byTooltip('Excluir Produto com nome comprido número 24'),
        250,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await _tap(
        tester,
        find.byTooltip('Excluir Produto com nome comprido número 24'),
      );
      expect(result.length, 24);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.text('Continuar adicionando'));
      expect(find.text('Abrir'), findsOneWidget);
    });
  }
}

Future<void> _openReview(
  WidgetTester tester,
  List<ShoppingItemDraft> drafts,
  ValueChanged<List<ShoppingItemDraft>> onChanged, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showPendingDraftsReviewSheet(
              context,
              drafts: drafts,
              onChanged: onChanged,
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, find.text('Abrir'));
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _queue(WidgetTester tester, String name, String price) async {
  await tester.enterText(_field('Item'), name);
  await tester.enterText(_field('Valor unitário'), price);
  await _tap(tester, find.text('Adicionar e continuar'));
}
