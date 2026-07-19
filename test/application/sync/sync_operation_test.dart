import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_operation.dart';

void main() {
  group('SyncOperation', () {
    test('freezes payload recursively', () {
      final tags = <Object?>['mercado'];
      final source = <String, Object?>{
        'name': 'Leite',
        'metadata': <String, Object?>{'tags': tags},
      };

      final operation = _operation(payload: source);
      tags.add('urgente');
      source['name'] = 'Alterado';

      expect(operation.payload['name'], 'Leite');
      final metadata = operation.payload['metadata']! as Map<String, Object?>;
      expect(metadata['tags'], ['mercado']);
      expect(() => operation.payload['new'] = true, throwsUnsupportedError);
      expect(
        () => (metadata['tags']! as List<Object?>).add('outro'),
        throwsUnsupportedError,
      );
    });

    test('keeps identity and increments attempts when scheduling retry', () {
      final operation = _operation();
      final retryAt = DateTime.utc(2026, 7, 19, 12);

      final retried = operation.scheduleRetry(retryAt);

      expect(retried.operationId, operation.operationId);
      expect(retried.revision, operation.revision);
      expect(retried.attempts, 1);
      expect(retried.nextAttemptAt, retryAt);
      expect(retried.payload, same(operation.payload));
    });

    test('rejects blank identity and unsupported payload values', () {
      expect(() => _operation(operationId: '  '), throwsArgumentError);
      expect(
        () => _operation(payload: {'createdAt': DateTime(2026)}),
        throwsArgumentError,
      );
      expect(
        () => _operation(payload: {'value': double.infinity}),
        throwsArgumentError,
      );
    });
  });
}

SyncOperation _operation({
  String operationId = 'operation-1',
  Map<String, Object?> payload = const {'name': 'Leite'},
}) {
  return SyncOperation(
    operationId: operationId,
    aggregateType: 'shopping-list',
    aggregateId: 'list-1',
    revision: 1,
    kind: SyncOperationKind.upsert,
    payload: payload,
    occurredAt: DateTime.utc(2026, 7, 19, 10),
  );
}
