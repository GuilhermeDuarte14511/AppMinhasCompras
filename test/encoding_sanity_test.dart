import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('source files do not contain mojibake patterns', () {
    final root = Directory.current.path;
    final suspiciousPattern = RegExp(r'Ã[\x80-\xBF]|Â[\x80-\xBF]|â[\x80-\xBF]|�');
    final failures = <String>[];

    final libDir = Directory('$root\\lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final content = entity.readAsStringSync();
      if (suspiciousPattern.hasMatch(content)) {
        failures.add(entity.path.replaceFirst('$root\\', ''));
      }
    }

    final firestoreRules = File('$root\\firestore.rules');
    if (firestoreRules.existsSync()) {
      final content = firestoreRules.readAsStringSync();
      if (suspiciousPattern.hasMatch(content)) {
        failures.add('firestore.rules');
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'Found probable text-encoding corruption (mojibake) in: ${failures.join(', ')}',
    );
  });
}
