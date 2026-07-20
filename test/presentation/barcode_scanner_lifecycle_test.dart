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

  test('web scanner recovery uses a clean restart delay', () {
    expect(barcodeScannerRestartDelay(isWeb: true), greaterThan(Duration.zero));
    expect(barcodeScannerRestartDelay(isWeb: false), Duration.zero);
  });

  test('web scanner recovery hint explains the iPhone PWA fallback', () {
    final hint = barcodeScannerRecoveryHint(isWeb: true);

    expect(hint, contains('iPhone'));
    expect(hint, contains('Safari'));
    expect(hint, contains('Tela de Início'));
  });

  test('web scanner opens fullscreen without clipping the camera view', () {
    expect(shouldUseFullScreenBarcodeScanner(isWeb: true), isTrue);
    expect(shouldUseFullScreenBarcodeScanner(isWeb: false), isFalse);
    expect(barcodeScannerViewportRadius(isFullScreen: true), 0);
    expect(barcodeScannerViewportRadius(isFullScreen: false), greaterThan(0));
  });
}
