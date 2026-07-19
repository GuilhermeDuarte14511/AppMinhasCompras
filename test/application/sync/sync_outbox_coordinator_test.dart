import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_operation.dart';
import 'package:lista_compras_material/src/application/sync/sync_outbox_coordinator.dart';
import 'package:lista_compras_material/src/application/sync/sync_outbox_queue.dart';
import 'package:lista_compras_material/src/application/sync/sync_outbox_storage.dart';

void main() {
  late _MemorySyncOutboxStorage storage;
  late SyncOutboxCoordinator coordinator;

  setUp(() {
    storage = _MemorySyncOutboxStorage();
    coordinator = SyncOutboxCoordinator(storage: storage, clock: () => _now);
  });

  test('serializes concurrent enqueue operations for the same user', () async {
    final results = await Future.wait([
      coordinator.enqueue(
        userId: 'user-1',
        operation: _operation('operation-1', revision: 1),
      ),
      coordinator.enqueue(
        userId: 'user-1',
        operation: _operation('operation-2', revision: 2),
      ),
    ]);

    expect(results, [SyncEnqueueResult.enqueued, SyncEnqueueResult.enqueued]);
    expect(
      (await coordinator.pending(
        userId: 'user-1',
      )).map((operation) => operation.operationId),
      ['operation-1', 'operation-2'],
    );
  });

  test('enqueue is idempotent by operation id', () async {
    final operation = _operation('operation-1', revision: 1);

    await coordinator.enqueue(userId: 'user-1', operation: operation);
    final result = await coordinator.enqueue(
      userId: 'user-1',
      operation: operation,
    );

    expect(result, SyncEnqueueResult.duplicate);
    expect(await coordinator.pending(userId: 'user-1'), hasLength(1));
  });

  test('acknowledges only operations captured before push', () async {
    await coordinator.enqueue(
      userId: 'user-1',
      operation: _operation('operation-1', revision: 1),
    );
    final batch = await coordinator.captureForPush(userId: 'user-1');

    await coordinator.enqueue(
      userId: 'user-1',
      operation: _operation('operation-2', revision: 2),
    );
    final removed = await coordinator.acknowledge(batch);

    expect(removed, 1);
    final pending = await coordinator.pending(userId: 'user-1');
    expect(pending.single.operationId, 'operation-2');
    expect(pending.single.revision, 2);
  });

  test('does not acknowledge a changed revision with the same id', () async {
    await coordinator.enqueue(
      userId: 'user-1',
      operation: _operation('operation-1', revision: 1),
    );
    final batch = await coordinator.captureForPush(userId: 'user-1');
    await storage.save(
      userId: 'user-1',
      operations: [_operation('operation-1', revision: 2)],
    );

    final removed = await coordinator.acknowledge(batch);

    expect(removed, 0);
    expect((await coordinator.pending(userId: 'user-1')).single.revision, 2);
  });

  test('captures a bounded FIFO batch and its highest revisions', () async {
    await coordinator.enqueue(
      userId: 'user-1',
      operation: _operation('operation-1', revision: 1),
    );
    await coordinator.enqueue(
      userId: 'user-1',
      operation: _operation('operation-2', revision: 2),
    );

    final batch = await coordinator.captureForPush(
      userId: 'user-1',
      maxOperations: 1,
    );

    expect(batch.operations.single.operationId, 'operation-1');
    expect(batch.capturedAt, _now);
    expect(
      batch.highestCapturedRevisionFor(
        aggregateType: 'shopping-list',
        aggregateId: 'list-1',
      ),
      1,
    );
  });
}

final _now = DateTime.utc(2026, 7, 19, 10);

SyncOperation _operation(String operationId, {required int revision}) {
  return SyncOperation(
    operationId: operationId,
    aggregateType: 'shopping-list',
    aggregateId: 'list-1',
    revision: revision,
    kind: SyncOperationKind.upsert,
    payload: {'revision': revision},
    occurredAt: _now,
  );
}

final class _MemorySyncOutboxStorage implements SyncOutboxStorage {
  final Map<String, List<SyncOperation>> _operationsByUser = {};

  @override
  Future<void> clear({required String userId}) async {
    await Future<void>.delayed(Duration.zero);
    _operationsByUser.remove(userId);
  }

  @override
  Future<List<SyncOperation>> load({required String userId}) async {
    await Future<void>.delayed(Duration.zero);
    return List<SyncOperation>.of(_operationsByUser[userId] ?? const []);
  }

  @override
  Future<void> save({
    required String userId,
    required List<SyncOperation> operations,
  }) async {
    await Future<void>.delayed(Duration.zero);
    _operationsByUser[userId] = List<SyncOperation>.of(operations);
  }
}
