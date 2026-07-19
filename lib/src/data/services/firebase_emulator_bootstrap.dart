import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

const bool useFirebaseEmulators = bool.fromEnvironment(
  'USE_FIREBASE_EMULATORS',
  defaultValue: false,
);

class FirebaseEmulatorConfiguration {
  const FirebaseEmulatorConfiguration({
    required this.host,
    this.authPort = 9099,
    this.firestorePort = 8080,
    this.functionsPort = 5001,
  });

  final String host;
  final int authPort;
  final int firestorePort;
  final int functionsPort;
}

abstract interface class FirebaseEmulatorConnector {
  Future<void> connectAuth(String host, int port);

  void connectFirestore(String host, int port);

  void connectFunctions(String host, int port);
}

@visibleForTesting
FirebaseEmulatorConfiguration resolveFirebaseEmulatorConfiguration({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  final isAndroidEmulator = !isWeb && platform == TargetPlatform.android;
  return FirebaseEmulatorConfiguration(
    host: isAndroidEmulator ? '10.0.2.2' : 'localhost',
  );
}

Future<bool> configureFirebaseEmulators({
  bool enabled = useFirebaseEmulators,
  bool? isWeb,
  TargetPlatform? platform,
  FirebaseEmulatorConnector? connector,
}) async {
  if (!enabled) {
    return false;
  }

  final resolvedIsWeb = isWeb ?? kIsWeb;
  final resolvedPlatform = platform ?? defaultTargetPlatform;
  final configuration = resolveFirebaseEmulatorConfiguration(
    isWeb: resolvedIsWeb,
    platform: resolvedPlatform,
  );
  final emulatorConnector = connector ?? _FlutterFireEmulatorConnector();

  await emulatorConnector.connectAuth(
    configuration.host,
    configuration.authPort,
  );
  emulatorConnector.connectFirestore(
    configuration.host,
    configuration.firestorePort,
  );
  emulatorConnector.connectFunctions(
    configuration.host,
    configuration.functionsPort,
  );

  debugPrint(
    '[Firebase] emuladores habilitados em ${configuration.host} '
    '(Auth ${configuration.authPort}, Firestore '
    '${configuration.firestorePort}, Functions '
    '${configuration.functionsPort}).',
  );
  return true;
}

class _FlutterFireEmulatorConnector implements FirebaseEmulatorConnector {
  static const String _functionsRegion = 'southamerica-east1';

  @override
  Future<void> connectAuth(String host, int port) {
    return FirebaseAuth.instance.useAuthEmulator(host, port);
  }

  @override
  void connectFirestore(String host, int port) {
    FirebaseFirestore.instance.useFirestoreEmulator(host, port);
  }

  @override
  void connectFunctions(String host, int port) {
    FirebaseFunctions.instanceFor(
      region: _functionsRegion,
    ).useFunctionsEmulator(host, port);
  }
}
