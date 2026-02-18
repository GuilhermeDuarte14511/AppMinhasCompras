import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../domain/models_and_utils.dart';

class FirestoreUserProfile {
  const FirestoreUserProfile({
    required this.uid,
    this.displayName,
    this.email,
    this.photoUrl,
    this.provider,
    this.themeMode,
    this.isOnboardingCompleted,
  });

  final String uid;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? provider;
  final String? themeMode;
  final bool? isOnboardingCompleted;

  bool get hasAnyValue {
    return (displayName?.trim().isNotEmpty ?? false) ||
        (email?.trim().isNotEmpty ?? false) ||
        (photoUrl?.trim().isNotEmpty ?? false) ||
        (provider?.trim().isNotEmpty ?? false) ||
        (themeMode?.trim().isNotEmpty ?? false) ||
        isOnboardingCompleted != null;
  }

  factory FirestoreUserProfile.fromFirestoreJson({
    required String uid,
    required Map<String, dynamic> json,
  }) {
    String? readString(String key) {
      final raw = json[key];
      if (raw is! String) {
        return null;
      }
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      return trimmed;
    }

    final parsedThemeMode = switch (readString('themeMode')) {
      'dark' => 'dark',
      'light' => 'light',
      _ => null,
    };
    final parsedProvider = switch (readString('provider')) {
      'password' => 'password',
      'google.com' => 'google.com',
      _ => null,
    };
    final rawOnboardingCompleted = json['isOnboardingCompleted'];

    return FirestoreUserProfile(
      uid: uid,
      displayName: readString('displayName'),
      email: readString('email'),
      photoUrl: readString('photoUrl'),
      provider: parsedProvider,
      themeMode: parsedThemeMode,
      isOnboardingCompleted: rawOnboardingCompleted is bool
          ? rawOnboardingCompleted
          : null,
    );
  }

  Map<String, dynamic> toFirestoreJson({bool includeCreatedAt = true}) {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{'updatedAt': now};
    final cleanedDisplayName = _clean(displayName);
    final cleanedEmail = _clean(email);
    final cleanedPhotoUrl = _clean(photoUrl);
    final cleanedProvider = _clean(provider);
    final cleanedThemeMode = _clean(themeMode);
    if (cleanedDisplayName != null) {
      payload['displayName'] = cleanedDisplayName;
    }
    if (cleanedEmail != null) {
      payload['email'] = cleanedEmail;
    }
    if (cleanedPhotoUrl != null) {
      payload['photoUrl'] = cleanedPhotoUrl;
    }
    if (cleanedProvider != null) {
      payload['provider'] = cleanedProvider;
    }
    if (cleanedThemeMode != null) {
      payload['themeMode'] = cleanedThemeMode;
    }
    if (isOnboardingCompleted != null) {
      payload['isOnboardingCompleted'] = isOnboardingCompleted;
    }
    if (includeCreatedAt) {
      payload['createdAt'] = now;
    }
    return payload;
  }

  String? _clean(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}

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
    return <String, dynamic>{
      'themeMode': hasData ? themeMode : null,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}

class FirestoreUserDataSnapshot {
  const FirestoreUserDataSnapshot({
    required this.lists,
    required this.history,
    required this.catalog,
    required this.settings,
    this.profile,
  });

  final List<ShoppingListModel> lists;
  final List<CompletedPurchase> history;
  final List<CatalogProduct> catalog;
  final FirestoreUserAppSettings settings;
  final FirestoreUserProfile? profile;

  bool get hasCoreData =>
      lists.isNotEmpty || history.isNotEmpty || catalog.isNotEmpty;
  bool get hasAnyData =>
      hasCoreData || settings.hasData || (profile?.hasAnyValue ?? false);
}

class FirestoreUserDataRepository {
  FirestoreUserDataRepository({FirebaseFirestore? firestore})
    : _defaultFirestore = FirebaseFirestore.instanceFor(app: Firebase.app()),
      _activeFirestore = firestore ?? _buildPreferredFirestore(),
      _allowDefaultFallback = firestore == null,
      _usingDefaultFirestore = firestore == null
          ? _resolveConfiguredDatabaseId() == '(default)'
          : false;

  static const String _firestoreDatabaseIdFromDefine = String.fromEnvironment(
    'FIRESTORE_DATABASE_ID',
  );
  static const String _firestoreDatabaseIdHardcoded = 'minhascompras';
  static const int _maxBatchOperations = 450;
  static const Set<String> _transientCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'aborted',
    'resource-exhausted',
  };

  final FirebaseFirestore _defaultFirestore;
  final bool _allowDefaultFallback;
  FirebaseFirestore _activeFirestore;
  bool _usingDefaultFirestore;

  static FirebaseFirestore _buildPreferredFirestore() {
    final configuredId = _resolveConfiguredDatabaseId();
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: configuredId,
    );
  }

  static String _resolveConfiguredDatabaseId() {
    final fromDefine = _firestoreDatabaseIdFromDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine;
    }
    final hardcoded = _firestoreDatabaseIdHardcoded.trim();
    if (hardcoded.isNotEmpty) {
      return hardcoded;
    }
    return '(default)';
  }

  CollectionReference<Map<String, dynamic>> _listsRef(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return firestore.collection('users').doc(uid).collection('lists');
  }

  CollectionReference<Map<String, dynamic>> _historyRef(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return firestore.collection('users').doc(uid).collection('history');
  }

  CollectionReference<Map<String, dynamic>> _catalogRef(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return firestore.collection('users').doc(uid).collection('catalog');
  }

  DocumentReference<Map<String, dynamic>> _userDocRef(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return firestore.collection('users').doc(uid);
  }

  DocumentReference<Map<String, dynamic>> _settingsDocRef(
    FirebaseFirestore firestore,
    String uid,
  ) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('app');
  }

  Future<FirestoreUserDataSnapshot> loadUserSnapshot(String uid) async {
    return _runWithDatabaseFallback((firestore) async {
      try {
        return _loadUserSnapshotWithSource(firestore, uid);
      } on FirebaseException catch (error) {
        if (!_isTransientError(error)) {
          rethrow;
        }
        // Fallback offline-first: use local cache when backend is temporarily unavailable.
        return _loadUserSnapshotWithSource(
          firestore,
          uid,
          source: Source.cache,
        );
      }
    });
  }

  Future<FirestoreUserDataSnapshot> _loadUserSnapshotWithSource(
    FirebaseFirestore firestore,
    String uid, {
    Source? source,
  }) async {
    final getOptions = source == null ? null : GetOptions(source: source);
    final responses = await Future.wait<dynamic>([
      getOptions == null
          ? _userDocRef(firestore, uid).get()
          : _userDocRef(firestore, uid).get(getOptions),
      getOptions == null
          ? _listsRef(firestore, uid).get()
          : _listsRef(firestore, uid).get(getOptions),
      getOptions == null
          ? _historyRef(firestore, uid).get()
          : _historyRef(firestore, uid).get(getOptions),
      getOptions == null
          ? _catalogRef(firestore, uid).get()
          : _catalogRef(firestore, uid).get(getOptions),
      getOptions == null
          ? _settingsDocRef(firestore, uid).get()
          : _settingsDocRef(firestore, uid).get(getOptions),
    ]);
    final userSnapshot = responses[0] as DocumentSnapshot<Map<String, dynamic>>;
    final listsSnapshot = responses[1] as QuerySnapshot<Map<String, dynamic>>;
    final historySnapshot = responses[2] as QuerySnapshot<Map<String, dynamic>>;
    final catalogSnapshot = responses[3] as QuerySnapshot<Map<String, dynamic>>;
    final settingsSnapshot =
        responses[4] as DocumentSnapshot<Map<String, dynamic>>;

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
    final profileData = userSnapshot.data();
    final profile = profileData == null
        ? null
        : FirestoreUserProfile.fromFirestoreJson(uid: uid, json: profileData);

    lists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    history.sort((a, b) => b.closedAt.compareTo(a.closedAt));
    catalog.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return FirestoreUserDataSnapshot(
      lists: List.unmodifiable(lists),
      history: List.unmodifiable(history),
      catalog: List.unmodifiable(catalog),
      settings: settings,
      profile: profile,
    );
  }

  Future<void> saveUserSnapshot({
    required String uid,
    required List<ShoppingListModel> lists,
    required List<CompletedPurchase> history,
    required List<CatalogProduct> catalog,
    required FirestoreUserAppSettings settings,
    FirestoreUserProfile? profile,
  }) async {
    await _runWithDatabaseFallback((firestore) async {
      final listsCollection = _listsRef(firestore, uid);
      final historyCollection = _historyRef(firestore, uid);
      final catalogCollection = _catalogRef(firestore, uid);

      QuerySnapshot<Map<String, dynamic>>? remoteLists;
      QuerySnapshot<Map<String, dynamic>>? remoteHistory;
      QuerySnapshot<Map<String, dynamic>>? remoteCatalog;
      try {
        final remoteResponses = await Future.wait<dynamic>([
          listsCollection.get(),
          historyCollection.get(),
          catalogCollection.get(),
        ]);
        remoteLists = remoteResponses[0] as QuerySnapshot<Map<String, dynamic>>;
        remoteHistory =
            remoteResponses[1] as QuerySnapshot<Map<String, dynamic>>;
        remoteCatalog =
            remoteResponses[2] as QuerySnapshot<Map<String, dynamic>>;
      } on FirebaseException catch (error) {
        if (!_isTransientError(error)) {
          rethrow;
        }
        // Backend temporarily unavailable. Continue with upserts so local cache can
        // queue writes and sync later. Cleanup deletes run again when reads recover.
        remoteLists = null;
        remoteHistory = null;
        remoteCatalog = null;
      }

      final localListIds = lists.map((entry) => entry.id).toSet();
      final localHistoryIds = history.map((entry) => entry.id).toSet();
      final localCatalogIds = catalog.map((entry) => entry.id).toSet();
      final operations = <void Function(WriteBatch batch)>[];

      if (remoteLists != null) {
        for (final doc in remoteLists.docs) {
          if (!localListIds.contains(doc.id)) {
            operations.add((batch) => batch.delete(doc.reference));
          }
        }
      }
      for (final entry in lists) {
        operations.add(
          (batch) => batch.set(listsCollection.doc(entry.id), entry.toJson()),
        );
      }

      if (remoteHistory != null) {
        for (final doc in remoteHistory.docs) {
          if (!localHistoryIds.contains(doc.id)) {
            operations.add((batch) => batch.delete(doc.reference));
          }
        }
      }
      for (final entry in history) {
        operations.add(
          (batch) => batch.set(historyCollection.doc(entry.id), entry.toJson()),
        );
      }

      if (remoteCatalog != null) {
        for (final doc in remoteCatalog.docs) {
          if (!localCatalogIds.contains(doc.id)) {
            operations.add((batch) => batch.delete(doc.reference));
          }
        }
      }
      for (final entry in catalog) {
        operations.add(
          (batch) => batch.set(catalogCollection.doc(entry.id), entry.toJson()),
        );
      }

      operations.add(
        (batch) => batch.set(
          _settingsDocRef(firestore, uid),
          settings.toFirestoreJson(),
          SetOptions(merge: true),
        ),
      );

      if (profile != null) {
        operations.add(
          (batch) => batch.set(
            _userDocRef(firestore, uid),
            profile.toFirestoreJson(includeCreatedAt: false),
            SetOptions(merge: true),
          ),
        );
      }

      await _commitOperationsInChunks(firestore, operations);
    });
  }

  Future<void> saveUserProfile({required FirestoreUserProfile profile}) async {
    await _runWithDatabaseFallback((firestore) async {
      await _userDocRef(firestore, profile.uid).set(
        profile.toFirestoreJson(includeCreatedAt: false),
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _commitOperationsInChunks(
    FirebaseFirestore firestore,
    List<void Function(WriteBatch batch)> operations,
  ) async {
    if (operations.isEmpty) {
      return;
    }

    var batch = firestore.batch();
    var batchSize = 0;

    for (final operation in operations) {
      operation(batch);
      batchSize += 1;
      if (batchSize >= _maxBatchOperations) {
        await batch.commit();
        batch = firestore.batch();
        batchSize = 0;
      }
    }

    if (batchSize > 0) {
      await batch.commit();
    }
  }

  bool _isTransientError(FirebaseException error) {
    return _transientCodes.contains(error.code.trim().toLowerCase());
  }

  bool _shouldFallbackToDefaultDatabase(FirebaseException error) {
    final code = error.code.trim().toLowerCase();
    return code == 'not-found' ||
        code == 'failed-precondition' ||
        code == 'invalid-argument' ||
        code == 'unavailable' ||
        code == 'deadline-exceeded';
  }

  Future<T> _runWithDatabaseFallback<T>(
    Future<T> Function(FirebaseFirestore firestore) action,
  ) async {
    try {
      return await action(_activeFirestore);
    } on FirebaseException catch (error) {
      if (_usingDefaultFirestore ||
          !_allowDefaultFallback ||
          !_shouldFallbackToDefaultDatabase(error)) {
        rethrow;
      }
      _activateDefaultFirestoreFallback();
      return await action(_activeFirestore);
    } on LateInitializationError {
      if (_usingDefaultFirestore || !_allowDefaultFallback) {
        rethrow;
      }
      _activateDefaultFirestoreFallback();
      return await action(_activeFirestore);
    }
  }

  void _activateDefaultFirestoreFallback() {
    _activeFirestore = _defaultFirestore;
    _usingDefaultFirestore = true;
  }
}
