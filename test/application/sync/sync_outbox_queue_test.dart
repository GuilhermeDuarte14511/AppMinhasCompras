import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/sync_backoff_policy.dart';
import 'package:lista_compras_material/src/application/sync/sync_operation.dart';
import 'package:lista_compras_material/src/application/sync/sync_outbox_queue.dart';
import 'package:lista_compras_material/src/application/sync/sync_state.dart';

void main() {
  late InMemorySyncOutboxQueue queue;

  setUp(() {
    queue = InMemorySyncOutboxQueue(
      backoffPolicy: ExponentialBackoffPolicy(
        baseDelay: const Duration(seconds: 2),
        maxDelay: const Duration(minutes: 1),
        jitterSampler: () => 1,
      ),
    );
  });

  test('enqueues idempotently and processes one operation at a time', () {
    final first = _operation('operation-1', revision: 1);
    final second = _operation('operation-2', revision: 2);
    queue.enqueue(first);
    queue.enqueue(second);

    expect(queue.enqueue(first), SyncEnqueueResult.duplicate);
    expect(queue.claimNext(now: _now), same(first));
    expect(queue.claimNext(now: _now), isNull);

    queue.acknowledge(first.operationId);

    expect(queue.claimNext(now: _now), same(second));
    expect(queue.operations, [second]);
  });

  test('failed head waits for backoff and blocks later revisions', () {
    final first = _operation('operation-1', revision: 1);
    final second = _operation('operation-2', revision: 2);
    queue.enqueue(first);
    queue.enqueue(second);
    queue.claimNext(now: _now);

    final retried = queue.scheduleRetry(
      operationId: first.operationId,
      failedAt: _now,
    );

    expect(retried.attempts, 1);
    expect(retried.nextAttemptAt, _now.add(const Duration(seconds: 2)));
    expect(
      queue.stateAt(now: _now, isOnline: true).phase,
      SyncPhase.waitingForRetry,
    );
    expect(queue.claimNext(now: _now), isNull);
    expect(
      queue.claimNext(now: _now.add(const Duration(seconds: 2)))?.operationId,
      first.operationId,
    );
  });

  test('release keeps operation and attempt count unchanged', () {
    final operation = _operation('operation-1', revision: 1);
    queue.enqueue(operation);
    queue.claimNext(now: _now);

    queue.release(operation.operationId);

    expect(queue.operations.single.attempts, 0);
    expect(queue.claimNext(now: _now), same(operation));
  });

  test('derives idle, offline, pending, and synchronizing states', () {
    expect(queue.stateAt(now: _now, isOnline: true).phase, SyncPhase.idle);

    final operation = _operation('operation-1', revision: 1);
    queue.enqueue(operation);
    expect(queue.stateAt(now: _now, isOnline: false).phase, SyncPhase.offline);
    expect(queue.stateAt(now: _now, isOnline: true).phase, SyncPhase.pending);

    queue.claimNext(now: _now);
    final syncing = queue.stateAt(now: _now, isOnline: true);
    expect(syncing.phase, SyncPhase.synchronizing);
    expect(syncing.currentOperationId, operation.operationId);
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
