import 'dart:async';

import 'sync_operation.dart';
import 'sync_outbox_queue.dart';
import 'sync_outbox_storage.dart';

typedef SyncClock = DateTime Function();

final class SyncPushBatch {
  SyncPushBatch({
    required this.userId,
    required List<SyncOperation> operations,
    required this.capturedAt,
  }) : operations = List<SyncOperation>.unmodifiable(operations);

  final String userId;
  final List<SyncOperation> operations;
  final DateTime capturedAt;

  bool get isEmpty => operations.isEmpty;

  int? highestCapturedRevisionFor({
    required String aggregateType,
    required String aggregateId,
  }) {
    int? highestRevision;
    for (final operation in operations) {
      final belongsToAggregate =
          operation.aggregateType == aggregateType &&
          operation.aggregateId == aggregateId;
      if (belongsToAggregate &&
          (highestRevision == null || operation.revision > highestRevision)) {
        highestRevision = operation.revision;
      }
    }
    return highestRevision;
  }
}

/// Serializes storage mutations per user without holding a lock during a push.
///
/// A caller captures a batch, performs the remote request, and acknowledges
/// that batch afterward. Acknowledgement reloads current storage and removes
/// only the exact operation identity and revision captured. Operations
/// enqueued while the remote request is running are therefore preserved.
final class SyncOutboxCoordinator {
  SyncOutboxCoordinator({required SyncOutboxStorage storage, SyncClock? clock})
    : _storage = storage,
      _clock = clock ?? DateTime.now;

  final SyncOutboxStorage _storage;
  final SyncClock _clock;
  final Map<String, _SerialExecutor> _executors = {};

  Future<SyncEnqueueResult> enqueue({
    required String userId,
    required SyncOperation operation,
  }) {
    return _forUser(userId).run(() async {
      final current = await _storage.load(userId: userId);
      if (current.any(
        (candidate) => candidate.operationId == operation.operationId,
      )) {
        return SyncEnqueueResult.duplicate;
      }
      await _storage.save(userId: userId, operations: [...current, operation]);
      return SyncEnqueueResult.enqueued;
    });
  }

  Future<List<SyncOperation>> pending({required String userId}) {
    return _forUser(userId).run(() async {
      final current = await _storage.load(userId: userId);
      return List<SyncOperation>.unmodifiable(current);
    });
  }

  Future<SyncPushBatch> captureForPush({
    required String userId,
    int? maxOperations,
  }) {
    if (maxOperations != null && maxOperations < 1) {
      throw ArgumentError.value(
        maxOperations,
        'maxOperations',
        'Must be at least 1.',
      );
    }
    return _forUser(userId).run(() async {
      final current = await _storage.load(userId: userId);
      final captured = maxOperations == null
          ? current
          : current.take(maxOperations).toList(growable: false);
      return SyncPushBatch(
        userId: userId,
        operations: captured,
        capturedAt: _clock(),
      );
    });
  }

  Future<int> acknowledge(SyncPushBatch batch) {
    _requireUserId(batch.userId);
    return _forUser(batch.userId).run(() async {
      if (batch.isEmpty) {
        return 0;
      }

      final capturedVersions = batch.operations.map(_versionOf).toSet();
      final current = await _storage.load(userId: batch.userId);
      final remaining = current
          .where(
            (operation) => !capturedVersions.contains(_versionOf(operation)),
          )
          .toList(growable: false);
      final removedCount = current.length - remaining.length;
      if (removedCount > 0) {
        await _storage.save(userId: batch.userId, operations: remaining);
      }
      return removedCount;
    });
  }

  Future<void> clear({required String userId}) {
    return _forUser(userId).run(() => _storage.clear(userId: userId));
  }

  _SerialExecutor _forUser(String userId) {
    _requireUserId(userId);
    return _executors.putIfAbsent(userId, _SerialExecutor.new);
  }

  static void _requireUserId(String userId) {
    if (userId.trim().isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be blank.');
    }
  }
}

typedef _OperationVersion = ({
  String operationId,
  String aggregateType,
  String aggregateId,
  int revision,
});

_OperationVersion _versionOf(SyncOperation operation) {
  return (
    operationId: operation.operationId,
    aggregateType: operation.aggregateType,
    aggregateId: operation.aggregateId,
    revision: operation.revision,
  );
}

final class _SerialExecutor {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await action());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}
