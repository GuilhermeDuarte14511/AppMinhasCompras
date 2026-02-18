import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../data/local/storages.dart';
import '../data/remote/cosmos_product_lookup_service.dart';
import '../data/remote/firebase_user_data_repository.dart';
import '../data/remote/open_food_facts_product_lookup_service.dart';
import '../data/remote/shared_lists_repository.dart';
import '../data/repositories/product_catalog_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/reminder_service.dart';
import '../presentation/auth_page.dart';
import '../presentation/launch.dart';
import '../presentation/onboarding_page.dart';
import '../presentation/pages.dart';
import '../presentation/theme/app_tokens.dart';
import '../presentation/utils/app_toast.dart';

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
    FirebaseFirestore? firestoreInstance,
  }) : _storage = storage,
       _backupService = backupService,
       _reminderService = reminderService,
       _catalogStorage = catalogStorage,
       _historyStorage = historyStorage,
       _lookupService = lookupService,
       _homeWidgetService = homeWidgetService,
       _firestoreInstance = firestoreInstance;

  final ShoppingListsStorage? _storage;
  final ShoppingBackupService? _backupService;
  final ShoppingReminderService? _reminderService;
  final ProductCatalogStorage? _catalogStorage;
  final PurchaseHistoryStorage? _historyStorage;
  final ProductLookupService? _lookupService;
  final ShoppingHomeWidgetService? _homeWidgetService;
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
  static const String _cosmosTokenFromDefine = String.fromEnvironment(
    'COSMOS_API_TOKEN',
  );
  static const String _cosmosHardcodedToken = '4hrzg_tHwg2TqECZotwqDg';
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
  late final FirestoreUserDataRepository _cloudRepository;
  late final SharedListsRepository _sharedListsRepository;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
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
  bool _isPullingCloudSnapshot = false;
  bool _hasPendingCloudSync = false;
  bool _hasNetworkConnection = true;
  bool _notifySuccessOnNextSync = false;
  DateTime? _lastSuccessfulCloudSyncAt;
  DateTime? _lastCloudSyncSnackAt;
  String? _lastCloudSyncSnackMessage;

  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicializa os repositórios imediatamente com a instância do Firestore
    // já pronta (passada pelo main.dart), evitando LateInitializationError
    // no SDK Web quando o delegate é acessado antes de estar pronto.
    _cloudRepository = FirestoreUserDataRepository(
      firestore: widget._firestoreInstance,
    );
    _sharedListsRepository = SharedListsRepository(
      firestore: widget._firestoreInstance,
    );
    _backupService =
        widget._backupService ?? const FilePickerShoppingBackupService();
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
    final homeWidgetService =
        widget._homeWidgetService ??
        (widget._storage == null
            ? const AndroidShoppingHomeWidgetService()
            : const NoopShoppingHomeWidgetService());
    _store = ShoppingListsStore(
      widget._storage ?? SharedPrefsShoppingListsStorage(),
      reminderService:
          widget._reminderService ?? const NoopShoppingReminderService(),
      productCatalog: ProductCatalogRepository(catalogStorage),
      historyStorage: historyStorage,
      lookupService: widget._lookupService ?? _buildLookupService(),
      homeWidgetService: homeWidgetService,
    )..load();
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
          _isInitialCloudHydration = false;
          _hydratingCloudUid = null;
          _loadedCloudUid = null;
          _resetOnboardingState();
          _hasPendingCloudSync = false;
          _lastSuccessfulCloudSyncAt = null;
          _cloudSyncDebounce?.cancel();
          _stopCloudRetryTimer();
          if (mounted) {
            setState(() {});
          }
          return;
        }

        final isDifferentUser = previousUid != user.uid;
        if (isDifferentUser) {
          _resetOnboardingState();
        }
        final needsInitialHydration = _loadedCloudUid != user.uid;
        if (isDifferentUser && needsInitialHydration) {
          _isInitialCloudHydration = true;
          _hydratingCloudUid = user.uid;
        }
        _hasPendingCloudSync = true;
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
    final services = <ProductLookupService>[];
    final cosmosToken = _cosmosTokenFromDefine.trim().isNotEmpty
        ? _cosmosTokenFromDefine
        : _cosmosHardcodedToken;
    if (cosmosToken.trim().isNotEmpty) {
      services.add(CosmosProductLookupService(token: cosmosToken));
    }
    services.addAll(const <ProductLookupService>[
      OpenProductsFactsProductLookupService(),
      OpenFoodFactsProductLookupService(),
    ]);
    return CompositeProductLookupService(services);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _cloudSyncDebounce?.cancel();
    _stopCloudRetryTimer();
    if (widget._storage == null) {
      _store.removeListener(_handleStoreChanged);
    }
    _store.dispose();
    super.dispose();
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
    _scheduleCloudSync(immediate: true);
  }

  Future<void> _waitForStoreLoaded() async {
    while (mounted && _store.isLoading) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
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
      _scheduleCloudSync(immediate: true);
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
    _scheduleCloudSync(immediate: true);
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
      _scheduleCloudSync();
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
      debugPrint('[CloudSync][pull] já em andamento, ignorando chamada duplicada para uid=$uid');
      return;
    }
    _isPullingCloudSnapshot = true;
    final repository = _cloudRepository;
    try {
      debugPrint('[CloudSync][pull] iniciando para uid=$uid asInitialHydration=$asInitialHydration');
      await _waitForStoreLoaded();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        debugPrint('[CloudSync][pull] abortado: usuário mudou ou widget desmontado');
        return;
      }
      debugPrint('[CloudSync][pull] chamando loadUserSnapshot...');
      final snapshot = await repository.loadUserSnapshot(uid);
      debugPrint('[CloudSync][pull] loadUserSnapshot OK — hasCoreData=${snapshot.hasCoreData}');
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }

      final hasCloudCoreData = snapshot.hasCoreData;
      if (hasCloudCoreData) {
        debugPrint('[CloudSync][pull] importando snapshot: listas=${snapshot.lists.length} histórico=${snapshot.history.length} catálogo=${snapshot.catalog.length}');
        final payload = jsonEncode({
          'version': 3,
          'exportedAt': DateTime.now().toIso8601String(),
          'lists': snapshot.lists.map((entry) => entry.toJson()).toList(),
          'purchaseHistory': snapshot.history
              .map((entry) => entry.toJson())
              .toList(),
          'catalog': snapshot.catalog.map((entry) => entry.toJson()).toList(),
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

      debugPrint('[CloudSync][pull] aplicando tema da nuvem (themeMode=${snapshot.settings.themeMode})...');
      final cloudTheme = _parseThemeMode(snapshot.settings.themeMode);
      if (cloudTheme != null && cloudTheme != _themeMode) {
        await _setThemeMode(cloudTheme, syncCloud: false);
      }
      debugPrint('[CloudSync][pull] tema OK');

      debugPrint('[CloudSync][pull] definindo _loadedCloudUid=$uid');
      _loadedCloudUid = uid;
      debugPrint('[CloudSync][pull] chamando _resolveOnboardingForUser...');
      await _resolveOnboardingForUser(uid, profile: snapshot.profile);
      debugPrint('[CloudSync][pull] _resolveOnboardingForUser OK');
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
      debugPrint('[CloudSync][pull] pull concluído com sucesso para uid=$uid');
    } catch (error, stack) {
      _logCloudError('pull', error, stack);
      // LateInitializationError com nome vazio ('') é causado pelo dart2js
      // em modo release (--omit-late-names) quando o SDK JS do Firebase ainda
      // não terminou de inicializar internamente. Tratamos como erro transiente
      // e tentamos novamente silenciosamente, sem exibir mensagem ao usuário.
      final isLateInitError = error.toString().contains('LateInitializationError');
      if (!_onboardingResolved) {
        debugPrint('[CloudSync][pull] resolvendo onboarding no catch (isLateInitError=$isLateInitError)...');
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
        debugPrint('[CloudSync][pull] finally: limpando _isInitialCloudHydration para uid=$uid');
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
        _isApplyingCloudSnapshot) {
      return;
    }
    _scheduleCloudSync();
  }

  void _scheduleCloudSync({bool immediate = false}) {
    if (widget._storage != null ||
        _store.isLoading ||
        _isApplyingCloudSnapshot) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
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
    if (_isPushingCloudSnapshot || _isApplyingCloudSnapshot) {
      debugPrint('[CloudSync][push] ignorado: isPushing=$_isPushingCloudSnapshot isApplying=$_isApplyingCloudSnapshot');
      return;
    }
    if (_loadedCloudUid != uid) {
      debugPrint('[CloudSync][push] ignorado: _loadedCloudUid=$_loadedCloudUid != uid=$uid — aguardando pull');
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

    debugPrint('[CloudSync][push] iniciando saveUserSnapshot para uid=$uid — listas=${_store.lists.length} histórico=${_store.purchaseHistory.length} catálogo=${_store.catalogProducts.length}');
    _isPushingCloudSnapshot = true;
    if (mounted) {
      setState(() {});
    }
    try {
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
        settings: FirestoreUserAppSettings(
          themeMode: _themeMode == ThemeMode.dark ? 'dark' : 'light',
        ),
        profile: profile,
      );
      debugPrint('[CloudSync][push] saveUserSnapshot OK — sincronização concluída!');
      _hasPendingCloudSync = false;
      _loadedCloudUid = uid;
      _lastSuccessfulCloudSyncAt = DateTime.now();
      _stopCloudRetryTimer();
      if (_notifySuccessOnNextSync) {
        _notifySuccessOnNextSync = false;
        _showCloudSyncNotification(
          'Sincronização concluída.',
          type: AppToastType.success,
        );
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error, stack) {
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

  Future<void> _signOut() async {
    _cloudSyncDebounce?.cancel();
    _stopCloudRetryTimer();
    _hasPendingCloudSync = false;
    _resetOnboardingState();
    await FirebaseAuth.instance.signOut();
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
    if (!mounted) {
      return;
    }
    _currentUser = FirebaseAuth.instance.currentUser;
    _hasPendingCloudSync = true;
    _scheduleCloudSync(immediate: true);
    setState(() {});
  }

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF008577),
      brightness: Brightness.light,
      surface: const Color(0xFFF8FCFB),
      surfaceContainerHighest: const Color(0xFFE8F2EF),
      surfaceContainerHigh: const Color(0xFFEDF5F3),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.light,
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.45,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.3),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.15,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5FAF8),
      textTheme: textTheme,
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
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radius2Xl)),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.36),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF5FAF8),
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.34),
          ),
        ),
        backgroundColor: scheme.surface.withValues(alpha: 0.72),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.34)),
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
        fillColor: const Color(0xFFF0F6F4),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00A896),
      brightness: Brightness.dark,
      surface: const Color(0xFF151E22),
      surfaceContainerHighest: const Color(0xFF27343A),
      surfaceContainerHigh: const Color(0xFF212C31),
      primary: const Color(0xFF4ED7C7),
      secondary: const Color(0xFF8ECFC6),
      tertiary: const Color(0xFF6FA5FF),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.dark,
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.15,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.05,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.36),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.36),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.3),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F161A),
      textTheme: textTheme,
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
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radius2Xl)),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.34),
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
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
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
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
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
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        backgroundColor: scheme.surface.withValues(alpha: 0.75),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
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
              final totalSyncRecords =
                  listRecords + historyRecords + catalogRecords;
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
                    onReplayOnboarding: _replayOnboarding,
                    openCreateListOnStart: _openCreateListAfterOnboarding,
                    onCreateListShortcutConsumed:
                        _consumeOnboardingCreateListShortcut,
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
