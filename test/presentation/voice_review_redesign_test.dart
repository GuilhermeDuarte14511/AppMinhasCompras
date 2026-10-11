import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/voice_quick_add_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';

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

  testWidgets('review editorial reference and computed totals', (tester) async {
    _size(tester, const Size(390, 884));
    await _open(tester, transcript: 'dois leites, um café, três sabonetes');
    await _review(tester);
    await tester.tap(find.byType(Checkbox).last);
    await tester.pumpAndSettle();
    expect(find.textContaining('13,80'), findsOneWidget);
    expect(find.textContaining('6,90/un'), findsOneWidget);
    expect(find.textContaining('Preço a definir'), findsOneWidget);
    expect(find.text('2 de 3 selecionados'), findsOneWidget);
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/voice_review_stitch_42_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'toggle all and single selection return only selected real draft',
    (tester) async {
      List<ShoppingItemDraft>? result;
      await _open(
        tester,
        transcript: 'dois leites, um café',
        onResult: (value) => result = value,
      );
      await _review(tester);
      await tester.tap(find.text('Desmarcar todos'));
      await tester.pumpAndSettle();
      expect(find.text('0 de 2 selecionados'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Nenhum produto selecionado'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Selecionar todos'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 2 selecionados'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar 1 produto'));
      await tester.pumpAndSettle();
      expect(result, hasLength(1));
      expect(result!.single.name, 'Leite integral');
      expect(result!.single.quantity, 2);
      expect(result!.single.unitPrice, 6.9);
    },
  );

  testWidgets(
    'ambiguous dropdown integrates real catalog category price barcode',
    (tester) async {
      List<ShoppingItemDraft>? result;
      final products = [
        CatalogProduct(
          id: 'neutral',
          name: 'Detergente Minuano Neutro 500 ml',
          category: ShoppingCategory.cleaning,
          unitPrice: 5,
          barcode: '7891234567895',
          updatedAt: DateTime(2026),
        ),
        CatalogProduct(
          id: 'lemon',
          name: 'Detergente Minuano Limão 500 ml',
          category: ShoppingCategory.cleaning,
          unitPrice: 5.2,
          barcode: '7891234567888',
          updatedAt: DateTime(2026),
        ),
      ];
      await _open(
        tester,
        transcript: 'dois detergentes minuano',
        catalog: products,
        onResult: (value) => result = value,
      );
      await _review(tester);
      expect(find.text('Escolha necessária'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<CatalogProduct>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(products.last.name).last);
      await tester.pumpAndSettle();
      expect(find.text('Catálogo confirmado'), findsOneWidget);
      await tester.tap(find.text('Adicionar 1 produto'));
      await tester.pumpAndSettle();
      expect(result!.single.name, products.last.name);
      expect(result!.single.quantity, 2);
      expect(result!.single.unitPrice, 5.2);
      expect(result!.single.barcode, products.last.barcode);
      expect(result!.single.category, ShoppingCategory.cleaning);
    },
  );

  testWidgets(
    'missing price prevents submit and product editor supplies actual price',
    (tester) async {
      List<ShoppingItemDraft>? result;
      await _open(
        tester,
        transcript: 'um produto inédito',
        onResult: (value) => result = value,
      );
      await _review(tester);
      await tester.tap(find.text('Adicionar 1 produto'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.textContaining('Informe o valor'), findsOneWidget);
      await tester.tap(find.byTooltip('Editar produto'));
      await tester.pumpAndSettle();
      final price = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Valor unitário',
      );
      await tester.ensureVisible(price);
      await tester.enterText(price, '750');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Salvar item'));
      await tester.tap(find.text('Salvar item'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar 1 produto'));
      await tester.pumpAndSettle();
      expect(result, hasLength(1));
      expect(result!.single.unitPrice, 7.5);
    },
  );

  testWidgets(
    'return to phrase preserves input and close cancels without drafts',
    (tester) async {
      List<ShoppingItemDraft>? result;
      var returned = false;
      await _open(
        tester,
        transcript: 'dois leites',
        onResult: (value) {
          result = value;
          returned = true;
        },
      );
      await _review(tester);
      await tester.tap(find.text('Ouvir novamente'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'dois leites'), findsOneWidget);
      await _review(tester);
      await tester.tap(find.byTooltip('Fechar voz'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
    },
  );

  testWidgets(
    'current-list badge reflects real match without invented association',
    (tester) async {
      await _open(
        tester,
        transcript: 'dois leites',
        current: [
          ShoppingItem(
            id: 'milk-in-list',
            name: 'Leite integral',
            quantity: 4,
            unitPrice: 6.9,
            category: ShoppingCategory.dairy,
          ),
        ],
      );
      await _review(tester);
      expect(find.text('Quantidade será somada'), findsOneWidget);
      expect(find.textContaining('(da lista)'), findsNothing);
    },
  );

  testWidgets(
    'compact dark review keeps actions above keyboard with enlarged text',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _open(
        tester,
        transcript: 'dois leites, um café',
        dark: true,
        scale: 1.5,
      );
      await _review(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final button = find.widgetWithText(FilledButton, 'Adicionar 2 produtos');
      expect(tester.getBottomRight(button).dy, lessThanOrEqualTo(388));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/voice_review_dark_keyboard_320.png'),
      );
    },
  );
}

Future<void> _review(WidgetTester tester) async {
  await tester.tap(find.text('Analisar itens'));
  await tester.pumpAndSettle();
}

void _size(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> _open(
  WidgetTester tester, {
  _Voice? service,
  List<CatalogProduct>? catalog,
  List<ShoppingItem> current = const [],
  String transcript = '',
  bool autoStart = false,
  bool dark = false,
  double scale = 1,
  ValueChanged<List<ShoppingItemDraft>?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: editorialWorkspaceTheme(
        dark ? ThemeData.dark() : ThemeData.light(),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async {
                final result = await showVoiceQuickAddSheet(
                  context,
                  voiceRecognitionService: service ?? _Voice(),
                  catalogProducts:
                      catalog ??
                      [
                        CatalogProduct(
                          id: 'milk',
                          category: ShoppingCategory.dairy,
                          name: 'Leite integral',
                          unitPrice: 6.9,
                          updatedAt: DateTime(2026, 10, 10),
                        ),
                        CatalogProduct(
                          id: 'coffee',
                          category: ShoppingCategory.beverages,
                          name: 'Café torrado',
                          unitPrice: 18.9,
                          updatedAt: DateTime(2026, 10, 10),
                        ),
                      ],
                  currentItems: current,
                  initialTranscript: transcript,
                  autoStart: autoStart,
                );
                onResult?.call(result);
              },
              child: const Text('Abrir voz'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir voz'));
  await tester.pumpAndSettle();
}

class _Voice implements ShoppingVoiceRecognitionService {
  final bool available = true;
  int starts = 0, stops = 0, cancels = 0;
  void Function(String)? error, status;
  void Function(ShoppingVoiceRecognitionUpdate)? result;
  @override
  bool isListening = false;
  @override
  Future<bool> initialize({
    required void Function(String) onError,
    required void Function(String) onStatus,
  }) async {
    error = onError;
    status = onStatus;
    return available;
  }

  @override
  Future<void> startListening({
    required void Function(ShoppingVoiceRecognitionUpdate) onResult,
    String localeId = 'pt_BR',
  }) async {
    starts++;
    isListening = true;
    result = onResult;
  }

  @override
  Future<void> stopListening() async {
    stops++;
    isListening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancels++;
    isListening = false;
  }
}
