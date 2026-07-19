import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/services/firebase_emulator_bootstrap.dart';

void main() {
  group('resolveFirebaseEmulatorConfiguration', () {
    test('uses Android host loopback alias for a native emulator', () {
      final configuration = resolveFirebaseEmulatorConfiguration(
        isWeb: false,
        platform: TargetPlatform.android,
      );

      expect(configuration.host, '10.0.2.2');
      expect(configuration.authPort, 9099);
      expect(configuration.firestorePort, 8080);
      expect(configuration.functionsPort, 5001);
    });

    test('uses localhost on web and other platforms', () {
      for (final platform in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        final configuration = resolveFirebaseEmulatorConfiguration(
          isWeb: true,
          platform: platform,
        );

        expect(configuration.host, 'localhost');
      }

      final iosConfiguration = resolveFirebaseEmulatorConfiguration(
        isWeb: false,
        platform: TargetPlatform.iOS,
      );
      expect(iosConfiguration.host, 'localhost');
    });
  });

  group('configureFirebaseEmulators', () {
    test('does nothing when opt-in is disabled', () async {
      final connector = _RecordingEmulatorConnector();

      final enabled = await configureFirebaseEmulators(
        enabled: false,
        isWeb: false,
        platform: TargetPlatform.android,
        connector: connector,
      );

      expect(enabled, isFalse);
      expect(connector.calls, isEmpty);
    });

    test('connects Auth, Firestore and Functions in bootstrap order', () async {
      final connector = _RecordingEmulatorConnector();

      final enabled = await configureFirebaseEmulators(
        enabled: true,
        isWeb: false,
        platform: TargetPlatform.android,
        connector: connector,
      );

      expect(enabled, isTrue);
      expect(connector.calls, <String>[
        'auth:10.0.2.2:9099',
        'firestore:10.0.2.2:8080',
        'functions:10.0.2.2:5001',
      ]);
    });
  });
}

class _RecordingEmulatorConnector implements FirebaseEmulatorConnector {
  final List<String> calls = <String>[];

  @override
  Future<void> connectAuth(String host, int port) async {
    calls.add('auth:$host:$port');
  }

  @override
  void connectFirestore(String host, int port) {
    calls.add('firestore:$host:$port');
  }

  @override
  void connectFunctions(String host, int port) {
    calls.add('functions:$host:$port');
  }
}
