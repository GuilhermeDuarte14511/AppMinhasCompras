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
}
