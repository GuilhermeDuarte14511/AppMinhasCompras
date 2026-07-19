import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/sync/sync_operation.dart';
import '../../application/sync/sync_outbox_storage.dart';

final class SharedPrefsSyncOutboxStorage implements SyncOutboxStorage {
  const SharedPrefsSyncOutboxStorage();

  static const String _keyPrefix = 'sync_outbox_v1_';
  static const int _schemaVersion = 1;

  @override
  Future<List<SyncOperation>> load({required String userId}) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_keyFor(userId));
    if (raw == null || raw.isEmpty) {
      return const <SyncOperation>[];
    }

    try {
      final document = _stringMap(jsonDecode(raw));
      if (_integer(document['version']) != _schemaVersion) {
        throw const FormatException('Unsupported sync outbox version.');
      }
      final rawOperations = document['operations'];
      if (rawOperations is! List) {
        throw const FormatException('Invalid sync outbox operations.');
      }
      return List<SyncOperation>.unmodifiable(
        rawOperations.map((entry) => _operationFromJson(_stringMap(entry))),
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid sync outbox data.', error);
    }
  }

  @override
  Future<void> save({
    required String userId,
    required List<SyncOperation> operations,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _keyFor(userId);
    if (operations.isEmpty) {
      await preferences.remove(key);
      return;
    }

    await preferences.setString(
      key,
      jsonEncode(<String, Object?>{
        'version': _schemaVersion,
        'operations': operations.map(_operationToJson).toList(growable: false),
      }),
    );
  }

  @override
  Future<void> clear({required String userId}) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_keyFor(userId));
  }

  String _keyFor(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Must not be blank.');
    }
    final encodedUserId = base64Url.encode(utf8.encode(normalized));
    return '$_keyPrefix$encodedUserId';
  }

  Map<String, Object?> _operationToJson(SyncOperation operation) {
    return <String, Object?>{
      'operationId': operation.operationId,
      'aggregateType': operation.aggregateType,
      'aggregateId': operation.aggregateId,
      'revision': operation.revision,
      'kind': operation.kind.name,
      'payload': operation.payload,
      'occurredAt': operation.occurredAt.toUtc().toIso8601String(),
      'attempts': operation.attempts,
      'nextAttemptAt': operation.nextAttemptAt?.toUtc().toIso8601String(),
    };
  }

  SyncOperation _operationFromJson(Map<String, Object?> json) {
    final kind = switch (_text(json['kind'])) {
      'upsert' => SyncOperationKind.upsert,
      'delete' => SyncOperationKind.delete,
      _ => throw const FormatException('Invalid sync operation kind.'),
    };
    final payload = _stringMap(json['payload']);
    final nextAttemptAt = json['nextAttemptAt'];
    return SyncOperation(
      operationId: _text(json['operationId']),
      aggregateType: _text(json['aggregateType']),
      aggregateId: _text(json['aggregateId']),
      revision: _integer(json['revision']),
      kind: kind,
      payload: payload,
      occurredAt: _dateTime(json['occurredAt']),
      attempts: _integer(json['attempts']),
      nextAttemptAt: nextAttemptAt == null ? null : _dateTime(nextAttemptAt),
    );
  }

  Map<String, Object?> _stringMap(Object? value) {
    if (value is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const FormatException('JSON object keys must be strings.');
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Expected non-empty text.');
    }
    return value;
  }

  int _integer(Object? value) {
    if (value is! int) {
      throw const FormatException('Expected an integer.');
    }
    return value;
  }

  DateTime _dateTime(Object? value) {
    if (value is! String) {
      throw const FormatException('Expected an ISO-8601 date.');
    }
    return DateTime.parse(value).toUtc();
  }
}
