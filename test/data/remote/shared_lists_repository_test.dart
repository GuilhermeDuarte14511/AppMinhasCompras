import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';

void main() {
  group('invite claim id', () {
    test('normalizes the invite code and preserves the authenticated UID', () {
      final claimId = SharedListsRepository.inviteClaimIdFor(
        inviteCode: ' abcd-2345 ',
        uid: ' firebase-uid ',
      );

      expect(claimId, 'ABCD2345_firebase-uid');
    });

    test('rejects an empty code or UID', () {
      expect(
        () => SharedListsRepository.inviteClaimIdFor(
          inviteCode: '---',
          uid: 'uid',
        ),
        throwsArgumentError,
      );
      expect(
        () => SharedListsRepository.inviteClaimIdFor(
          inviteCode: 'ABCD2345',
          uid: '  ',
        ),
        throwsArgumentError,
      );
    });
  });

  test(
    'sorts shared lists by createdAt when an older list is updated later',
    () {
      final oldButUpdated = SharedShoppingListSummary(
        id: 'old',
        name: 'Antiga atualizada',
        ownerUid: 'owner',
        memberUids: const ['owner', 'member'],
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 6, 24),
      );
      final newer = SharedShoppingListSummary(
        id: 'newer',
        name: 'Criada ontem',
        ownerUid: 'owner',
        memberUids: const ['owner', 'member'],
        createdAt: DateTime(2026, 6, 23),
        updatedAt: DateTime(2026, 6, 23),
      );

      final sorted = SharedListsRepository.sortSummariesByCreatedAt([
        oldButUpdated,
        newer,
      ]);

      expect(sorted.map((entry) => entry.id), ['newer', 'old']);
    },
  );
}
