import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/fiscal_receipt_import.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/fiscal_receipt_import_sheet.dart';

void main() {
  testWidgets(
    'reviews selection, edits, confidence, planned link and total difference',
    (tester) async {
      FiscalReceiptReviewSubmission? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result =
                          await showModalBottomSheet<
                            FiscalReceiptReviewSubmission
                          >(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => FiscalReceiptImportSheet(
                              currentItems: [_plannedRice()],
                            ),
                          );
                    },
                    child: const Text('Abrir cupom'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Abrir cupom'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Texto do cupom'),
        '''
AR001 ARROZ TIPO 1 1 UND9 20,00 20,00
AR002 CAFE TORRADO 1 UND9 18,90 18,90
Valor total R\$ 40,00
''',
      );
      await tester.pump();

      expect(find.textContaining('Cupom R\$'), findsOneWidget);
      await tester.tap(find.text('Revisar 2 itens'));
      await tester.pumpAndSettle();

      expect(find.text('2 itens selecionados'), findsOneWidget);
      expect(find.textContaining('Alta 98%'), findsOneWidget);
      expect(
        find.textContaining('A soma difere do cupom em'),
        findsOneWidget,
      );

      await tester.tap(find.text('Desmarcar todos'));
      await tester.pump();
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Produto').first,
        'Arroz integral',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Quantidade').first,
        '2',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Preço unitário').first,
        '12,50',
      );
      await tester.pump();

      expect(find.text('1 item selecionado'), findsOneWidget);
      expect(find.textContaining('Subtotal R\$'), findsOneWidget);
      expect(
        find.textContaining('A soma difere do cupom em'),
        findsOneWidget,
      );

      await tester.tap(find.text('Confirmar compra'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.items, hasLength(1));
      expect(result!.items.single.draft.name, 'Arroz integral');
      expect(result!.items.single.draft.quantity, 2);
      expect(result!.items.single.draft.unitPrice, 12.50);
      expect(result!.items.single.plannedItemId, 'planned-rice');
      expect(result!.declaredTotal, 40);
      expect(result!.finalizePurchase, isTrue);
    },
  );
}

ShoppingItem _plannedRice() {
  return ShoppingItem(
    id: 'planned-rice',
    name: 'ARROZ TIPO 1',
    quantity: 1,
    unitPrice: 19,
    isPurchased: false,
    category: ShoppingCategory.grainsAndPasta,
    priceHistory: const <PriceHistoryEntry>[],
  );
}
