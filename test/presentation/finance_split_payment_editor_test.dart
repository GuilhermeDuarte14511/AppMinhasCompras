import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/finance_split_payment_editor.dart';

void main() {
  testWidgets('splits VA and credit and blocks totals that do not match', (
    tester,
  ) async {
    List<FinancePaymentAllocation>? allocations;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: FinanceSplitPaymentEditor(
              totalCents: 12000,
              sources: const [
                FinancePaymentSource(
                  id: 'va',
                  kind: FinancePaymentSourceKind.foodVoucher,
                  name: 'Alelo',
                  availableCents: 9600,
                  colorHex: '#006B45',
                ),
                FinancePaymentSource(
                  id: 'credit',
                  kind: FinancePaymentSourceKind.credit,
                  name: 'Visa',
                  availableCents: 100000,
                  colorHex: '#1434CB',
                ),
              ],
              onChanged: (value) => allocations = value,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(allocations, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-0')),
      '9600',
    );
    await tester.tap(find.text('Adicionar pagamento'));
    await tester.pumpAndSettle();
    expect(allocations?.map((a) => a.amountCents), [9600, 2400]);
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-1')),
      '2300',
    );
    await tester.pumpAndSettle();
    expect(allocations, isNull);
    expect(find.textContaining('Falta distribuir'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('split-amount-1')),
      '2400',
    );
    await tester.pumpAndSettle();
    expect(allocations?.length, 2);
    expect(tester.takeException(), isNull);
  });
}
