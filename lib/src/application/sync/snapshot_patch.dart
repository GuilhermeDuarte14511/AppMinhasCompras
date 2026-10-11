import 'dart:convert';

const snapshotEntityKeys = ['lists', 'purchaseHistory', 'catalog', 'pantry'];

/// Collapses a captured outbox into its final mutations. Permanent deletes
/// dominate every upsert, including stale entries later in the same queue.
Map<String, dynamic> compactSnapshotPatches(
  Iterable<Map<String, dynamic>> patches,
) {
  final source = patches.toList();
  final result = <String, dynamic>{};
  for (final key in snapshotEntityKeys) {
    final upserts = <String, Map<String, dynamic>>{};
    final deleted = <String>{};
    for (final patch in source) {
      final changes = patch[key];
      if (changes is! Map) continue;
      upserts.addAll(_index(changes['upserts']));
      final ids = changes['deletedIds'];
      if (ids is List) deleted.addAll(ids.whereType<String>());
    }
    upserts.removeWhere((id, _) => deleted.contains(id));
    if (upserts.isNotEmpty || deleted.isNotEmpty) {
      result[key] = {
        'upserts': upserts.values.toList(),
        'deletedIds': deleted.toList()..sort(),
      };
    }
  }
  final settings = <String, dynamic>{};
  for (final patch in source) {
    if (patch['settings'] is Map) {
      settings.addAll(Map<String, dynamic>.from(patch['settings'] as Map));
    }
  }
  if (settings.isNotEmpty) result['settings'] = settings;
  return result;
}

Map<String, Map<String, dynamic>> _index(Object? entries) => {
  if (entries is List)
    for (final entry in entries.whereType<Map>())
      if (entry['id'] is String)
        entry['id'] as String: Map<String, dynamic>.from(entry),
};

/// Only records local mutations; unrelated records on another device survive.
Map<String, dynamic> diffSnapshotData(
  Map<String, dynamic> base,
  Map<String, dynamic> current,
) {
  final patch = <String, dynamic>{};
  for (final key in snapshotEntityKeys) {
    final before = _index(base[key]);
    final after = _index(current[key]);
    final upserts = after.values
        .where((entry) => jsonEncode(before[entry['id']]) != jsonEncode(entry))
        .toList();
    final deleted = before.keys.where((id) => !after.containsKey(id)).toList();
    if (upserts.isNotEmpty || deleted.isNotEmpty) {
      patch[key] = {'upserts': upserts, 'deletedIds': deleted};
    }
  }
  if (current['settings'] != null &&
      jsonEncode(base['settings']) != jsonEncode(current['settings'])) {
    final settings = Map<String, dynamic>.from(current['settings'] as Map);
    final priorSettings = base['settings'] is Map
        ? base['settings'] as Map
        : const {};
    patch['settings'] = {
      for (final entry in settings.entries)
        if (jsonEncode(priorSettings[entry.key]) != jsonEncode(entry.value))
          entry.key: entry.value,
    };
  }
  return patch;
}

/// Replays durable mutations over the latest cloud state, including deletions.
Map<String, dynamic> applySnapshotPatch(
  Map<String, dynamic> base,
  Map<String, dynamic> patch,
) {
  final result = Map<String, dynamic>.from(base);
  final tombstones = <String, dynamic>{};
  final prior = base['deletedEntityIds'];
  for (final key in snapshotEntityKeys) {
    final deleted = <String>{
      if (prior is Map && prior[key] is List)
        ...(prior[key] as List).whereType<String>(),
    };
    final entities = _index(base[key]);
    final changes = patch[key];
    if (changes is Map) {
      final rawDeleted = changes['deletedIds'];
      if (rawDeleted is List) deleted.addAll(rawDeleted.whereType<String>());
      for (final entry in _index(changes['upserts']).values) {
        if (!deleted.contains(entry['id'])) entities[entry['id']] = entry;
      }
    }
    entities.removeWhere((id, _) => deleted.contains(id));
    result[key] = entities.values.toList();
    tombstones[key] = deleted.toList()..sort();
  }
  result['deletedEntityIds'] = tombstones;
  if (patch['settings'] is Map) {
    result['settings'] = {
      if (base['settings'] is Map)
        ...Map<String, dynamic>.from(base['settings'] as Map),
      ...Map<String, dynamic>.from(patch['settings'] as Map),
    };
  }
  return result;
}
