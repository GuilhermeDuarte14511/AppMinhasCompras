import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/presentation/dialogs/sheets/barcode_scanner_sheet.dart';

void main() {
  test('scanner lifecycle only stops on inactive state', () {
    expect(
      shouldStopBarcodeScannerForLifecycle(AppLifecycleState.inactive),
      isTrue,
    );
    expect(
      shouldStopBarcodeScannerForLifecycle(AppLifecycleState.paused),
      isFalse,
    );
    expect(
      shouldStopBarcodeScannerForLifecycle(AppLifecycleState.hidden),
      isFalse,
    );
    expect(
      shouldStopBarcodeScannerForLifecycle(AppLifecycleState.detached),
      isFalse,
    );
    expect(
      shouldStopBarcodeScannerForLifecycle(AppLifecycleState.resumed),
      isFalse,
    );
  });

  test('web and iOS scanner recovery release the camera before restart', () {
    expect(
      barcodeScannerRestartDelay(
        isWeb: true,
        targetPlatform: TargetPlatform.iOS,
      ),
      greaterThan(Duration.zero),
    );
    expect(
      barcodeScannerRestartDelay(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      greaterThan(Duration.zero),
    );
    expect(
      barcodeScannerRestartDelay(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      Duration.zero,
    );
  });

  test('web scanner recovery hint explains the iPhone PWA fallback', () {
    final hint = barcodeScannerRecoveryHint(isWeb: true);

    expect(hint, contains('iPhone'));
    expect(hint, contains('Safari'));
    expect(hint, contains('Tela de Início'));
  });

  test('web and iOS scanner open fullscreen without clipping the camera', () {
    expect(
      shouldUseFullScreenBarcodeScanner(
        isWeb: true,
        targetPlatform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      shouldUseFullScreenBarcodeScanner(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      isTrue,
    );
    expect(
      shouldUseFullScreenBarcodeScanner(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      isFalse,
    );
    expect(barcodeScannerViewportRadius(isFullScreen: true), 0);
    expect(barcodeScannerViewportRadius(isFullScreen: false), greaterThan(0));
  });

  test('iOS and web hard restart recreate the camera session', () {
    expect(
      shouldRecreateBarcodeScannerOnRestart(
        isWeb: true,
        targetPlatform: TargetPlatform.android,
      ),
      isTrue,
    );
    expect(
      shouldRecreateBarcodeScannerOnRestart(
        isWeb: false,
        targetPlatform: TargetPlatform.iOS,
      ),
      isTrue,
    );
    expect(
      shouldRecreateBarcodeScannerOnRestart(
        isWeb: false,
        targetPlatform: TargetPlatform.android,
      ),
      isFalse,
    );
  });
}
