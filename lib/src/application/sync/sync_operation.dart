enum SyncOperationKind { upsert, delete }

/// An immutable, idempotent change that can be delivered to a remote store.
///
/// [operationId] is the idempotency key and must remain stable across retries.
/// [revision] is monotonic inside the aggregate identified by
/// [aggregateType] and [aggregateId].
final class SyncOperation {
  factory SyncOperation({
    required String operationId,
    required String aggregateType,
    required String aggregateId,
    required int revision,
    required SyncOperationKind kind,
    required Map<String, Object?> payload,
    required DateTime occurredAt,
    int attempts = 0,
    DateTime? nextAttemptAt,
  }) {
    _requireText(operationId, 'operationId');
    _requireText(aggregateType, 'aggregateType');
    _requireText(aggregateId, 'aggregateId');
    if (revision < 0) {
      throw ArgumentError.value(revision, 'revision', 'Must not be negative.');
    }
    if (attempts < 0) {
      throw ArgumentError.value(attempts, 'attempts', 'Must not be negative.');
    }

    return SyncOperation._(
      operationId: operationId,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      revision: revision,
      kind: kind,
      payload: _freezeMap(payload),
      occurredAt: occurredAt,
      attempts: attempts,
      nextAttemptAt: nextAttemptAt,
    );
  }

  const SyncOperation._({
    required this.operationId,
    required this.aggregateType,
    required this.aggregateId,
    required this.revision,
    required this.kind,
    required this.payload,
    required this.occurredAt,
    required this.attempts,
    required this.nextAttemptAt,
  });

  final String operationId;
  final String aggregateType;
  final String aggregateId;
  final int revision;
  final SyncOperationKind kind;

  /// Deeply unmodifiable and restricted to JSON-compatible values.
  final Map<String, Object?> payload;

  final DateTime occurredAt;
  final int attempts;
  final DateTime? nextAttemptAt;

  bool isReadyAt(DateTime instant) {
    final scheduledAt = nextAttemptAt;
    return scheduledAt == null || !scheduledAt.isAfter(instant);
  }

  bool hasSameIdentityAndRevisionAs(SyncOperation other) {
    return operationId == other.operationId &&
        aggregateType == other.aggregateType &&
        aggregateId == other.aggregateId &&
        revision == other.revision;
  }

  SyncOperation scheduleRetry(DateTime retryAt) {
    return SyncOperation._(
      operationId: operationId,
      aggregateType: aggregateType,
      aggregateId: aggregateId,
      revision: revision,
      kind: kind,
      payload: payload,
      occurredAt: occurredAt,
      attempts: attempts + 1,
      nextAttemptAt: retryAt,
    );
  }

  static void _requireText(String value, String name) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, name, 'Must not be blank.');
    }
  }
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) {
  return Map<String, Object?>.unmodifiable(
    source.map((key, value) => MapEntry(key, _freezeValue(value))),
  );
}

Object? _freezeValue(Object? value) {
  if (value == null || value is bool || value is String || value is int) {
    return value;
  }
  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'payload',
        'Must contain finite numbers.',
      );
    }
    return value;
  }
  if (value is num) {
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeValue));
  }
  if (value is Map<String, Object?>) {
    return _freezeMap(value);
  }
  if (value is Map) {
    final normalized = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
          value,
          'payload',
          'Nested map keys must be strings.',
        );
      }
      normalized[key] = _freezeValue(entry.value);
    }
    return Map<String, Object?>.unmodifiable(normalized);
  }

  throw ArgumentError.value(
    value,
    'payload',
    'Only JSON-compatible values are supported.',
  );
}
