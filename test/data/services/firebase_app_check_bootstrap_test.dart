import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/services/firebase_app_check_bootstrap.dart';

void main() {
  group('supportsFirebaseAppCheck', () {
    test('allows local emulator mode without production configuration', () {
      expect(
        supportsFirebaseAppCheck(
          isWeb: true,
          platform: TargetPlatform.windows,
          webSiteKey: '',
          useFirebaseEmulators: true,
        ),
        isTrue,
      );
    });

    test('requires a configured provider key on web', () {
      expect(
        supportsFirebaseAppCheck(
          isWeb: true,
          platform: TargetPlatform.android,
          webSiteKey: ' ',
        ),
        isFalse,
      );
      expect(
        supportsFirebaseAppCheck(
          isWeb: true,
          platform: TargetPlatform.android,
          webSiteKey: 'configured-site-key',
        ),
        isTrue,
      );
    });

    test('supports native Android and Apple platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      ]) {
        expect(
          supportsFirebaseAppCheck(
            isWeb: false,
            platform: platform,
            webSiteKey: '',
          ),
          isTrue,
          reason: '$platform should support attestation',
        );
      }
    });

    test('disables protected calls on unsupported desktop platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          supportsFirebaseAppCheck(
            isWeb: false,
            platform: platform,
            webSiteKey: '',
          ),
          isFalse,
          reason: '$platform should use the Open Facts fallback',
        );
      }
    });
  });
}
