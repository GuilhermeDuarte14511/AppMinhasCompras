import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_operation.dart';
import 'package:lista_compras_material/src/data/local/shared_prefs_sync_outbox_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const storage = SharedPrefsSyncOutboxStorage();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('round-trips operations and isolates users', () async {
    final operation = _operation();

    await storage.save(
      userId: 'user-a',
      operations: <SyncOperation>[operation],
    );

    final restored = await storage.load(userId: 'user-a');
    expect(restored, hasLength(1));
    expect(restored.single.operationId, operation.operationId);
    expect(restored.single.revision, operation.revision);
    expect(restored.single.kind, operation.kind);
    expect(restored.single.payload, operation.payload);
    expect(restored.single.occurredAt, operation.occurredAt);
    expect(restored.single.attempts, operation.attempts);
    expect(restored.single.nextAttemptAt, operation.nextAttemptAt);
    expect(await storage.load(userId: 'user-b'), isEmpty);
  });

  test('saving an empty outbox removes its persisted snapshot', () async {
    await storage.save(
      userId: 'user-a',
      operations: <SyncOperation>[_operation()],
    );

    await storage.save(userId: 'user-a', operations: const <SyncOperation>[]);

    expect(await storage.load(userId: 'user-a'), isEmpty);
  });

  test('does not silently discard corrupted outbox data', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'sync_outbox_v1_dXNlci1h': '{"version":1,"operations":"invalid"}',
    });

    await expectLater(
      storage.load(userId: 'user-a'),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects blank user identifiers', () async {
    await expectLater(storage.load(userId: '  '), throwsArgumentError);
  });
}

SyncOperation _operation() {
  return SyncOperation(
    operationId: 'operation-1',
    aggregateType: 'legacy-user-snapshot',
    aggregateId: 'private-data',
    revision: 3,
    kind: SyncOperationKind.upsert,
    payload: const <String, Object?>{'schemaVersion': 1},
    occurredAt: DateTime.utc(2026, 7, 19, 14),
    attempts: 2,
    nextAttemptAt: DateTime.utc(2026, 7, 19, 14, 5),
  );
}
