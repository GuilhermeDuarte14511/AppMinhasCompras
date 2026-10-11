import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/data/remote/firebase_user_data_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'permanent deletion completes when native transaction bridge stalls',
    () async {
      final firestore = _NativeBoundary();
      firestore.records['users/account/lists/old-list'] = {'id': 'old-list'};
      final repository = FirestoreUserDataRepository(firestore: firestore);

      await repository
          .applyUserPatch(
            uid: 'account',
            patch: {
              'lists': {
                'deletedIds': ['old-list'],
              },
            },
          )
          .timeout(const Duration(milliseconds: 200));

      expect(
        firestore.records.containsKey('users/account/lists/old-list'),
        isFalse,
      );
      expect(
        firestore.records['users/account/sync_deletions/lists_old-list'],
        containsPair('entityId', 'old-list'),
      );
      expect(
        firestore.records['users/account/sync_deletions/lists_old-list'],
        containsPair('entityType', 'lists'),
      );
    },
  );

  test(
    'failed deletion commit leaves the record and no deletion marker',
    () async {
      final firestore = _NativeBoundary()..failCommit = true;
      firestore.records['users/account/lists/old-list'] = {'id': 'old-list'};
      final repository = FirestoreUserDataRepository(firestore: firestore);

      await expectLater(
        repository
            .applyUserPatch(
              uid: 'account',
              patch: {
                'lists': {
                  'deletedIds': ['old-list'],
                },
              },
            )
            .timeout(const Duration(milliseconds: 200)),
        throwsA(
          isA<FirebaseException>().having((e) => e.code, 'code', 'unavailable'),
        ),
      );

      expect(
        firestore.records.containsKey('users/account/lists/old-list'),
        isTrue,
      );
      expect(
        firestore.records.containsKey(
          'users/account/sync_deletions/lists_old-list',
        ),
        isFalse,
      );
    },
  );

  test(
    'large deletion queues persist every marker without exceeding batch limits',
    () async {
      final firestore = _NativeBoundary();
      final ids = List.generate(260, (i) => 'old-$i');
      for (final id in ids) {
        firestore.records['users/account/lists/$id'] = {'id': id};
      }
      await FirestoreUserDataRepository(firestore: firestore)
          .applyUserPatch(
            uid: 'account',
            patch: {
              'lists': {'deletedIds': ids},
            },
          )
          .timeout(const Duration(milliseconds: 200));
      expect(
        firestore.records.keys.where((path) => path.contains('/lists/')),
        isEmpty,
      );
      expect(
        firestore.records.keys.where(
          (path) => path.contains('/sync_deletions/'),
        ),
        hasLength(260),
      );
    },
  );
}

/// The external SDK boundary models a missing native transaction completion
/// event. Atomic batches remain available and update state only after commit.
class _NativeBoundary implements FirebaseFirestore {
  final records = <String, Map<String, dynamic>>{};
  bool failCommit = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);

  @override
  WriteBatch batch() => _Batch(this);

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => Completer<T>().future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Test-only external SDK boundary; no runtime subclass is shipped.
// ignore: subtype_of_sealed_class
class _Collection implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.owner, this.path);
  final _NativeBoundary owner;
  @override
  final String path;
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(owner, '${this.path}/$path');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _Document implements DocumentReference<Map<String, dynamic>> {
  _Document(this.owner, this.path);
  final _NativeBoundary owner;
  @override
  final String path;
  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _Collection(owner, '$path/$collectionPath');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Batch implements WriteBatch {
  _Batch(this.owner);
  final _NativeBoundary owner;
  final writes = <void Function()>[];
  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) {
    writes.add(
      () =>
          owner.records[document.path] = Map<String, dynamic>.from(data as Map),
    );
  }

  @override
  void delete(DocumentReference document) {
    writes.add(() => owner.records.remove(document.path));
  }

  @override
  Future<void> commit() async {
    if (writes.length > 500) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
      );
    }
    if (owner.failCommit) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    for (final write in writes) {
      write();
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
