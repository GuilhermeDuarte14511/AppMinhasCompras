import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/finance_integration.dart';
import 'package:lista_compras_material/src/presentation/finance_purchase_sync_panel.dart';

void main() {
  testWidgets('partial sync is explicit and retry is accessible on mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const fontPath = String.fromEnvironment('GOLDEN_FONT_PATH');
    if (fontPath.isNotEmpty) {
      await tester.runAsync(() async {
        final loader = FontLoader('Roboto')
          ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      });
    }
    var retried = 0;
    FinancePurchaseSync record(
      String id,
      String name,
      int cents,
      FinanceSyncStatus status,
    ) => FinancePurchaseSync(
      purchaseId: 'purchase',
      sourceName: name,
      status: status,
      request: FinancePurchaseRequest(
        externalPurchaseId: id,
        cardId: id,
        paymentSourceKind: id == 'va'
            ? FinancePaymentSourceKind.foodVoucher
            : FinancePaymentSourceKind.credit,
        description: 'Mercado',
        amountCents: cents,
        purchasedOn: DateTime(2026, 9, 7),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          colorSchemeSeed: const Color(0xFF0D7B9A),
        ),
        home: Scaffold(
          appBar: AppBar(title: const Text('Histórico mensal')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compra do mercado',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FinancePurchaseSyncPanel(
                      records: [
                        record('va', 'Alelo', 9600, FinanceSyncStatus.synced),
                        record(
                          'credit',
                          'Visa',
                          2400,
                          FinanceSyncStatus.pending,
                        ),
                      ],
                      onRetry: () => retried++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sincronização parcial · 1/2'), findsOneWidget);
    expect(find.textContaining('Confirmado'), findsOneWidget);
    expect(find.textContaining('Pendente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (fontPath.isNotEmpty) {
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/finance_sync_partial.png'),
      );
    }
    await tester.tap(find.text('Reenviar pendentes'));
    expect(retried, 1);
  });
}
