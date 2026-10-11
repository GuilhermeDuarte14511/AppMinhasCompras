import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/sync/snapshot_cleanup_policy.dart';

void main() {
  test('keeps deletion pending when the remote snapshot was not read', () {
    expect(
      () => planSnapshotDeletes(localIds: const {'kept-list'}, remoteIds: null),
      throwsA(isA<IncompleteRemoteSnapshotException>()),
    );
  });

  test('deletes remote documents missing from the local snapshot', () {
    final deletedIds = planSnapshotDeletes(
      localIds: const {'kept-list'},
      remoteIds: const {'kept-list', 'deleted-list'},
    );

    expect(deletedIds, {'deleted-list'});
  });
}
