import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../application/ports.dart';
import '../application/shared_list_sync_policy.dart';
import '../application/store_and_services.dart';
import '../application/sync/sync_operation.dart';
import '../application/sync/sync_outbox_coordinator.dart';
import '../application/sync/sync_outbox_storage.dart';
import '../application/sync_diagnostics.dart';
import '../data/local/shared_prefs_sync_outbox_storage.dart';
import '../data/local/storages.dart';
import '../data/remote/cosmos_backend_product_lookup_service.dart';
import '../data/remote/firebase_user_data_repository.dart';
import '../data/remote/open_food_facts_product_lookup_service.dart';
import '../data/remote/shared_lists_repository.dart';
import '../data/repositories/product_catalog_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/reminder_service.dart';
import '../data/services/speech_to_text_voice_service.dart';
import '../domain/models_and_utils.dart';
import '../presentation/auth_page.dart';
import '../presentation/launch.dart';
import '../presentation/onboarding_page.dart';
import '../presentation/pages.dart';
import '../presentation/theme/app_tokens.dart';
import '../presentation/utils/app_toast.dart';

const Color _actionColor = Color(0xFFF97316);
const Color _actionForegroundColor = Color(0xFF111827);

@visibleForTesting
List<ProductLookupService> buildDefaultProductLookupServices() {
  return <ProductLookupService>[
    CosmosBackendProductLookupService(),
    const OpenProductsFactsProductLookupService(),
    const OpenFoodFactsProductLookupService(),
  ];
}

class ShoppingListApp extends StatefulWidget {
  const ShoppingListApp({
    super.key,
    ShoppingListsStorage? storage,
    ShoppingBackupService? backupService,
    ShoppingReminderService? reminderService,
    ProductCatalogStorage? catalogStorage,
    PurchaseHistoryStorage? historyStorage,
    ProductLookupService? lookupService,
    ShoppingHomeWidgetService? homeWidgetService,
    ShoppingVoiceRecognitionService? voiceRecognitionService,
    FirebaseFirestore? firestoreInstance,
    SyncOutboxStorage? syncOutboxStorage,
  }) : _storage = storage,
       _backupService = backupService,
       _reminderService = reminderService,
       _catalogStorage = catalogStorage,
       _historyStorage = historyStorage,
       _lookupService = lookupService,
       _homeWidgetService = homeWidgetService,
       _voiceRecognitionService = voiceRecognitionService,
       _firestoreInstance = firestoreInstance,
       _syncOutboxStorage = syncOutboxStorage;

  final ShoppingListsStorage? _storage;
  final ShoppingBackupService? _backupService;
  final ShoppingReminderService? _reminderService;
  final ProductCatalogStorage? _catalogStorage;
  final PurchaseHistoryStorage? _historyStorage;
  final ProductLookupService? _lookupService;
  final ShoppingHomeWidgetService? _homeWidgetService;
  final ShoppingVoiceRecognitionService? _voiceRecognitionService;
  final SyncOutboxStorage? _syncOutboxStorage;

  /// Instância pré-inicializada do Firestore (necessária na Web para evitar
  /// LateInitializationError com databaseId customizado).
  final FirebaseFirestore? _firestoreInstance;

  @override
  State<ShoppingListApp> createState() => _ShoppingListAppState();
}

class _ShoppingListAppState extends State<ShoppingListApp>
    with WidgetsBindingObserver {
  static const Duration _minimumLaunchDuration = Duration(milliseconds: 2500);
  static const Duration _cloudSyncDebounceDuration = Duration(
    milliseconds: 900,
  );
  static const Duration _cloudSyncRetryInterval = Duration(seconds: 25);
  static const String _themeModeKey = 'app_theme_mode_v1';
  static const String _onboardingCompletionKeyPrefix =
      'onboarding_completed_v1_';
  static const Set<String> _transientCloudErrorCodes = <String>{
    'unavailable',
    'deadline-exceeded',
    'aborted',
    'resource-exhausted',
  };

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();
  final Connectivity _connectivity = Connectivity();

  late final ShoppingListsStore _store;
  late final ShoppingBackupService _backupService;
  late final Future<void> _launchDelay;
  late final SyncOutboxCoordinator _syncOutbox;
  ShoppingVoiceRecognitionService? _voiceRecognitionService;
  FirestoreUserDataRepository? _cloudRepository;
  SharedListsRepository? _sharedListsRepository;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<Uri?>? _homeWidgetClickSubscription;
  Timer? _cloudSyncDebounce;
  Timer? _cloudSyncRetryTimer;
  User? _currentUser;
  bool _authStateResolved = false;
  bool _onboardingResolved = false;
  bool? _onboardingCompleted;
  bool _showOnboarding = false;
  bool _openCreateListAfterOnboarding = false;
  bool _isInitialCloudHydration = false;
  String? _hydratingCloudUid;
  String? _loadedCloudUid;
  bool _isApplyingCloudSnapshot = false;
  bool _isPushingCloudSnapshot = false;
  Completer<void>? _activeCloudPush;
  bool _cloudPushRequestedWhileActive = false;
  bool _isPullingCloudSnapshot = false;
  bool _isMirroringSharedLists = false;
  bool _isSigningOut = false;
  bool _storeReadyForOutbox = false;
  int _suppressStoreChangeTracking = 0;
  Future<void> _snapshotOutboxTail = Future<void>.value();
  Object? _lastOutboxWriteError;
  String? _outboxWriteErrorUid;
  bool _hasPendingCloudSync = false;
  bool _hasNetworkConnection = true;
  bool _notifySuccessOnNextSync = false;
  DateTime? _lastSuccessfulCloudSyncAt;
  DateTime? _lastSuccessfulSharedSyncAt;
  String? _lastCloudSyncError;
  String? _lastSharedSyncError;
  DateTime? _lastCloudSyncSnackAt;
  String? _lastCloudSyncSnackMessage;
  Uri? _pendingHomeWidgetLaunchUri;
  int _homeWidgetActionId = 0;

  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicializa os repositórios imediatamente com a instância do Firestore
    // já pronta (passada pelo main.dart), evitando LateInitializationError
    // no SDK Web quando o delegate é acessado antes de estar pronto.
    if (widget._storage == null) {
      _cloudRepository = FirestoreUserDataRepository(
        firestore: widget._firestoreInstance,
      );
      _sharedListsRepository = SharedListsRepository(
        firestore: widget._firestoreInstance,
      );
    }
    _backupService =
        widget._backupService ?? const FilePickerShoppingBackupService();
    _syncOutbox = SyncOutboxCoordinator(
      storage:
          widget._syncOutboxStorage ?? const SharedPrefsSyncOutboxStorage(),
    );
    final catalogStorage =
        widget._catalogStorage ??
        (widget._storage == null
            ? SharedPrefsProductCatalogStorage()
            : InMemoryProductCatalogStorage());
    final historyStorage =
        widget._historyStorage ??
        (widget._storage == null
            ? SharedPrefsPurchaseHistoryStorage()
            : InMemoryPurchaseHistoryStorage());
    final pantryStorage = widget._storage == null
        ? SharedPrefsPantryStorage()
        : InMemoryPantryStorage();
    final homeWidgetService =
        widget._homeWidgetService ??
        (widget._storage == null
            ? const AndroidShoppingHomeWidgetService()
            : const NoopShoppingHomeWidgetService());
    _voiceRecognitionService =
        widget._voiceRecognitionService ??
        (widget._storage == null
            ? SpeechToTextShoppingVoiceRecognitionService()
            : null);
    _store = ShoppingListsStore(
      widget._storage ?? SharedPrefsShoppingListsStorage(),
      reminderService:
          widget._reminderService ?? const NoopShoppingReminderService(),
      productCatalog: ProductCatalogRepository(catalogStorage),
      historyStorage: historyStorage,
      pantryStorage: pantryStorage,
      lookupService: widget._lookupService ?? _buildLookupService(),
      homeWidgetService: homeWidgetService,
      sharedCatalogImportPreferences: widget._storage == null
          ? const SharedPrefsSharedCatalogImportPreferences()
          : InMemorySharedCatalogImportPreferences(),
    )..load();
    if (widget._storage == null &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_initializeHomeWidgetActions());
    }
    final launchDuration = widget._storage == null
        ? _minimumLaunchDuration
        : Duration.zero;
    _launchDelay = Future<void>.delayed(launchDuration);
    if (widget._storage == null) {
      unawaited(_restoreThemeMode());
      unawaited(_startConnectivityTracking());
      _store.addListener(_handleStoreChanged);
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        final previousUid = _currentUser?.uid;
        _currentUser = user;
        _authStateResolved = true;

        if (user == null) {
          _storeReadyForOutbox = false;
          _isInitialCloudHydration = false;
          _hydratingCloudUid = null;
          _loadedCloudUid = null;
          _resetOnboardingState();
          _hasPendingCloudSync = false;
          _lastSuccessfulCloudSyncAt = null;
          _lastSuccessfulSharedSyncAt = null;
          _lastCloudSyncError = null;
          _lastSharedSyncError = null;
          _cloudSyncDebounce?.cancel();
          _stopCloudRetryTimer();
          unawaited(_clearLocalDataWithoutSyncTracking());
          if (mounted) {
            setState(() {});
          }
          return;
        }

        final isDifferentUser = previousUid != user.uid;
        if (isDifferentUser && previousUid != null) {
          _storeReadyForOutbox = false;
          unawaited(_clearLocalDataWithoutSyncTracking());
        }
        if (isDifferentUser) {
          _resetOnboardingState();
        }
        final needsInitialHydration = _loadedCloudUid != user.uid;
        if (isDifferentUser && needsInitialHydration) {
          _isInitialCloudHydration = true;
          _hydratingCloudUid = user.uid;
        }
        _hasPendingCloudSync = true;
        unawaited(_activateOutboxForUser(user.uid));
        if (mounted) {
          setState(() {});
        }
        _ensureCloudRetryTimer();
        if (needsInitialHydration) {
          unawaited(
            _pullFromCloud(user.uid, asInitialHydration: isDifferentUser),
          );
          return;
        }
        if (!_onboardingResolved) {
          unawaited(_resolveOnboardingForUser(user.uid));
        }
        _scheduleCloudSync(immediate: true);
      });
    }
  }

  ProductLookupService _buildLookupService() {
    return CompositeProductLookupService(buildDefaultProductLookupServices());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _homeWidgetClickSubscription?.cancel();
    _cloudSyncDebounce?.cancel();
    _stopCloudRetryTimer();
    if (widget._storage == null) {
      _store.removeListener(_handleStoreChanged);
    }
    _store.dispose();
    super.dispose();
  }

  Future<void> _initializeHomeWidgetActions() async {
    _homeWidgetClickSubscription = HomeWidget.widgetClicked.listen(
      _queueHomeWidgetAction,
    );
    try {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _queueHomeWidgetAction(initialUri);
    } on MissingPluginException {
      // The Android widget plugin is optional on unsupported platforms.
    } on PlatformException {
      // Keep normal app startup when the launcher does not return widget data.
    }
  }

  void _queueHomeWidgetAction(Uri? uri) {
    if (uri == null || !mounted) {
      return;
    }
    setState(() {
      _pendingHomeWidgetLaunchUri = uri;
      _homeWidgetActionId++;
    });
  }

  void _consumeHomeWidgetAction() {
    if (!mounted || _pendingHomeWidgetLaunchUri == null) {
      return;
    }
    setState(() {
      _pendingHomeWidgetLaunchUri = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || widget._storage != null) {
      return;
    }
    unawaited(_refreshConnectivityStatus());
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (_loadedCloudUid != uid) {
      unawaited(_pullFromCloud(uid));
      return;
    }
    unawaited(_mirrorSharedListsToLocal(uid, showSnack: true));
    _scheduleCloudSync(immediate: true);
  }

  Future<void> _waitForStoreLoaded() async {
    while (mounted && _store.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }
  }

  Future<void> _clearLocalDataWithoutSyncTracking() async {
    _suppressStoreChangeTracking++;
    try {
      await _store.clearAllLocalData();
    } finally {
      _suppressStoreChangeTracking--;
    }
  }

  Future<void> _activateOutboxForUser(String uid) async {
    await _waitForStoreLoaded();
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    await _snapshotOutboxTail;

    List<SyncOperation> pending;
    try {
      pending = await _syncOutbox.pending(userId: uid);
    } on FormatException catch (error) {
      debugPrint(
        '[CloudSync][outbox] dados inválidos; reconstruindo marcador local',
      );
      await _syncOutbox.clear(userId: uid);
      await _enqueueLegacySnapshotOperation(uid);
      pending = await _syncOutbox.pending(userId: uid);
      _lastCloudSyncError = 'outbox-local-invalida';
      _lastOutboxWriteError = null;
      _outboxWriteErrorUid = null;
      debugPrint(
        '[CloudSync][outbox] marcador reconstruído kind=${error.runtimeType}',
      );
    } catch (error) {
      pending = const <SyncOperation>[];
      _lastOutboxWriteError = error;
      _outboxWriteErrorUid = uid;
      _lastCloudSyncError = 'falha-outbox-local';
      _hasPendingCloudSync = true;
      _ensureCloudRetryTimer();
      debugPrint(
        '[CloudSync][outbox] falha ao carregar fila kind=${error.runtimeType}',
      );
    }

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    _storeReadyForOutbox = true;
    if (pending.isNotEmpty) {
      _hasPendingCloudSync = true;
      _ensureCloudRetryTimer();
      _scheduleCloudSync(immediate: true);
    }
    setState(() {});
  }

  void _queueLegacySnapshotOperation(String uid) {
    final previous = _snapshotOutboxTail;
    _snapshotOutboxTail = _appendLegacySnapshotOperation(
      previous: previous,
      uid: uid,
    );
  }

  Future<void> _appendLegacySnapshotOperation({
    required Future<void> previous,
    required String uid,
  }) async {
    try {
      await previous;
    } catch (_) {}
    try {
      await _enqueueLegacySnapshotOperation(uid);
      if (_outboxWriteErrorUid == null || _outboxWriteErrorUid == uid) {
        _lastOutboxWriteError = null;
        _outboxWriteErrorUid = null;
      }
    } catch (error) {
      _lastOutboxWriteError = error;
      _outboxWriteErrorUid = uid;
      _lastCloudSyncError = 'falha-outbox-local';
      debugPrint(
        '[CloudSync][outbox] falha ao persistir marcador kind=${error.runtimeType}',
      );
    }
  }

  Future<void> _enqueueLegacySnapshotOperation(String uid) async {
    final current = await _syncOutbox.pending(userId: uid);
    var nextRevision = 1;
    for (final operation in current) {
      if (operation.aggregateType == 'legacy-user-snapshot' &&
          operation.aggregateId == 'private-data' &&
          operation.revision >= nextRevision) {
        nextRevision = operation.revision + 1;
      }
    }
    await _syncOutbox.enqueue(
      userId: uid,
      operation: SyncOperation(
        operationId: 'snapshot_${uniqueId()}',
        aggregateType: 'legacy-user-snapshot',
        aggregateId: 'private-data',
        revision: nextRevision,
        kind: SyncOperationKind.upsert,
        payload: const <String, Object?>{'schemaVersion': 1},
        occurredAt: DateTime.now().toUtc(),
      ),
    );
  }

  Future<void> _recoverOrThrowOutboxWriteFailure(String uid) async {
    await _snapshotOutboxTail;
    if (_lastOutboxWriteError == null || _outboxWriteErrorUid != uid) {
      return;
    }
    try {
      await _enqueueLegacySnapshotOperation(uid);
      _lastOutboxWriteError = null;
      _outboxWriteErrorUid = null;
    } catch (_) {
      throw StateError('Não foi possível preservar a fila local.');
    }
  }

  Future<void> _mirrorSharedListsToLocal(
    String uid, {
    bool showSnack = false,
  }) async {
    final repository = _sharedListsRepository;
    if (widget._storage != null) {
      return;
    }
    if (repository == null) {
      return;
    }
    if (_isMirroringSharedLists) {
      return;
    }
    _isMirroringSharedLists = true;
    try {
      await _waitForStoreLoaded();
      final ownedShared = await repository.fetchOwnedSharedLists(uid);
      _lastSuccessfulSharedSyncAt = DateTime.now();
      _lastSharedSyncError = null;
      if (ownedShared.isEmpty) {
        if (mounted) {
          setState(() {});
        }
        return;
      }
      var mirroredCount = 0;
      for (final shared in ownedShared) {
        final sourceId = shared.sourceLocalListId?.trim() ?? '';
        final local = _store.findById(sourceId);
        final mirrorAction = resolveOwnedSharedListMirrorAction(
          hasSourceLocalListId: sourceId.isNotEmpty,
          hasLocalCopy: local != null,
          localUpdatedAt: local?.updatedAt,
          sharedUpdatedAt: shared.updatedAt,
        );
        if (mirrorAction == SharedListMirrorAction.skip) {
          continue;
        }
        final items = await repository.fetchListItems(shared.id);
        final listModel = ShoppingListModel(
          id: sourceId,
          name: shared.name,
          createdAt: local?.createdAt ?? shared.createdAt,
          updatedAt: shared.updatedAt,
          items: items
              .map((entry) => entry.toShoppingItem())
              .toList(growable: false),
          budget: shared.budget,
          reminder: shared.reminder,
          paymentBalances: shared.paymentBalances,
          isClosed: shared.isClosed,
          closedAt: shared.closedAt,
        );
        await _store.upsertList(
          listModel,
          ingestCatalog: _store.autoImportOwnedSharedCatalogs,
        );
        mirroredCount++;
      }
      if (showSnack && mirroredCount > 0) {
        _showCloudSyncNotification(
          'Listas compartilhadas sincronizadas.',
          duration: const Duration(seconds: 3),
          type: AppToastType.info,
        );
      }
    } catch (error, stack) {
      _lastSharedSyncError = _cloudErrorDetails(error);
      debugPrint('[share_sync] erro ao espelhar: $error');
      debugPrintStack(label: '[share_sync]', stackTrace: stack);
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isMirroringSharedLists = false;
    }
  }

  Future<void> _restoreThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    final restored = switch (raw) {
      'dark' => ThemeMode.dark,
      _ => ThemeMode.light,
    };
    if (!mounted) {
      return;
    }
    setState(() {
      _themeMode = restored;
    });
  }

  String _onboardingCompletionKeyForUser(String uid) {
    return '$_onboardingCompletionKeyPrefix$uid';
  }

  Future<bool?> _readLocalOnboardingCompletion(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _onboardingCompletionKeyForUser(uid);
    if (!prefs.containsKey(key)) {
      return null;
    }
    return prefs.getBool(key);
  }

  Future<void> _writeLocalOnboardingCompletion(String uid, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _onboardingCompletionKeyForUser(uid);
    await prefs.setBool(key, value);
  }

  void _resetOnboardingState() {
    _onboardingResolved = false;
    _onboardingCompleted = null;
    _showOnboarding = false;
    _openCreateListAfterOnboarding = false;
  }

  Future<void> _resolveOnboardingForUser(
    String uid, {
    FirestoreUserProfile? profile,
  }) async {
    bool? resolvedCompletion = profile?.isOnboardingCompleted;
    final fromCloud = resolvedCompletion != null;
    resolvedCompletion ??= await _readLocalOnboardingCompletion(uid);
    final shouldShow = resolvedCompletion != true;

    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }

    setState(() {
      _onboardingCompleted = resolvedCompletion ?? false;
      _showOnboarding = shouldShow;
      _onboardingResolved = true;
    });

    if (!fromCloud && resolvedCompletion == true) {
      _hasPendingCloudSync = true;
      _scheduleCloudSync(immediate: true, recordLocalChange: true);
    }
  }

  Future<void> _completeOnboarding({required bool createFirstList}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }

    await _writeLocalOnboardingCompletion(uid, true);
    if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }

    setState(() {
      _onboardingCompleted = true;
      _showOnboarding = false;
      _onboardingResolved = true;
      _openCreateListAfterOnboarding = createFirstList;
      _hasPendingCloudSync = true;
    });
    _scheduleCloudSync(immediate: true, recordLocalChange: true);
  }

  void _replayOnboarding() {
    if (!mounted || _currentUser == null) {
      return;
    }
    setState(() {
      _showOnboarding = true;
      _onboardingResolved = true;
      _openCreateListAfterOnboarding = false;
    });
  }

  void _consumeOnboardingCreateListShortcut() {
    if (!_openCreateListAfterOnboarding || !mounted) {
      return;
    }
    setState(() {
      _openCreateListAfterOnboarding = false;
    });
  }

  Future<void> _setThemeMode(ThemeMode mode, {bool syncCloud = true}) async {
    if (_themeMode == mode) {
      return;
    }
    setState(() {
      _themeMode = mode;
    });
    if (widget._storage == null) {
      final prefs = await SharedPreferences.getInstance();
      final raw = mode == ThemeMode.dark ? 'dark' : 'light';
      await prefs.setString(_themeModeKey, raw);
    }
    if (syncCloud) {
      _scheduleCloudSync(recordLocalChange: true);
    }
  }

  ThemeMode? _parseThemeMode(String? rawValue) {
    return switch (rawValue?.trim()) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => null,
    };
  }

  String? _resolveProviderId(User user) {
    for (final info in user.providerData) {
      final providerId = info.providerId.trim();
      if (providerId.isEmpty || providerId == 'firebase') {
        continue;
      }
      if (providerId == 'password' || providerId == 'google.com') {
        return providerId;
      }
      return null;
    }
    return null;
  }

  Future<void> _startConnectivityTracking() async {
    await _refreshConnectivityStatus(triggerSyncIfOnline: false);
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      _handleConnectivityChanged(results, triggerSyncIfOnline: true);
    });
  }

  Future<void> _refreshConnectivityStatus({
    bool triggerSyncIfOnline = true,
  }) async {
    try {
      final results = await _connectivity.checkConnectivity();
      _handleConnectivityChanged(
        results,
        triggerSyncIfOnline: triggerSyncIfOnline,
      );
    } catch (_) {}
  }

  void _handleConnectivityChanged(
    List<ConnectivityResult> results, {
    required bool triggerSyncIfOnline,
  }) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    final connectionChanged = hasConnection != _hasNetworkConnection;
    _hasNetworkConnection = hasConnection;

    if (connectionChanged && mounted) {
      setState(() {});
    }

    if (!hasConnection) {
      if (connectionChanged) {
        _showCloudSyncNotification(
          'Sem internet. As listas continuam salvas no aparelho.',
          type: AppToastType.warning,
        );
        final pendingRecords = _estimatedPendingCloudRecords();
        if (pendingRecords > 0) {
          unawaited(
            _store.notifySyncPending(
              pendingRecords: pendingRecords,
              hasNetworkConnection: false,
            ),
          );
        }
      }
      return;
    }

    if (!triggerSyncIfOnline) {
      return;
    }

    if (_hasPendingCloudSync) {
      if (connectionChanged) {
        _notifySuccessOnNextSync = true;
        _showCloudSyncNotification(
          'Internet detectada. Sincronizando listas.',
          type: AppToastType.info,
        );
      }
      _scheduleCloudSync(immediate: true);
    }
  }

  int _estimatedPendingCloudRecords() {
    if (!_hasPendingCloudSync) {
      return 0;
    }
    return _store.lists.length +
        _store.purchaseHistory.length +
        _store.catalogProducts.length;
  }

  void _showCloudSyncNotification(
    String message, {
    Duration duration = const Duration(seconds: 3),
    AppToastType type = AppToastType.info,
  }) {
    final messenger = _scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    final now = DateTime.now();
    if (_lastCloudSyncSnackMessage == message &&
        _lastCloudSyncSnackAt != null &&
        now.difference(_lastCloudSyncSnackAt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastCloudSyncSnackAt = now;
    _lastCloudSyncSnackMessage = message;
    AppToast.showWithMessenger(
      messenger,
      message: message,
      type: type,
      duration: duration,
    );
  }

  String _cloudErrorCode(Object error) {
    if (error is FirebaseException) {
      final code = error.code.trim();
      return code.isEmpty ? 'firebase-error' : code;
    }
    return 'erro-desconhecido';
  }

  bool _isTransientCloudError(Object error) {
    if (error is FirebaseException) {
      return _transientCloudErrorCodes.contains(
        error.code.trim().toLowerCase(),
      );
    }
    return false;
  }

  String _cloudErrorDetails(Object error) {
    if (error is FirebaseException) {
      final code = _cloudErrorCode(error);
      final message = (error.message ?? '').trim();
      if (message.isEmpty) {
        return code;
      }
      return '$code: $message';
    }
    return error.toString();
  }

  void _logCloudError(String stage, Object error, StackTrace stack) {
    debugPrint('[CloudSync][$stage] ${_cloudErrorDetails(error)}');
    debugPrintStack(label: '[CloudSync][$stage]', stackTrace: stack);
  }

  Future<void> _pullFromCloud(
    String uid, {
    bool asInitialHydration = false,
  }) async {
    if (_loadedCloudUid == uid) {
      return;
    }
    // Guard contra múltiplas execuções paralelas do pull.
    // Sem esse guard, o _scheduleCloudSync agendado pelo authStateChanges
    // pode disparar um segundo _pullFromCloud enquanto o primeiro ainda está
    // em andamento, causando LateInitializationError no SDK Web do Firestore.
    if (_isPullingCloudSnapshot) {
      debugPrint(
        '[CloudSync][pull] já em andamento; chamada duplicada ignorada',
      );
      return;
    }
    _isPullingCloudSnapshot = true;
    final repository = _cloudRepository;
    if (repository == null) {
      _isPullingCloudSnapshot = false;
      return;
    }
    try {
      debugPrint(
        '[CloudSync][pull] iniciando; hidrataçãoInicial=$asInitialHydration',
      );
      await _waitForStoreLoaded();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        debugPrint(
          '[CloudSync][pull] abortado: usuário mudou ou widget desmontado',
        );
        return;
      }
      debugPrint('[CloudSync][pull] chamando loadUserSnapshot...');
      final snapshot = await repository.loadUserSnapshot(uid);
      _lastCloudSyncError = null;
      debugPrint(
        '[CloudSync][pull] loadUserSnapshot OK — hasCoreData=${snapshot.hasCoreData}',
      );
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }

      final hasCloudCoreData = snapshot.hasCoreData;
      if (hasCloudCoreData) {
        debugPrint(
          '[CloudSync][pull] importando snapshot: listas=${snapshot.lists.length} histórico=${snapshot.history.length} catálogo=${snapshot.catalog.length} despensa=${snapshot.pantry.length}',
        );
        final payload = jsonEncode({
          'version': 4,
          'exportedAt': DateTime.now().toIso8601String(),
          'lists': snapshot.lists.map((entry) => entry.toJson()).toList(),
          'purchaseHistory': snapshot.history
              .map((entry) => entry.toJson())
              .toList(),
          'catalog': snapshot.catalog.map((entry) => entry.toJson()).toList(),
          'pantry': snapshot.pantry.map((entry) => entry.toJson()).toList(),
        });
        try {
          _isApplyingCloudSnapshot = true;
          debugPrint('[CloudSync][pull] chamando importBackupJson...');
          await _store.importBackupJson(payload, replaceExisting: true);
          debugPrint('[CloudSync][pull] importBackupJson OK');
        } finally {
          _isApplyingCloudSnapshot = false;
        }
      }

      debugPrint(
        '[CloudSync][pull] aplicando tema da nuvem (themeMode=${snapshot.settings.themeMode})...',
      );
      final cloudTheme = _parseThemeMode(snapshot.settings.themeMode);
      if (cloudTheme != null && cloudTheme != _themeMode) {
        await _setThemeMode(cloudTheme, syncCloud: false);
      }
      if (snapshot.settings.hasData) {
        _suppressStoreChangeTracking++;
        try {
          await _store.applySharedCatalogImportSettings(
            autoImportOwnedSharedCatalogs:
                snapshot.settings.autoImportOwnedSharedCatalogs,
            autoImportAllSharedCatalogs:
                snapshot.settings.autoImportSharedCatalogs,
            enabledSharedListIds: snapshot.settings.sharedCatalogImportListIds,
          );
        } finally {
          _suppressStoreChangeTracking--;
        }
      }
      debugPrint('[CloudSync][pull] tema OK');

      debugPrint('[CloudSync][pull] vinculando snapshot ao usuário atual');
      _loadedCloudUid = uid;
      debugPrint('[CloudSync][pull] chamando _resolveOnboardingForUser...');
      await _resolveOnboardingForUser(uid, profile: snapshot.profile);
      debugPrint('[CloudSync][pull] _resolveOnboardingForUser OK');
      unawaited(_mirrorSharedListsToLocal(uid));
      _hasPendingCloudSync = true;
      if (mounted) {
        setState(() {});
      }
      _ensureCloudRetryTimer();
      debugPrint('[CloudSync][pull] agendando push via _scheduleCloudSync...');
      // Agenda o push via debounce em vez de chamar diretamente,
      // evitando que dois _pushToCloud rodem em paralelo (um via
      // _scheduleCloudSync e outro direto), o que causava
      // LateInitializationError no SDK Web do Firestore.
      _scheduleCloudSync(immediate: true);
      debugPrint('[CloudSync][pull] concluído com sucesso');
    } catch (error, stack) {
      _lastCloudSyncError = _cloudErrorDetails(error);
      _logCloudError('pull', error, stack);
      // LateInitializationError com nome vazio ('') é causado pelo dart2js
      // em modo release (--omit-late-names) quando o SDK JS do Firebase ainda
      // não terminou de inicializar internamente. Tratamos como erro transiente
      // e tentamos novamente silenciosamente, sem exibir mensagem ao usuário.
      final isLateInitError = error.toString().contains(
        'LateInitializationError',
      );
      if (!_onboardingResolved) {
        debugPrint(
          '[CloudSync][pull] resolvendo onboarding no catch (isLateInitError=$isLateInitError)...',
        );
        await _resolveOnboardingForUser(uid);
      }
      _hasPendingCloudSync = true;
      _notifySuccessOnNextSync = true;
      _ensureCloudRetryTimer();
      if (!isLateInitError) {
        if (_isTransientCloudError(error)) {
          _showCloudSyncNotification(
            'Servidor da nuvem indisponível no momento. Continuando offline e tentando novamente.',
            duration: const Duration(seconds: 6),
            type: AppToastType.warning,
          );
        } else {
          _showCloudSyncNotification(
            'Falha ao carregar dados online: ${_cloudErrorDetails(error)}',
            duration: const Duration(seconds: 8),
            type: AppToastType.error,
          );
        }
      }
      if (mounted) {
        setState(() {});
      }
    } finally {
      _isPullingCloudSnapshot = false;
      // Sempre limpa o estado de hydration inicial se este pull era para o
      // uid atual, independente de asInitialHydration. Isso evita que um erro
      // na segunda chamada (asInitialHydration=false) deixe _isInitialCloudHydration
      // preso em true para sempre, causando loading eterno na Web.
      if (_hydratingCloudUid == uid && mounted) {
        debugPrint('[CloudSync][pull] finalizando hidratação inicial');
        setState(() {
          _isInitialCloudHydration = false;
          _hydratingCloudUid = null;
        });
      }
    }
  }

  void _handleStoreChanged() {
    if (widget._storage != null ||
        _store.isLoading ||
        _isApplyingCloudSnapshot ||
        !_storeReadyForOutbox ||
        _suppressStoreChangeTracking > 0) {
      return;
    }
    _scheduleCloudSync(recordLocalChange: true);
  }

  void _scheduleCloudSync({
    bool immediate = false,
    bool recordLocalChange = false,
  }) {
    if (widget._storage != null ||
        _store.isLoading ||
        _isApplyingCloudSnapshot) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    if (recordLocalChange) {
      _queueLegacySnapshotOperation(uid);
    }
    if (!_hasPendingCloudSync) {
      _hasPendingCloudSync = true;
      if (mounted) {
        setState(() {});
      }
    }
    _ensureCloudRetryTimer();
    _cloudSyncDebounce?.cancel();
    final delay = immediate ? Duration.zero : _cloudSyncDebounceDuration;
    _cloudSyncDebounce = Timer(delay, () {
      if (_loadedCloudUid != uid) {
        unawaited(_pullFromCloud(uid));
        return;
      }
      unawaited(_pushToCloud(uid));
    });
  }

  Future<void> _pushToCloud(String uid) async {
    if (widget._storage != null) {
      return;
    }
    final repository = _cloudRepository;
    if (repository == null) {
      return;
    }
    if (_isPushingCloudSnapshot) {
      debugPrint('[CloudSync][push] aguardando sincronização já iniciada');
      _cloudPushRequestedWhileActive = true;
      await _activeCloudPush?.future;
      return;
    }
    if (_isApplyingCloudSnapshot) {
      debugPrint('[CloudSync][push] ignorado durante aplicação da nuvem');
      return;
    }
    if (_loadedCloudUid != uid) {
      debugPrint(
        '[CloudSync][push] aguardando vínculo do snapshot com o usuário atual',
      );
      _ensureCloudRetryTimer();
      return;
    }
    if (!_hasNetworkConnection) {
      debugPrint('[CloudSync][push] ignorado: sem conexão de rede');
      if (!_hasPendingCloudSync) {
        _hasPendingCloudSync = true;
        if (mounted) {
          setState(() {});
        }
      }
      _ensureCloudRetryTimer();
      return;
    }
    if (!_hasPendingCloudSync && _loadedCloudUid == uid) {
      debugPrint('[CloudSync][push] ignorado: nada pendente');
      return;
    }

    debugPrint(
      '[CloudSync][push] iniciando snapshot — listas=${_store.lists.length} histórico=${_store.purchaseHistory.length} catálogo=${_store.catalogProducts.length} despensa=${_store.pantryItems.length}',
    );
    final activePush = Completer<void>();
    _activeCloudPush = activePush;
    _isPushingCloudSnapshot = true;
    if (mounted) {
      setState(() {});
    }
    try {
      do {
        _cloudPushRequestedWhileActive = false;
        await _recoverOrThrowOutboxWriteFailure(uid);
        final outboxBatch = await _syncOutbox.captureForPush(userId: uid);
        final currentUser = FirebaseAuth.instance.currentUser;
        final profile = currentUser == null
            ? null
            : FirestoreUserProfile(
                uid: uid,
                displayName: currentUser.displayName,
                email: currentUser.email,
                photoUrl: currentUser.photoURL,
                provider: _resolveProviderId(currentUser),
                themeMode: _themeMode == ThemeMode.dark ? 'dark' : 'light',
                isOnboardingCompleted: _onboardingCompleted,
              );
        await repository.saveUserSnapshot(
          uid: uid,
          lists: _store.lists,
          history: _store.purchaseHistory,
          catalog: _store.catalogProducts,
          pantry: _store.pantryItems,
          settings: FirestoreUserAppSettings(
            themeMode: _themeMode == ThemeMode.dark ? 'dark' : 'light',
            autoImportOwnedSharedCatalogs: _store.autoImportOwnedSharedCatalogs,
            autoImportSharedCatalogs: _store.autoImportAllSharedCatalogs,
            sharedCatalogImportListIds: _store.sharedCatalogImportListIds,
          ),
          profile: profile,
        );
        debugPrint(
          '[CloudSync][push] saveUserSnapshot OK — sincronização concluída!',
        );
        await _recoverOrThrowOutboxWriteFailure(uid);
        await _syncOutbox.acknowledge(outboxBatch);
        final pendingOperations = await _syncOutbox.pending(userId: uid);
        _hasPendingCloudSync =
            _cloudPushRequestedWhileActive || pendingOperations.isNotEmpty;
        _loadedCloudUid = uid;
        _lastSuccessfulCloudSyncAt = DateTime.now();
        _lastCloudSyncError = null;
        if (!_hasPendingCloudSync) {
          _stopCloudRetryTimer();
        }
        if (_notifySuccessOnNextSync && !_hasPendingCloudSync) {
          _notifySuccessOnNextSync = false;
          _showCloudSyncNotification(
            'Sincronização concluída.',
            type: AppToastType.success,
          );
        }
        if (mounted) {
          setState(() {});
        }
      } while (_cloudPushRequestedWhileActive && _hasNetworkConnection);
    } catch (error, stack) {
      _lastCloudSyncError = _cloudErrorDetails(error);
      _logCloudError('push', error, stack);
      _hasPendingCloudSync = true;
      _notifySuccessOnNextSync = true;
      _ensureCloudRetryTimer();
      if (mounted && _hasNetworkConnection) {
        if (_isTransientCloudError(error)) {
          _showCloudSyncNotification(
            'Sincronização pausada: servidor indisponível. Tentaremos novamente automático.',
            duration: const Duration(seconds: 6),
            type: AppToastType.warning,
          );
        } else {
          _showCloudSyncNotification(
            'Falha ao sincronizar: ${_cloudErrorDetails(error)}',
            duration: const Duration(seconds: 8),
            type: AppToastType.error,
          );
        }
        setState(() {});
      }
    } finally {
      _isPushingCloudSnapshot = false;
      if (!activePush.isCompleted) {
        activePush.complete();
      }
      if (identical(_activeCloudPush, activePush)) {
        _activeCloudPush = null;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _ensureCloudRetryTimer() {
    if (_cloudSyncRetryTimer != null) {
      return;
    }
    _cloudSyncRetryTimer = Timer.periodic(_cloudSyncRetryInterval, (_) {
      if (!_hasPendingCloudSync || _isApplyingCloudSnapshot) {
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) {
        return;
      }
      if (_loadedCloudUid != uid) {
        unawaited(_pullFromCloud(uid));
        return;
      }
      unawaited(_pushToCloud(uid));
    });
  }

  void _stopCloudRetryTimer() {
    _cloudSyncRetryTimer?.cancel();
    _cloudSyncRetryTimer = null;
  }

  Future<void> _signOut({required bool discardPendingChanges}) async {
    if (_isSigningOut) {
      return;
    }
    _isSigningOut = true;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    SyncPushBatch? discardedBatch;
    _cloudSyncDebounce?.cancel();
    _stopCloudRetryTimer();
    try {
      if (discardPendingChanges && uid.isNotEmpty) {
        await _recoverOrThrowOutboxWriteFailure(uid);
        discardedBatch = await _syncOutbox.captureForPush(userId: uid);
        await _syncOutbox.clear(userId: uid);
      }
      await FirebaseAuth.instance.signOut();
      if (discardPendingChanges) {
        _hasPendingCloudSync = false;
      }
    } catch (_) {
      final operationsToRestore = discardedBatch?.operations;
      if (operationsToRestore != null) {
        try {
          for (final operation in operationsToRestore) {
            await _syncOutbox.enqueue(userId: uid, operation: operation);
          }
        } catch (error) {
          _lastOutboxWriteError = error;
          _outboxWriteErrorUid = uid;
          debugPrint(
            '[CloudSync][outbox] falha ao restaurar descarte kind=${error.runtimeType}',
          );
        }
      }
      if (_hasPendingCloudSync) {
        _ensureCloudRetryTimer();
      }
      rethrow;
    } finally {
      _isSigningOut = false;
    }
  }

  Future<void> _refreshCurrentUserProfile() async {
    if (widget._storage != null) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null) {
      final repository = FirestoreUserDataRepository();
      final migrated = await repository.migrateProfilePhotoToStoragePath(
        user: refreshed,
      );
      if (migrated && mounted) {
        setState(() {});
      }
    }
    if (!mounted) {
      return;
    }
    _currentUser = FirebaseAuth.instance.currentUser;
    _hasPendingCloudSync = true;
    _scheduleCloudSync(immediate: true, recordLocalChange: true);
    setState(() {});
  }

  Future<void> _syncNowFromDiagnostics() async {
    if (widget._storage != null) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (uid.isEmpty) {
      throw StateError('Faça login para sincronizar.');
    }
    _cloudSyncDebounce?.cancel();
    await _refreshConnectivityStatus(triggerSyncIfOnline: false);
    if (!_hasNetworkConnection) {
      _hasPendingCloudSync = true;
      if (mounted) {
        setState(() {});
      }
      throw StateError('Sem internet para sincronizar agora.');
    }
    if (_loadedCloudUid != uid) {
      await _pullFromCloud(uid);
    }
    await _mirrorSharedListsToLocal(uid);
    _cloudSyncDebounce?.cancel();
    _hasPendingCloudSync = true;
    if (mounted) {
      setState(() {});
    }
    await _pushToCloud(uid);
    if (_lastCloudSyncError != null) {
      throw StateError(_lastCloudSyncError!);
    }
  }

  Future<SyncDiagnosticsSnapshot?> _refreshSyncDiagnosticsSnapshot() async {
    if (widget._storage != null) {
      return null;
    }
    return _buildSyncDiagnosticsSnapshot();
  }

  SyncDiagnosticsSnapshot _buildSyncDiagnosticsSnapshot() {
    final user = FirebaseAuth.instance.currentUser ?? _currentUser;
    final listRecords = _store.lists.length;
    final historyRecords = _store.purchaseHistory.length;
    final catalogRecords = _store.catalogProducts.length;
    final pantryRecords = _store.pantryItems.length;
    final totalSyncRecords =
        listRecords + historyRecords + catalogRecords + pantryRecords;
    final pendingSyncRecords = (_hasPendingCloudSync || _isPushingCloudSnapshot)
        ? totalSyncRecords
        : 0;
    final lastError = _lastCloudSyncError ?? _lastSharedSyncError;
    return SyncDiagnosticsSnapshot(
      generatedAt: DateTime.now(),
      userName: user?.displayName,
      userEmail: user?.email,
      userUid: user?.uid,
      providerId: user == null ? null : _resolveProviderId(user),
      projectId: widget._firestoreInstance?.app.options.projectId,
      platformLabel: _platformLabel(),
      appVersion: '1.0.0+1',
      hasInternetConnection: _hasNetworkConnection,
      hasPendingCloudSync: _hasPendingCloudSync,
      isCloudSyncing: _isPushingCloudSnapshot,
      isPullingCloudSnapshot: _isPullingCloudSnapshot,
      isMirroringSharedLists: _isMirroringSharedLists,
      lastCloudSyncAt: _lastSuccessfulCloudSyncAt,
      lastSharedSyncAt: _lastSuccessfulSharedSyncAt,
      totalSyncRecords: totalSyncRecords,
      pendingSyncRecords: pendingSyncRecords,
      listRecords: listRecords,
      historyRecords: historyRecords,
      catalogRecords: catalogRecords,
      pantryRecords: pantryRecords,
      sharedListCount: 0,
      autoImportOwnedSharedCatalogs: _store.autoImportOwnedSharedCatalogs,
      autoImportAllSharedCatalogs: _store.autoImportAllSharedCatalogs,
      enabledSharedCatalogImportCount: _store.sharedCatalogImportListIds.length,
      lastError: lastError,
      sharedLists: const <SharedListDiagnosticEntry>[],
    );
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'Web';
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.fuchsia => 'Fuchsia',
    };
  }

  TextTheme _buildAppTextTheme(TextTheme baseTextTheme) {
    final bodyTheme = GoogleFonts.nunitoSansTextTheme(baseTextTheme);
    return bodyTheme.copyWith(
      displaySmall: GoogleFonts.rubik(
        textStyle: bodyTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      headlineMedium: GoogleFonts.rubik(
        textStyle: bodyTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      headlineSmall: GoogleFonts.rubik(
        textStyle: bodyTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      titleLarge: GoogleFonts.rubik(
        textStyle: bodyTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
      titleMedium: GoogleFonts.rubik(
        textStyle: bodyTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      titleSmall: GoogleFonts.rubik(
        textStyle: bodyTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      bodyLarge: bodyTheme.bodyLarge?.copyWith(height: 1.38),
      bodyMedium: bodyTheme.bodyMedium?.copyWith(height: 1.36),
      bodySmall: bodyTheme.bodySmall?.copyWith(height: 1.3),
      labelLarge: GoogleFonts.nunitoSans(
        textStyle: bodyTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      labelMedium: GoogleFonts.nunitoSans(
        textStyle: bodyTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    final base = FlexThemeData.light(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colors: const FlexSchemeColor(
        primary: Color(0xFF0D9488),
        primaryContainer: Color(0xFFCCFBF1),
        secondary: Color(0xFF0F766E),
        secondaryContainer: Color(0xFFD1FAE5),
        tertiary: _actionColor,
        tertiaryContainer: Color(0xFFFFEDD5),
        appBarColor: Color(0xFFF8FAFC),
        error: Color(0xFFB3261E),
      ),
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 4,
      scaffoldBackground: const Color(0xFFF8FAFC),
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        blendOnLevel: 4,
      ),
    );
    final scheme = base.colorScheme;
    final textTheme = _buildAppTextTheme(base.textTheme);
    return base.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      textTheme: textTheme,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.42),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.cardElevation,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusXl)),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _actionColor,
          foregroundColor: _actionForegroundColor,
          minimumSize: const Size(0, AppTokens.controlHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _actionColor,
        foregroundColor: _actionForegroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXs),
        ),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.9),
          width: 1.4,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll<Color?>(
          scheme.outlineVariant.withValues(alpha: 0.36),
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.62)),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 450),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(12),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.34),
              ),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radius2Xl),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFFFFFFFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.92),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final base = FlexThemeData.dark(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      colors: const FlexSchemeColor(
        primary: Color(0xFF4ED7C7),
        primaryContainer: Color(0xFF005C52),
        secondary: Color(0xFF8ECFC6),
        secondaryContainer: Color(0xFF24453F),
        tertiary: _actionColor,
        tertiaryContainer: Color(0xFF7C2D12),
        appBarColor: Color(0xFF0F161A),
        error: Color(0xFFF2A29D),
      ),
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 8,
      scaffoldBackground: const Color(0xFF0F161A),
      subThemesData: const FlexSubThemesData(
        interactionEffects: true,
        blendOnLevel: 8,
      ),
    );
    final scheme = base.colorScheme;
    final textTheme = _buildAppTextTheme(base.textTheme);
    return base.copyWith(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: const Color(0xFF0F161A),
      textTheme: textTheme,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.44),
        thickness: 1,
      ),
      cardTheme: CardThemeData(
        elevation: AppTokens.cardElevation,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: const Color(0xFF1A252A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusXl)),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.48),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F161A),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFF1E2A2F),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.9),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _actionColor,
          foregroundColor: _actionForegroundColor,
          minimumSize: const Size(0, AppTokens.controlHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeightLg),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppTokens.controlHeight),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelLarge),
          padding: const WidgetStatePropertyAll<EdgeInsets>(
            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _actionColor,
        foregroundColor: _actionForegroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusXs),
        ),
        visualDensity: VisualDensity.compact,
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.92),
          width: 1.4,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll<Color?>(
          scheme.outlineVariant.withValues(alpha: 0.38),
        ),
        thumbColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.onPrimary;
          }
          return scheme.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.surfaceContainerHighest;
        }),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.48)),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 450),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.all(12),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(scheme.surface),
          surfaceTintColor: const WidgetStatePropertyAll<Color>(
            Colors.transparent,
          ),
          shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.36),
              ),
            ),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppTokens.radius2Xl),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTransitionShell({
    required Widget child,
    required String stateKey,
  }) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return KeyedSubtree(key: ValueKey<String>(stateKey), child: child);
    }
    return AnimatedSwitcher(
      duration: AppTokens.motionSlow,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (widget, animation) {
        final opacity = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: opacity,
          child: ScaleTransition(scale: scale, child: widget),
        );
      },
      child: KeyedSubtree(key: ValueKey<String>(stateKey), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Minhas Compras',
      supportedLocales: const <Locale>[Locale('pt', 'BR'), Locale('en', 'US')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      home: FutureBuilder<void>(
        future: _launchDelay,
        builder: (context, launchSnapshot) {
          return AnimatedBuilder(
            animation: _store,
            builder: (context, _) {
              final launchReady =
                  launchSnapshot.connectionState == ConnectionState.done;
              if (!launchReady || _store.isLoading) {
                return _buildHomeTransitionShell(
                  stateKey: 'boot-loading',
                  child: LoadingScreen(
                    showReadyHint: launchReady && _store.isLoading,
                  ),
                );
              }
              final listRecords = _store.lists.length;
              final historyRecords = _store.purchaseHistory.length;
              final catalogRecords = _store.catalogProducts.length;
              final pantryRecords = _store.pantryItems.length;
              final totalSyncRecords =
                  listRecords + historyRecords + catalogRecords + pantryRecords;
              final pendingSyncRecords =
                  (_hasPendingCloudSync || _isPushingCloudSnapshot)
                  ? totalSyncRecords
                  : 0;

              if (widget._storage == null) {
                if (!_authStateResolved) {
                  return _buildHomeTransitionShell(
                    stateKey: 'auth-resolve',
                    child: const LoadingScreen(showReadyHint: true),
                  );
                }
                final user = _currentUser;
                if (user == null) {
                  return _buildHomeTransitionShell(
                    stateKey: 'auth-page',
                    child: AuthPage(
                      themeMode: _themeMode,
                      onThemeModeChanged: (mode) {
                        unawaited(_setThemeMode(mode));
                      },
                    ),
                  );
                }
                final isHydratingLoggedUser =
                    _isInitialCloudHydration && _hydratingCloudUid == user.uid;
                if (isHydratingLoggedUser) {
                  return _buildHomeTransitionShell(
                    stateKey: 'cloud-hydration',
                    child: const LoadingScreen(showReadyHint: true),
                  );
                }
                if (!_onboardingResolved) {
                  return _buildHomeTransitionShell(
                    stateKey: 'onboarding-resolve',
                    child: const LoadingScreen(showReadyHint: true),
                  );
                }
                if (_showOnboarding) {
                  return _buildHomeTransitionShell(
                    stateKey: 'onboarding',
                    child: OnboardingPage(
                      themeMode: _themeMode,
                      onThemeModeChanged: (mode) {
                        unawaited(_setThemeMode(mode));
                      },
                      onSkip: () => _completeOnboarding(createFirstList: false),
                      onComplete: ({required bool createFirstList}) =>
                          _completeOnboarding(createFirstList: createFirstList),
                    ),
                  );
                }
                return _buildHomeTransitionShell(
                  stateKey: 'dashboard-auth',
                  child: DashboardPage(
                    store: _store,
                    backupService: _backupService,
                    sharedListsRepository: _sharedListsRepository,
                    themeMode: _themeMode,
                    onThemeModeChanged: _setThemeMode,
                    userDisplayName: user.displayName,
                    userEmail: user.email,
                    userPhotoUrl: user.photoURL,
                    onSignOut: _signOut,
                    onProfileUpdated: _refreshCurrentUserProfile,
                    showCloudSyncStatus: true,
                    hasInternetConnection: _hasNetworkConnection,
                    hasPendingCloudSync: _hasPendingCloudSync,
                    isCloudSyncing: _isPushingCloudSnapshot,
                    lastCloudSyncAt: _lastSuccessfulCloudSyncAt,
                    totalSyncRecords: totalSyncRecords,
                    pendingSyncRecords: pendingSyncRecords,
                    listRecords: listRecords,
                    historyRecords: historyRecords,
                    catalogRecords: catalogRecords,
                    pantryRecords: pantryRecords,
                    syncDiagnostics: _buildSyncDiagnosticsSnapshot(),
                    onSyncNow: _syncNowFromDiagnostics,
                    onRefreshSyncDiagnostics: _refreshSyncDiagnosticsSnapshot,
                    onReplayOnboarding: _replayOnboarding,
                    openCreateListOnStart: _openCreateListAfterOnboarding,
                    onCreateListShortcutConsumed:
                        _consumeOnboardingCreateListShortcut,
                    voiceRecognitionService: _voiceRecognitionService,
                    homeWidgetLaunchUri: _pendingHomeWidgetLaunchUri,
                    homeWidgetActionId: _homeWidgetActionId,
                    onHomeWidgetActionConsumed: _consumeHomeWidgetAction,
                  ),
                );
              }

              return _buildHomeTransitionShell(
                stateKey: 'dashboard-local',
                child: DashboardPage(
                  store: _store,
                  backupService: _backupService,
                  sharedListsRepository: _sharedListsRepository,
                  themeMode: _themeMode,
                  onThemeModeChanged: _setThemeMode,
                  userDisplayName: null,
                  userEmail: null,
                  userPhotoUrl: null,
                  onReplayOnboarding: null,
                  openCreateListOnStart: false,
                  onCreateListShortcutConsumed: null,
                  voiceRecognitionService: _voiceRecognitionService,
                  homeWidgetLaunchUri: _pendingHomeWidgetLaunchUri,
                  homeWidgetActionId: _homeWidgetActionId,
                  onHomeWidgetActionConsumed: _consumeHomeWidgetAction,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
