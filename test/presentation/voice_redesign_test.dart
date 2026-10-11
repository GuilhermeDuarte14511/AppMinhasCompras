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
  testWidgets('voice capture and review mobile editorial references', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    await _open(tester, transcript: 'dois leites, um café');
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/voice_capture_stitch_390.png'),
    );
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/voice_review_stitch_390.png'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('speech starts stops and final result enables review', (
    tester,
  ) async {
    final service = _Voice();
    await _open(tester, service: service, autoStart: true);
    expect(service.starts, 1);
    expect(find.text('Ouvindo… toque para parar'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Analisar itens'),
          )
          .onPressed,
      isNull,
    );
    service.result!(
      const ShoppingVoiceRecognitionUpdate(
        words: 'dois leites',
        isFinal: false,
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(TextField, 'dois leites'), findsOneWidget);
    await tester.tap(find.byTooltip('Parar de ouvir'));
    await tester.pumpAndSettle();
    expect(service.stops, 1);
    await tester.tap(find.byTooltip('Começar a ouvir'));
    await tester.pumpAndSettle();
    service.result!(
      const ShoppingVoiceRecognitionUpdate(words: 'dois leites', isFinal: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    expect(find.text('Leite integral'), findsNWidgets(2));
    await tester.tap(find.text('Ouvir novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar voz'));
    await tester.pumpAndSettle();
    expect(service.cancels, 1);
  });

  testWidgets('unavailable microphone preserves typed fallback', (
    tester,
  ) async {
    await _open(tester, service: _Voice(available: false), autoStart: true);
    expect(find.textContaining('não está disponível'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'um leite');
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    expect(find.text('Leite integral'), findsNWidgets(2));
  });

  testWidgets('permission network no match and timeout keep controls usable', (
    tester,
  ) async {
    final service = _Voice();
    await _open(tester, service: service, autoStart: true);
    final messages = {
      'permission_denied': 'Permita o acesso ao microfone',
      'network_error': 'está sem conexão',
      'no_match': 'Não consegui entender',
      'speech_timeout': 'Não foi possível ouvir agora',
    };
    for (final entry in messages.entries) {
      service.error!(entry.key);
      await tester.pumpAndSettle();
      expect(find.textContaining(entry.value), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Analisar itens'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Começar a ouvir'));
      await tester.pumpAndSettle();
    }
    service.status!('done');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Começar a ouvir'), findsOneWidget);
  });

  testWidgets(
    'deselection returns only chosen drafts and can recover zero selection',
    (tester) async {
      List<ShoppingItemDraft>? result;
      await _open(
        tester,
        transcript: 'dois leites, um café',
        onResult: (value) => result = value,
      );
      await tester.tap(find.text('Analisar itens'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox).first);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Nenhum produto selecionado'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar 1 produto'));
      await tester.pumpAndSettle();
      expect(result, hasLength(1));
      expect(result!.single.name, 'Café torrado');
      expect(result!.single.unitPrice, 18.9);
    },
  );

  testWidgets('compact dark capture and review work with large text keyboard', (
    tester,
  ) async {
    _size(tester, const Size(320, 568));
    await _open(tester, dark: true, scale: 1.5);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(TextField));
    await tester.enterText(find.byType(TextField), 'um leite');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Analisar itens'));
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Adicionar 1 produto'), findsOneWidget);
    await tester.tap(find.byTooltip('Ouvir novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('capture leaves room for device bottom navigation', (
    tester,
  ) async {
    _size(tester, const Size(390, 568));
    tester.view.viewPadding = const FakeViewPadding(bottom: 40);
    tester.view.padding = const FakeViewPadding(bottom: 40);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    await _open(tester, transcript: 'um leite');
    await tester.ensureVisible(find.text('Analisar itens'));
    final action = tester.getBottomRight(
      find.widgetWithText(OutlinedButton, 'Analisar itens'),
    );
    expect(action.dy, lessThanOrEqualTo(528));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getBottomRight(
            find.widgetWithText(FilledButton, 'Adicionar 1 produto'),
          )
          .dy,
      lessThanOrEqualTo(528),
    );
  });
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
                  catalogProducts: [
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
                  currentItems: const [],
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
  _Voice({this.available = true});
  final bool available;
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
