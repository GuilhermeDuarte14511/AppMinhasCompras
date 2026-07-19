import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

const String _webAppCheckSiteKey = String.fromEnvironment(
  'FIREBASE_WEB_APP_CHECK_SITE_KEY',
);

@visibleForTesting
bool supportsFirebaseAppCheck({
  required bool isWeb,
  required TargetPlatform platform,
  required String webSiteKey,
  bool useFirebaseEmulators = false,
}) {
  if (useFirebaseEmulators) {
    return true;
  }
  if (isWeb) {
    return webSiteKey.trim().isNotEmpty;
  }
  return switch (platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => true,
    TargetPlatform.fuchsia ||
    TargetPlatform.linux ||
    TargetPlatform.windows => false,
  };
}

Future<bool> activateFirebaseAppCheck({
  bool useFirebaseEmulators = false,
}) async {
  if (useFirebaseEmulators) {
    debugPrint('[AppCheck] modo emulador: atestação de produção desabilitada.');
    return true;
  }

  if (!supportsFirebaseAppCheck(
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    webSiteKey: _webAppCheckSiteKey,
    useFirebaseEmulators: useFirebaseEmulators,
  )) {
    debugPrint(
      '[AppCheck] indisponível nesta plataforma ou sem configuração web; '
      'backend Cosmos continuará protegido por autenticação e limites.',
    );
    return false;
  }

  try {
    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_webAppCheckSiteKey.trim()),
      );
      return true;
    }

    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    return true;
  } catch (error) {
    debugPrint(
      '[AppCheck] ativação falhou (${error.runtimeType}); '
      'backend Cosmos continuará protegido por autenticação e limites.',
    );
    return false;
  }
}
