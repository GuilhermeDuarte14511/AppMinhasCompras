import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models_and_utils.dart';

class FirestoreUserAppSettings {
  const FirestoreUserAppSettings({this.themeMode});

  final String? themeMode;

  bool get hasData => themeMode != null && themeMode!.isNotEmpty;

  factory FirestoreUserAppSettings.fromJson(Map<String, dynamic> json) {
    final rawThemeMode = (json['themeMode'] as String?)?.trim();
    final parsedThemeMode = switch (rawThemeMode) {
      'dark' => 'dark',
      'light' => 'light',
      _ => null,
    };
    return FirestoreUserAppSettings(themeMode: parsedThemeMode);
  }

  Map<String, dynamic> toFirestoreJson() {
    final payload = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (hasData) {
      payload['themeMode'] = themeMode;
    }
    return payload;
  }
}

class FirestoreUserDataSnapshot {
  const FirestoreUserDataSnapshot({
    required this.lists,
    required this.history,
    required this.catalog,
    required this.settings,
  });

  final List<ShoppingListModel> lists;
  final List<CompletedPurchase> history;
  final List<CatalogProduct> catalog;
  final FirestoreUserAppSettings settings;

  bool get hasCoreData =>
      lists.isNotEmpty || history.isNotEmpty || catalog.isNotEmpty;
  bool get hasAnyData => hasCoreData || settings.hasData;
}

class FirestoreUserDataRepository {
  FirestoreUserDataRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _listsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('lists');
  }

  CollectionReference<Map<String, dynamic>> _historyRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('history');
  }

  CollectionReference<Map<String, dynamic>> _catalogRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('catalog');
  }

  DocumentReference<Map<String, dynamic>> _settingsDocRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app');
  }

  Future<FirestoreUserDataSnapshot> loadUserSnapshot(String uid) async {
    final responses = await Future.wait<dynamic>([
      _listsRef(uid).get(),
      _historyRef(uid).get(),
      _catalogRef(uid).get(),
      _settingsDocRef(uid).get(),
    ]);
    final listsSnapshot = responses[0] as QuerySnapshot<Map<String, dynamic>>;
    final historySnapshot = responses[1] as QuerySnapshot<Map<String, dynamic>>;
    final catalogSnapshot = responses[2] as QuerySnapshot<Map<String, dynamic>>;
    final settingsSnapshot =
        responses[3] as DocumentSnapshot<Map<String, dynamic>>;

    final lists = <ShoppingListModel>[];
    for (final doc in listsSnapshot.docs) {
      final data = doc.data();
      data.putIfAbsent('id', () => doc.id);
      lists.add(ShoppingListModel.fromJson(data));
    }

    final history = <CompletedPurchase>[];
    for (final doc in historySnapshot.docs) {
      final data = doc.data();
      data.putIfAbsent('id', () => doc.id);
      history.add(CompletedPurchase.fromJson(data));
    }

    final catalog = <CatalogProduct>[];
    for (final doc in catalogSnapshot.docs) {
      final data = doc.data();
      data.putIfAbsent('id', () => doc.id);
      catalog.add(CatalogProduct.fromJson(data));
    }

    final settings = FirestoreUserAppSettings.fromJson(
      settingsSnapshot.data() ?? const <String, dynamic>{},
    );

    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    history.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    catalog.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return FirestoreUserDataSnapshot(
      lists: List.unmodifiable(lists),
      history: List.unmodifiable(history),
      catalog: List.unmodifiable(catalog),
      settings: settings,
    );
  }

  Future<void> saveUserSnapshot({
    required String uid,
    required List<ShoppingListModel> lists,
    required List<CompletedPurchase> history,
    required List<CatalogProduct> catalog,
    required FirestoreUserAppSettings settings,
  }) async {
    final batch = _firestore.batch();

    final listsCollection = _listsRef(uid);
    final historyCollection = _historyRef(uid);
    final catalogCollection = _catalogRef(uid);

    final remoteResponses = await Future.wait<dynamic>([
      listsCollection.get(),
      historyCollection.get(),
      catalogCollection.get(),
    ]);
    final remoteLists =
        remoteResponses[0] as QuerySnapshot<Map<String, dynamic>>;
    final remoteHistory =
        remoteResponses[1] as QuerySnapshot<Map<String, dynamic>>;
    final remoteCatalog =
        remoteResponses[2] as QuerySnapshot<Map<String, dynamic>>;

    final localListIds = lists.map((entry) => entry.id).toSet();
    final localHistoryIds = history.map((entry) => entry.id).toSet();
    final localCatalogIds = catalog.map((entry) => entry.id).toSet();

    for (final doc in remoteLists.docs) {
      if (!localListIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final entry in lists) {
      batch.set(listsCollection.doc(entry.id), entry.toJson());
    }

    for (final doc in remoteHistory.docs) {
      if (!localHistoryIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final entry in history) {
      batch.set(historyCollection.doc(entry.id), entry.toJson());
    }

    for (final doc in remoteCatalog.docs) {
      if (!localCatalogIds.contains(doc.id)) {
        batch.delete(doc.reference);
      }
    }
    for (final entry in catalog) {
      batch.set(catalogCollection.doc(entry.id), entry.toJson());
    }

    batch.set(
      _settingsDocRef(uid),
      settings.toFirestoreJson(),
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
