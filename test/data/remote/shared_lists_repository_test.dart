import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/shared_lists_repository.dart';

void main() {
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
