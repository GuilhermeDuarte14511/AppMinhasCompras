import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/snapshot_patch.dart';

void main() {
  for (final collection in ['lists', 'purchaseHistory', 'catalog', 'pantry']) {
    group('$collection durable CRUD patch', () {
      test('create edit and delete survive serialization and replay', () {
        final before = _snapshot(collection, [
          {'id': 'edited', 'name': 'Original', 'quantity': 1},
          {'id': 'deleted', 'name': 'Excluir'},
          {'id': 'unchanged', 'name': 'Preservar'},
        ]);
        final after = _snapshot(collection, [
          {'id': 'created', 'name': 'Novo', 'quantity': 2},
          {'id': 'edited', 'name': 'Editado', 'quantity': 3},
          {'id': 'unchanged', 'name': 'Preservar'},
        ]);
        final patch = _serialized(diffSnapshotData(before, after));
        final restored = applySnapshotPatch(before, patch);
        expect(_byId(restored, collection), _byId(after, collection));
      });

      test('pending delete cannot return from stale remote snapshot', () {
        final staleRemote = _snapshot(collection, [
          {'id': 'deleted', 'name': 'Antigo'},
          {'id': 'kept', 'name': 'Preservar'},
        ]);
        final local = _snapshot(collection, [
          {'id': 'kept', 'name': 'Preservar'},
        ]);
        final durablePatch = _serialized(diffSnapshotData(staleRemote, local));
        final hydrated = applySnapshotPatch(staleRemote, durablePatch);
        expect(_byId(hydrated, collection).containsKey('deleted'), isFalse);
        expect(_byId(hydrated, collection)['kept'], {
          'id': 'kept',
          'name': 'Preservar',
        });
      });

      test('replay preserves unrelated records created by another device', () {
        final base = _snapshot(collection, [
          {'id': 'local', 'name': 'Original'},
        ]);
        final local = _snapshot(collection, [
          {'id': 'local', 'name': 'Atualizado'},
        ]);
        final remote = _snapshot(collection, [
          {'id': 'local', 'name': 'Original'},
          {'id': 'other-device', 'name': 'Criado em outro aparelho'},
        ]);
        final hydrated = applySnapshotPatch(
          remote,
          diffSnapshotData(base, local),
        );
        expect(_byId(hydrated, collection)['local']!['name'], 'Atualizado');
        expect(
          _byId(hydrated, collection)['other-device']!['name'],
          'Criado em outro aparelho',
        );
      });

      test('replaying the same pending operation is idempotent', () {
        final base = _snapshot(collection, [
          {'id': 'removed'},
        ]);
        final local = _snapshot(collection, [
          {'id': 'new', 'name': 'Novo'},
        ]);
        final patch = diffSnapshotData(base, local);
        final once = applySnapshotPatch(base, patch);
        final twice = applySnapshotPatch(once, patch);
        expect(_byId(twice, collection), _byId(once, collection));
      });

      test('permanent tombstone blocks an older queued upsert', () {
        final base = _snapshot(collection, [
          {'id': 'removed', 'name': 'Original'},
        ]);
        final edited = _snapshot(collection, [
          {'id': 'removed', 'name': 'Editado antes da exclusão'},
        ]);
        final staleEdit = diffSnapshotData(base, edited);
        final deletion = diffSnapshotData(base, _snapshot(collection, []));
        final deleted = applySnapshotPatch(base, deletion);
        final replayed = applySnapshotPatch(deleted, staleEdit);
        expect(_byId(replayed, collection).containsKey('removed'), isFalse);
        expect(
          (replayed['deletedEntityIds'] as Map)[collection],
          contains('removed'),
        );
      });
    });
  }

  test('local settings patch preserves unrelated remote settings', () {
    final base = _snapshot(
      'lists',
      [],
    )..['settings'] = {'themeMode': 'light', 'autoImportSharedCatalogs': false};
    final local = _snapshot('lists', [])
      ..['settings'] = {'themeMode': 'dark', 'autoImportSharedCatalogs': false};
    final remote = _snapshot('lists', [])
      ..['settings'] = {'themeMode': 'light', 'autoImportSharedCatalogs': true};
    final replayed = applySnapshotPatch(
      remote,
      _serialized(diffSnapshotData(base, local)),
    );
    expect(replayed['settings'], {
      'themeMode': 'dark',
      'autoImportSharedCatalogs': true,
    });
  });

  test('a list edit preserves deletion marker and nested item fields', () {
    final before = _snapshot('lists', [
      {
        'id': 'list',
        'name': 'Mercado',
        'items': [
          {'id': 'item', 'quantity': 1},
        ],
      },
    ]);
    final after = _snapshot('lists', [
      {
        'id': 'list',
        'name': 'Mercado',
        'deletedAt': '2026-10-11T17:00:00.000',
        'items': [
          {'id': 'item', 'quantity': 2, 'isPurchased': true},
        ],
      },
    ]);
    final hydrated = applySnapshotPatch(
      before,
      _serialized(diffSnapshotData(before, after)),
    );
    expect(_byId(hydrated, 'lists'), _byId(after, 'lists'));
  });

  test('successive edit and permanent delete leave no entity after reload', () {
    final base = _snapshot('lists', [
      {'id': 'list', 'name': 'Aberta'},
    ]);
    final trashed = _snapshot('lists', [
      {'id': 'list', 'name': 'Aberta', 'deletedAt': '2026-10-11T17:00:00.000'},
    ]);
    final empty = _snapshot('lists', []);
    final trashPatch = _serialized(diffSnapshotData(base, trashed));
    final deletionPatch = _serialized(diffSnapshotData(trashed, empty));
    final replayed = applySnapshotPatch(
      applySnapshotPatch(base, trashPatch),
      deletionPatch,
    );
    expect(_byId(replayed, 'lists'), isEmpty);
  });
}

Map<String, dynamic> _snapshot(
  String collection,
  List<Map<String, dynamic>> values,
) => {
  'lists': <Map<String, dynamic>>[],
  'purchaseHistory': <Map<String, dynamic>>[],
  'catalog': <Map<String, dynamic>>[],
  'pantry': <Map<String, dynamic>>[],
  'settings': <String, dynamic>{},
  collection: values,
};

Map<String, dynamic> _serialized(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

Map<String, Map<String, dynamic>> _byId(
  Map<String, dynamic> snapshot,
  String collection,
) => {
  for (final raw in snapshot[collection] as List)
    (raw as Map)['id'] as String: Map<String, dynamic>.from(raw),
};
