// Local emulator probe for the production FlutterFire repository.
// Build separately; this entry point is never used by the published app.
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lista_compras_material/src/data/remote/firebase_user_data_repository.dart';
import 'package:lista_compras_material/src/application/sync/snapshot_patch.dart';
import 'package:lista_compras_material/src/domain/models_and_utils.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';
import 'package:lista_compras_material/src/domain/pantry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = <String>[];
  final progress = ValueNotifier('Initializing local emulator probe…');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<String>(
          valueListenable: progress,
          builder: (context, value, child) =>
              SingleChildScrollView(child: SelectableText(value)),
        ),
      ),
    ),
  );
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
        appId: '1:123:web:crud',
        messagingSenderId: '123',
        projectId: 'demo-crud-validation',
      ),
    );
    progress.value = 'Firebase initialized; connecting local emulators…';
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    progress.value = 'Creating emulator test account…';
    final account = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: 'probe-${DateTime.now().microsecondsSinceEpoch}@example.test',
      password: 'Emulator-only-password-123!',
    );
    final uid = account.user!.uid;
    progress.value = 'Emulator account created; testing repository…';
    final repo = FirestoreUserDataRepository();
    Map<String, dynamic> fixture(
      String key,
      String id,
      String name,
      DateTime now,
    ) => switch (key) {
      'lists' => ShoppingListModel(
        id: id,
        name: name,
        createdAt: now,
        updatedAt: now,
        items: const [],
      ).toJson(),
      'purchaseHistory' => CompletedPurchase(
        id: id,
        listId: 'probe-list',
        listName: name,
        closedAt: now,
        items: const [],
      ).toJson(),
      'catalog' => CatalogProduct(
        id: id,
        name: name,
        category: ShoppingCategory.grocery,
        updatedAt: now,
        unitPrice: 5,
      ).toJson(),
      _ => PantryItem(
        id: id,
        name: name,
        category: ShoppingCategory.grocery,
        status: PantryStockStatus.inStock,
        updatedAt: now,
      ).toJson(),
    };
    Map<String, dynamic> serialize(FirestoreUserDataSnapshot snapshot) => {
      'lists': snapshot.lists.map((e) => e.toJson()).toList(),
      'purchaseHistory': snapshot.history.map((e) => e.toJson()).toList(),
      'catalog': snapshot.catalog.map((e) => e.toJson()).toList(),
      'pantry': snapshot.pantry.map((e) => e.toJson()).toList(),
      'deletedEntityIds': snapshot.deletedEntityIds,
    };
    void check(bool condition, String label) {
      if (!condition) throw StateError(label);
      results.add('PASS $label');
      progress.value = results.join('\n');
    }

    for (final key in snapshotEntityKeys) {
      final now = DateTime.now().toUtc();
      final record = fixture(key, 'original-$key', 'Original', now);
      await repo.applyUserPatch(
        uid: uid,
        patch: {
          key: {
            'upserts': [record],
          },
        },
      );
      var snapshot = serialize(await repo.loadUserSnapshot(uid));
      check((snapshot[key] as List).length == 1, '$key create/read');
      final edit = fixture(
        key,
        'original-$key',
        'Edited',
        now.add(const Duration(seconds: 1)),
      );
      await repo.applyUserPatch(
        uid: uid,
        patch: {
          key: {
            'upserts': [edit],
          },
        },
      );
      snapshot = serialize(await repo.loadUserSnapshot(uid));
      check(
        (snapshot[key] as List).single[key == 'purchaseHistory'
                ? 'listName'
                : 'name'] ==
            'Edited',
        '$key update persisted',
      );
      await repo.applyUserPatch(
        uid: uid,
        patch: {
          key: {
            'deletedIds': ['original-$key'],
          },
        },
      );
      snapshot = serialize(await repo.loadUserSnapshot(uid));
      check((snapshot[key] as List).isEmpty, '$key delete persisted');
      check(
        (snapshot['deletedEntityIds'][key] as List).contains('original-$key'),
        '$key durable marker',
      );
      await repo.applyUserPatch(
        uid: uid,
        patch: {
          key: {
            'upserts': [record],
          },
        },
      );
      snapshot = serialize(await repo.loadUserSnapshot(uid));
      check(
        (snapshot[key] as List).isEmpty,
        '$key stale device cannot resurrect',
      );
      await repo.applyUserPatch(
        uid: uid,
        patch: {
          key: {
            'upserts': [fixture(key, 'fresh-$key', 'Fresh', now)],
          },
        },
      );
      snapshot = serialize(await repo.loadUserSnapshot(uid));
      check(
        (snapshot[key] as List).single['id'] == 'fresh-$key',
        '$key new ID works',
      );
    }
    results.add('ALL 24 REPOSITORY CHECKS PASSED');
  } catch (error) {
    results.add('FAIL $error');
  }
  progress.value = results.join('\n');
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SelectableText(results.join('\n'))),
      ),
    ),
  );
}
