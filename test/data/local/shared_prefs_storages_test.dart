import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/local/storages.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test(
    'recovers the last valid list snapshot when primary JSON is corrupt',
    () async {
      final storage = SharedPrefsShoppingListsStorage();
      final first = _list(id: 'first', name: 'Primeira');
      final second = _list(id: 'second', name: 'Segunda');

      await storage.saveLists(<ShoppingListModel>[first]);
      await storage.saveLists(<ShoppingListModel>[second]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopping_lists_v2', '{invalid-json');

      final recovered = await storage.loadLists();

      expect(recovered, hasLength(1));
      expect(recovered.single.id, first.id);
      expect(
        jsonDecode(prefs.getString('shopping_lists_v2')!) as List<dynamic>,
        hasLength(1),
      );
    },
  );

  test('promotes a valid pending write after an interrupted save', () async {
    final pending = _list(id: 'pending', name: 'Mais recente');
    final previous = _list(id: 'previous', name: 'Anterior');
    SharedPreferences.setMockInitialValues(<String, Object>{
      'shopping_lists_v2': jsonEncode(<Object>[previous.toJson()]),
      'shopping_lists_v2_pending': jsonEncode(<Object>[pending.toJson()]),
    });

    final storage = SharedPrefsShoppingListsStorage();
    final loaded = await storage.loadLists();
    final prefs = await SharedPreferences.getInstance();

    expect(loaded.single.id, pending.id);
    expect(prefs.containsKey('shopping_lists_v2_pending'), isFalse);
    expect(
      ShoppingListModel.fromJson(
        Map<String, dynamic>.from(
          (jsonDecode(prefs.getString('shopping_lists_v2')!) as List).single
              as Map,
        ),
      ).id,
      pending.id,
    );
  });

  test(
    'reports unrecoverable corruption instead of returning empty data',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'shopping_lists_v2': 'not-json',
        'shopping_lists_v2_backup': '{"also":"not-a-list"}',
      });

      final storage = SharedPrefsShoppingListsStorage();

      await expectLater(
        storage.loadLists(),
        throwsA(isA<LocalStorageCorruptionException>()),
      );
    },
  );
}

ShoppingListModel _list({required String id, required String name}) {
  final timestamp = DateTime.utc(2026, 7, 23);
  return ShoppingListModel(
    id: id,
    name: name,
    createdAt: timestamp,
    updatedAt: timestamp,
    items: const [],
  );
}
