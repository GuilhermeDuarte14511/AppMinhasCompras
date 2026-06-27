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

  test('web scanner recovery hint mentions browser refresh options', () {
    final hint = barcodeScannerRecoveryHint(isWeb: true);

    expect(hint, contains('navegador'));
    expect(hint, contains('recarregue'));
  });
}
