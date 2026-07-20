import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/voice_quick_add_sheet.dart';

void main() {
  testWidgets('reviews a spoken item matched safely to the catalog', (
    tester,
  ) async {
    List<ShoppingItemDraft>? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                submitted = await showVoiceQuickAddSheet(
                  context,
                  voiceRecognitionService: _FakeVoiceRecognitionService(),
                  catalogProducts: [
                    CatalogProduct(
                      id: 'minuano',
                      name: 'Detergente Minuano 500 ml',
                      category: ShoppingCategory.cleaning,
                      unitPrice: 4.99,
                      barcode: '7891234567895',
                      updatedAt: DateTime(2026, 7, 20),
                    ),
                  ],
                  currentItems: const <ShoppingItem>[],
                  initialTranscript: 'dois detergentes Minuano',
                  autoStart: false,
                );
              },
              child: const Text('Abrir voz'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir voz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();

    expect(find.text('Revise os produtos'), findsOneWidget);
    expect(find.text('Detergente Minuano 500 ml'), findsOneWidget);
    expect(find.textContaining('2 un.'), findsOneWidget);
    expect(find.textContaining('4,99'), findsOneWidget);
    expect(find.text('Match seguro'), findsOneWidget);
    expect(find.text('Código associado'), findsOneWidget);

    await tester.tap(find.text('Adicionar 1 produto'));
    await tester.pumpAndSettle();

    expect(submitted, isNotNull);
    expect(submitted, hasLength(1));
    expect(submitted!.single.quantity, 2);
    expect(submitted!.single.unitPrice, 4.99);
    expect(submitted!.single.barcode, '7891234567895');
  });

  testWidgets('blocks submission of a new product without a price', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () {
                showVoiceQuickAddSheet(
                  context,
                  voiceRecognitionService: _FakeVoiceRecognitionService(),
                  catalogProducts: const <CatalogProduct>[],
                  currentItems: const <ShoppingItem>[],
                  initialTranscript: 'um produto inédito',
                  autoStart: false,
                );
              },
              child: const Text('Abrir voz'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir voz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar 1 produto'));
    await tester.pumpAndSettle();

    expect(
      find.text('Informe o valor dos produtos destacados antes de adicionar.'),
      findsOneWidget,
    );
    expect(find.text('Produto novo'), findsOneWidget);
  });
}

class _FakeVoiceRecognitionService implements ShoppingVoiceRecognitionService {
  @override
  bool get isListening => false;

  @override
  Future<void> cancelListening() async {}

  @override
  Future<bool> initialize({
    required void Function(String message) onError,
    required void Function(String status) onStatus,
  }) async {
    return true;
  }

  @override
  Future<void> startListening({
    required void Function(ShoppingVoiceRecognitionUpdate update) onResult,
    String localeId = 'pt_BR',
  }) async {}

  @override
  Future<void> stopListening() async {}
}
