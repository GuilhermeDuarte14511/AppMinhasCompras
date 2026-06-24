import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/shared_list_sync_policy.dart';

void main() {
  test(
    'owned shared mirror pulls from shared even when local copy looks newer',
    () {
      final action = resolveOwnedSharedListMirrorAction(
        hasSourceLocalListId: true,
        hasLocalCopy: true,
        localUpdatedAt: DateTime(2026, 6, 20),
        sharedUpdatedAt: DateTime(2026, 6, 19),
      );

      expect(action, SharedListMirrorAction.pullSharedToLocal);
    },
  );

  test('linked local editor skips stale shared snapshots without pushing', () {
    final action = resolveLinkedSharedSnapshotAction(
      sourceMatchesLocalList: true,
      isSyncingToShared: false,
      localUpdatedAt: DateTime(2026, 6, 20),
      sharedUpdatedAt: DateTime(2026, 6, 19),
    );

    expect(action, SharedListMirrorAction.skip);
  });
}
