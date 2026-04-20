import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';

void main() {
  group('SharedShoppingListSummary visibility compatibility', () {
    test('recognizes modern schema membership', () {
      final data = <String, dynamic>{
        'ownerUid': 'owner-1',
        'memberUids': <String>['owner-1', 'user-2'],
      };

      expect(
        SharedShoppingListSummary.isVisibleToUserData(data, 'user-2'),
        isTrue,
      );
    });

    test('recognizes legacy schema membership (ownerId/sharedWith)', () {
      final data = <String, dynamic>{
        'ownerId': 'owner-legacy',
        'sharedWith': <String>['user-legacy', 'user-2'],
      };

      expect(
        SharedShoppingListSummary.isVisibleToUserData(data, 'user-2'),
        isTrue,
      );
    });

    test('recognizes owner from legacy ownerId even without sharedWith', () {
      final data = <String, dynamic>{'ownerId': 'owner-legacy'};

      expect(
        SharedShoppingListSummary.isVisibleToUserData(data, 'owner-legacy'),
        isTrue,
      );
    });

    test('returns false when user is not owner or member', () {
      final data = <String, dynamic>{
        'ownerUid': 'owner-1',
        'memberUids': <String>['owner-1', 'user-2'],
      };

      expect(
        SharedShoppingListSummary.isVisibleToUserData(data, 'outsider'),
        isFalse,
      );
    });
  });
}
