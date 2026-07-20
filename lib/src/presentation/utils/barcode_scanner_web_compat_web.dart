import 'dart:async';
import 'dart:js_interop';

@JS('shoppingCameraCompat.prepare')
external void _prepareCameraVideo();

Future<void> prepareBarcodeScannerWebVideo() async {
  for (final delay in const [
    Duration.zero,
    Duration(milliseconds: 100),
    Duration(milliseconds: 350),
  ]) {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }

    try {
      _prepareCameraVideo();
    } on Object {
      // The scanner still owns error reporting if the compatibility helper
      // is unavailable, for example in a unit-test document.
      return;
    }
  }
}
