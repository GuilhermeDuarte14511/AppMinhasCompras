import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/barcode_scanner_sheet.dart';
import 'package:lista_compras_material/src/presentation/theme/editorial_workspace_theme.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  late MobileScannerPlatform original;
  late _ScannerPlatform platform;
  setUpAll(() async {
    for (final font in {
      'MercadoPublicSans': 'assets/fonts/PublicSans.ttf',
      'MercadoNewsreader': 'assets/fonts/Newsreader.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });
  setUp(() {
    original = MobileScannerPlatform.instance;
    platform = _ScannerPlatform();
    MobileScannerPlatform.instance = platform;
  });
  tearDown(() {
    MobileScannerPlatform.instance = original;
  });

  testWidgets('scanner editorial golden shows only running camera truth', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Câmera ativa'), findsOneWidget);
    expect(find.textContaining('Acesso à câmera concedido'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/barcode_scanner_stitch_390.png'),
    );
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pumpAndSettle();
    expect(platform.stops, greaterThan(0));
  });

  testWidgets('detected valid code returns sanitized value and stops camera', (
    tester,
  ) async {
    String? result;
    await _open(tester, onResult: (value) => result = value);
    platform.codes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: null)]),
    );
    await tester.pump();
    expect(find.text('Leitor de código'), findsOneWidget);
    platform.codes.add(
      const BarcodeCapture(barcodes: [Barcode(rawValue: '7891234567890')]),
    );
    await tester.pumpAndSettle();
    expect(result, '7891234567890');
    expect(platform.stops, greaterThan(0));
  });

  testWidgets('manual escape cancels scanner without fabricating a code', (
    tester,
  ) async {
    String? result = 'sentinel';
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Digitar manualmente'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(platform.stops, greaterThan(0));
  });

  testWidgets('permission denied has recovery and never claims active', (
    tester,
  ) async {
    platform.denied = true;
    await _open(tester);
    expect(find.text('Câmera ativa'), findsNothing);
    expect(find.textContaining('Acesso à câmera concedido'), findsNothing);
    expect(find.textContaining('A câmera está bloqueada'), findsOneWidget);
    platform.denied = false;
    await tester.tap(find.text('Reabrir câmera'));
    await tester.pumpAndSettle();
    expect(find.text('Câmera ativa'), findsOneWidget);
    expect(platform.starts, 2);
  });

  testWidgets('switch and restart preserve camera controls', (tester) async {
    await _open(tester);
    await tester.tap(find.byTooltip('Trocar câmera'));
    await tester.pumpAndSettle();
    expect(platform.facing, CameraFacing.front);
    await tester.tap(find.text('Reabrir câmera'));
    await tester.pumpAndSettle();
    expect(platform.starts, 3);
  });

  testWidgets('camera startup never reports granted access before completion', (
    tester,
  ) async {
    platform.startGate = Completer<void>();
    await _open(tester);
    expect(find.text('Abrindo câmera...'), findsOneWidget);
    expect(find.text('Câmera ativa'), findsNothing);
    expect(find.textContaining('Aguardando acesso'), findsOneWidget);
    platform.startGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Câmera ativa'), findsOneWidget);
  });

  testWidgets('compact dark enlarged sheet keeps actions above keyboard', (
    tester,
  ) async {
    platform.denied = true;
    await _open(
      tester,
      size: const Size(320, 568),
      scale: 1.5,
      dark: true,
      keyboard: 210,
    );
    expect(tester.takeException(), isNull);
    final permissionText = tester.widget<EditableText>(
      find.textContaining('A câmera está bloqueada'),
    );
    expect(permissionText.style.color, const Color(0xFFF3F1EB));
    for (final title in ['Reabrir câmera', 'Digitar manualmente']) {
      final rect = tester.getRect(
        find
            .ancestor(
              of: find.text(title),
              matching: find.byWidgetPredicate(
                (widget) => widget is ButtonStyleButton,
              ),
            )
            .first,
      );
      expect(rect.bottom, lessThanOrEqualTo(358));
      expect(rect.height, greaterThanOrEqualTo(48));
    }
    await tester.tap(find.text('Digitar manualmente'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('full screen scanner fits safe area and enlarged text', (
    tester,
  ) async {
    await _open(
      tester,
      size: const Size(320, 568),
      scale: 1.5,
      fullScreen: true,
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .getRect(find.widgetWithText(FilledButton, 'Digitar manualmente'))
          .bottom,
      lessThanOrEqualTo(544),
    );
  });

  testWidgets('full screen keyboard is compensated exactly once', (
    tester,
  ) async {
    await _open(
      tester,
      size: const Size(320, 568),
      scale: 1.5,
      fullScreen: true,
      keyboard: 210,
    );
    expect(tester.takeException(), isNull);
    final button = tester.getRect(
      find.widgetWithText(FilledButton, 'Digitar manualmente'),
    );
    expect(button.bottom, lessThanOrEqualTo(358));
    expect(button.top, greaterThan(100));
  });
}

Future<void> _open(
  WidgetTester tester, {
  ValueChanged<String?>? onResult,
  Size size = const Size(390, 844),
  double scale = 1,
  bool dark = false,
  double keyboard = 0,
  bool fullScreen = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: editorialWorkspaceTheme(
        ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: fullScreen
              ? const EdgeInsets.only(top: 24, bottom: 24)
              : EdgeInsets.zero,
          viewPadding: fullScreen
              ? const EdgeInsets.only(top: 24, bottom: 24)
              : EdgeInsets.zero,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = fullScreen
                  ? await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const BarcodeScannerPage(),
                      ),
                    )
                  : await showBarcodeScannerSheet(context);
              onResult?.call(result);
            },
            child: const Text('Abrir leitor'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir leitor'));
  await tester.pumpAndSettle();
}

// The camera surface and hardware live only in this test platform.
class _ScannerPlatform extends MobileScannerPlatform {
  final codes = StreamController<BarcodeCapture?>.broadcast();
  bool denied = false;
  int starts = 0;
  int stops = 0;
  CameraFacing facing = CameraFacing.back;
  Completer<void>? startGate;

  @override
  Stream<BarcodeCapture?> get barcodesStream => codes.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Color(0xFF30312D));
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    starts++;
    await startGate?.future;
    if (denied) {
      throw const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
    }
    facing = options.cameraDirection;
    return MobileScannerViewAttributes(
      cameraDirection: facing,
      currentTorchMode: TorchState.off,
      size: const Size(640, 480),
      numberOfCameras: 2,
    );
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
}
