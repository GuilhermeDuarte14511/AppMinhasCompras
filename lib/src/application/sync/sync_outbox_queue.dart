import 'dart:collection';

import 'sync_backoff_policy.dart';
import 'sync_operation.dart';
import 'sync_state.dart';

enum SyncEnqueueResult { enqueued, duplicate }

abstract interface class SyncOutboxQueue {
  SyncEnqueueResult enqueue(SyncOperation operation);

  /// Claims the oldest operation only when it is ready.
  ///
  /// A claimed operation must be acknowledged, retried, or released before
  /// another operation can be claimed.
  SyncOperation? claimNext({required DateTime now});

  void acknowledge(String operationId);

  SyncOperation scheduleRetry({
    required String operationId,
    required DateTime failedAt,
  });

  void release(String operationId);

  List<SyncOperation> get operations;

  SyncState stateAt({required DateTime now, required bool isOnline});
}

/// A process-local, globally FIFO outbox.
///
/// A delayed head blocks later operations. This preserves revision order even
/// when multiple changes target the same aggregate. Enqueuing an existing
/// [SyncOperation.operationId] is idempotent: the first operation wins.
final class InMemorySyncOutboxQueue implements SyncOutboxQueue {
  InMemorySyncOutboxQueue({
    required ExponentialBackoffPolicy backoffPolicy,
    Iterable<SyncOperation> initialOperations = const [],
  }) : _backoffPolicy = backoffPolicy {
    for (final operation in initialOperations) {
      enqueue(operation);
    }
  }

  final ExponentialBackoffPolicy _backoffPolicy;
  final LinkedHashMap<String, SyncOperation> _operations =
      LinkedHashMap<String, SyncOperation>();

  String? _inFlightOperationId;

  @override
  SyncEnqueueResult enqueue(SyncOperation operation) {
    if (_operations.containsKey(operation.operationId)) {
      return SyncEnqueueResult.duplicate;
    }
    _operations[operation.operationId] = operation;
    return SyncEnqueueResult.enqueued;
  }

  @override
  SyncOperation? claimNext({required DateTime now}) {
    if (_inFlightOperationId != null || _operations.isEmpty) {
      return null;
    }

    final operation = _operations.values.first;
    if (!operation.isReadyAt(now)) {
      return null;
    }
    _inFlightOperationId = operation.operationId;
    return operation;
  }

  @override
  void acknowledge(String operationId) {
    _requireInFlight(operationId);
    _operations.remove(operationId);
    _inFlightOperationId = null;
  }

  @override
  SyncOperation scheduleRetry({
    required String operationId,
    required DateTime failedAt,
  }) {
    final current = _requireInFlight(operationId);
    final retryAt = _backoffPolicy.nextAttemptAt(
      failedAt: failedAt,
      attempt: current.attempts + 1,
    );
    final retried = current.scheduleRetry(retryAt);
    _operations[operationId] = retried;
    _inFlightOperationId = null;
    return retried;
  }

  @override
  void release(String operationId) {
    _requireInFlight(operationId);
    _inFlightOperationId = null;
  }

  @override
  List<SyncOperation> get operations {
    return List<SyncOperation>.unmodifiable(_operations.values);
  }

  @override
  SyncState stateAt({required DateTime now, required bool isOnline}) {
    if (_operations.isEmpty) {
      return const SyncState.idle();
    }
    if (_inFlightOperationId case final operationId?) {
      return SyncState.synchronizing(
        pendingOperations: _operations.length,
        currentOperationId: operationId,
      );
    }
    if (!isOnline) {
      return SyncState.offline(pendingOperations: _operations.length);
    }

    final nextAttemptAt = _operations.values.first.nextAttemptAt;
    if (nextAttemptAt != null && nextAttemptAt.isAfter(now)) {
      return SyncState.waitingForRetry(
        pendingOperations: _operations.length,
        nextAttemptAt: nextAttemptAt,
      );
    }
    return SyncState.pending(pendingOperations: _operations.length);
  }

  SyncOperation _requireInFlight(String operationId) {
    if (_inFlightOperationId != operationId) {
      throw StateError(
        'Operation $operationId is not the operation currently in flight.',
      );
    }
    return _operations[operationId]!;
  }
}
