import 'dart:async';
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

  testWidgets('active capture reflects service and live transcript', (
    tester,
  ) async {
    _size(tester, const Size(390, 884));
    final voice = _Voice();
    await _open(tester, service: voice, autoStart: true);
    voice.result!(
      const ShoppingVoiceRecognitionUpdate(
        words: 'dois detergentes, um arroz e três sabonetes',
        isFinal: false,
      ),
    );
    await tester.pump();
    expect(find.text('Ouvindo… toque para parar'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Analisar itens'),
          )
          .onPressed,
      isNull,
    );
    expect(tester.getSize(find.byTooltip('Parar de ouvir')).width, 80);
    await expectLater(
      find.byType(BottomSheet),
      matchesGoldenFile('goldens/voice_capture_listening_stitch_390.png'),
    );
    await tester.tap(find.byTooltip('Parar de ouvir'));
    await tester.pumpAndSettle();
    expect(voice.stops, 1);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Analisar itens'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'pending initialization blocks analysis and closing prevents late start',
    (tester) async {
      final pending = Completer<bool>();
      final voice = _Voice(pendingInitialization: pending);
      await _open(tester, service: voice);
      await tester.tap(find.byTooltip('Começar a ouvir'));
      await tester.pump();
      expect(find.text('Preparando microfone…'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Analisar itens'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Fechar voz'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(voice.starts, 0);
      expect(voice.cancels, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('service Future exceptions recover to manual entry and retry', (
    tester,
  ) async {
    final voice = _Voice(throwPhase: 'initialize');
    await _open(tester, service: voice, autoStart: true);
    expect(find.textContaining('está sem conexão'), findsOneWidget);
    voice.throwPhase = 'start';
    await tester.tap(find.byTooltip('Começar a ouvir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permita o acesso'), findsOneWidget);
    voice.throwPhase = null;
    await tester.tap(find.byTooltip('Começar a ouvir'));
    await tester.pumpAndSettle();
    voice.throwPhase = 'stop';
    await tester.tap(find.byTooltip('Parar de ouvir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('está sem conexão'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'dois leites');
    await tester.tap(find.text('Analisar itens'));
    await tester.pumpAndSettle();
    expect(find.text('Leite integral'), findsNWidgets(2));
    expect(find.textContaining('2 un.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty transcript validates and callbacks after disposal are ignored',
    (tester) async {
      final voice = _Voice();
      await _open(tester, service: voice);
      await tester.tap(find.text('Analisar itens'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ao menos um produto'), findsOneWidget);
      await tester.tap(find.byTooltip('Começar a ouvir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar voz'));
      await tester.pumpAndSettle();
      voice.result!(
        const ShoppingVoiceRecognitionUpdate(words: 'um leite', isFinal: true),
      );
      voice.error!('permission_denied');
      voice.status!('done');
      await tester.pump();
      expect(voice.cancels, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact dark capture keeps footer above keyboard and shows focus',
    (tester) async {
      _size(tester, const Size(320, 568));
      await _open(tester, dark: true, scale: 1.5);
      tester.view.viewInsets = const FakeViewPadding(bottom: 210);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'um leite');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      final action = find.widgetWithText(OutlinedButton, 'Analisar itens');
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(358));
      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/voice_capture_dark_keyboard_320.png'),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(action);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Leite integral'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
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
  _Voice({this.pendingInitialization, this.throwPhase});
  final Completer<bool>? pendingInitialization;
  String? throwPhase;

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
    if (throwPhase == 'initialize') throw StateError('network_error');
    return pendingInitialization == null ? true : pendingInitialization!.future;
  }

  @override
  Future<void> startListening({
    required void Function(ShoppingVoiceRecognitionUpdate) onResult,
    String localeId = 'pt_BR',
  }) async {
    starts++;
    if (throwPhase == 'start') throw StateError('permission_denied');
    isListening = true;
    result = onResult;
  }

  @override
  Future<void> stopListening() async {
    stops++;
    if (throwPhase == 'stop') throw StateError('network_error');
    isListening = false;
  }

  @override
  Future<void> cancelListening() async {
    cancels++;
    isListening = false;
  }
}
