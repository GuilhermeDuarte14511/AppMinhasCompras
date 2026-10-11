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
    platform = _ScannerPlatform()..denied = true;
    MobileScannerPlatform.instance = platform;
  });
  tearDown(() => MobileScannerPlatform.instance = original);

  test('permission recovery instructions follow the actual platform', () {
    String message({
      bool web = false,
      TargetPlatform target = TargetPlatform.android,
    }) => barcodeScannerErrorMessage(
      MobileScannerErrorCode.permissionDenied,
      isWeb: web,
      targetPlatform: target,
    );
    expect(message(), contains('Configurações > Aplicativos'));
    expect(message(), isNot(contains('Ajustes')));
    expect(message(target: TargetPlatform.iOS), contains('Ajustes >'));
    expect(
      message(web: true, target: TargetPlatform.iOS),
      contains('deste site'),
    );
    expect(message(web: true), isNot(contains('Aplicativos')));
    expect(
      barcodeScannerErrorMessage(
        MobileScannerErrorCode.unsupported,
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      contains('Nenhuma câmera'),
    );
  });
  testWidgets('permission error follows Stitch with truthful recovery', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Câmera indisponível agora'), findsOneWidget);
    expect(find.byTooltip('Trocar câmera'), findsNothing);
    expect(find.text('Câmera ativa'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Reabrir câmera'), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, 'Digitar manualmente'),
      findsOneWidget,
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/barcode_scanner_error_stitch_390.png'),
    );
    platform.denied = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(platform.starts, 2);
    expect(find.text('Câmera ativa'), findsOneWidget);
    expect(find.text('Câmera indisponível agora'), findsNothing);
  });
  testWidgets('repeated denied retry remains recoverable and manual cancels', (
    tester,
  ) async {
    String? result = 'sentinel';
    await _open(tester, onResult: (value) => result = value);
    await tester.tap(find.text('Reabrir câmera'));
    await tester.pumpAndSettle();
    expect(find.text('Câmera indisponível agora'), findsOneWidget);
    expect(platform.starts, 2);
    await tester.tap(find.text('Digitar manualmente'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing during pending camera startup is safe', (tester) async {
    platform.denied = false;
    platform.startGate = Completer<void>();
    await _open(tester);
    await tester.tap(find.text('Digitar manualmente'));
    await tester.pumpAndSettle();
    platform.startGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Leitor de código'), findsNothing);
    expect(tester.takeException(), isNull);
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
