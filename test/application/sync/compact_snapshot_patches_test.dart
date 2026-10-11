import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/snapshot_patch.dart';

void main() {
  for (final key in snapshotEntityKeys) {
    group('$key compact durable patches', () {
      test('many revisions send one final record', () {
        final patches = List.generate(
          120,
          (revision) => <String, dynamic>{
            key: {
              'upserts': [
                {'id': 'edited', 'revision': revision},
              ],
            },
          },
        );
        final compact = compactSnapshotPatches(patches);
        expect(compact[key]['upserts'], [
          {'id': 'edited', 'revision': 119},
        ]);
      });

      test('deletion dominates earlier and later stale upserts', () {
        final compact = compactSnapshotPatches([
          {
            key: {
              'upserts': [
                {'id': 'removed', 'revision': 1},
              ],
            },
          },
          {
            key: {
              'deletedIds': ['removed'],
            },
          },
          {
            key: {
              'upserts': [
                {'id': 'removed', 'revision': 100},
              ],
            },
          },
          {
            key: {
              'deletedIds': ['removed'],
            },
          },
        ]);
        expect(compact[key]['deletedIds'], ['removed']);
        expect(compact[key]['upserts'] ?? [], isEmpty);
        final replayed = applySnapshotPatch({
          key: [
            {'id': 'removed'},
          ],
        }, compact);
        expect(replayed[key], isEmpty);
      });

      test(
        'compacted replay equals sequential replay and preserves remote IDs',
        () {
          final base = <String, dynamic>{
            key: [
              {'id': 'remote-only', 'name': 'Other phone'},
              {'id': 'removed'},
            ],
            'settings': {'themeMode': 'dark', 'autoImportSharedCatalogs': true},
          };
          final patches = <Map<String, dynamic>>[
            {
              key: {
                'upserts': [
                  {'id': 'a', 'name': 'Before'},
                  {'id': 'b', 'name': 'Before'},
                ],
              },
            },
            {
              'settings': {'themeMode': 'light'},
            },
            {
              key: {
                'deletedIds': ['removed'],
                'upserts': [
                  {'id': 'a', 'name': 'After'},
                ],
              },
            },
            {
              key: {
                'upserts': [
                  {'id': 'removed', 'name': 'Stale'},
                  {'id': 'b', 'name': 'After'},
                ],
              },
            },
          ];
          final sequential = patches.fold(base, applySnapshotPatch);
          final compacted = applySnapshotPatch(
            base,
            compactSnapshotPatches(patches),
          );
          for (final entityKey in snapshotEntityKeys) {
            expect(_byId(compacted[entityKey]), _byId(sequential[entityKey]));
          }
          expect(compacted['settings'], sequential['settings']);
          expect(compacted['deletedEntityIds'], sequential['deletedEntityIds']);
          expect(_byId(compacted[key]), contains('remote-only'));
        },
      );
    });
  }

  test('latest settings value wins per property and null remains explicit', () {
    final compact = compactSnapshotPatches([
      {
        'settings': {'themeMode': 'dark', 'autoImportSharedCatalogs': true},
      },
      {
        'settings': {'themeMode': 'light'},
      },
      {
        'settings': {
          'sharedCatalogImportListIds': ['list-a'],
        },
      },
      {
        'settings': {'themeMode': null},
      },
    ]);
    expect(compact['settings'], {
      'themeMode': null,
      'autoImportSharedCatalogs': true,
      'sharedCatalogImportListIds': ['list-a'],
    });
  });

  test('compaction does not mutate original durable payloads', () {
    final patches = <Map<String, dynamic>>[
      {
        'catalog': {
          'upserts': [
            {'id': 'a', 'name': 'Before'},
          ],
          'deletedIds': ['b'],
        },
      },
      {
        'catalog': {
          'upserts': [
            {'id': 'a', 'name': 'After'},
          ],
        },
      },
      {
        'settings': {
          'sharedCatalogImportListIds': ['list-a'],
        },
      },
    ];
    final before = jsonEncode(patches);
    compactSnapshotPatches(patches);
    expect(jsonEncode(patches), before);
  });

  test('empty and irrelevant payloads produce no writes', () {
    expect(compactSnapshotPatches([]), isEmpty);
    expect(
      compactSnapshotPatches([
        {},
        {'exportedAt': 'ignored'},
      ]),
      isEmpty,
    );
  });
}

Map<String, dynamic> _byId(dynamic records) => {
  for (final record in records as List) record['id'] as String: record,
};
