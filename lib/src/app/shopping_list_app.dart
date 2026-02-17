import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../data/local/storages.dart';
import '../data/remote/cosmos_product_lookup_service.dart';
import '../data/remote/firebase_user_data_repository.dart';
import '../data/remote/open_food_facts_product_lookup_service.dart';
import '../data/repositories/product_catalog_repository.dart';
import '../data/services/backup_service.dart';
import '../data/services/home_widget_service.dart';
import '../data/services/reminder_service.dart';
import '../presentation/auth_page.dart';
import '../presentation/launch.dart';
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
  }) : _storage = storage,
       _backupService = backupService,
       _reminderService = reminderService,
       _catalogStorage = catalogStorage,
       _historyStorage = historyStorage,
       _lookupService = lookupService,
       _homeWidgetService = homeWidgetService;

  final ShoppingListsStorage? _storage;
  final ShoppingBackupService? _backupService;
  final ShoppingReminderService? _reminderService;
  final ProductCatalogStorage? _catalogStorage;
  final PurchaseHistoryStorage? _historyStorage;
  final ProductLookupService? _lookupService;
  final ShoppingHomeWidgetService? _homeWidgetService;

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
  FirestoreUserDataRepository? _cloudRepository;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _cloudSyncDebounce;
  Timer? _cloudSyncRetryTimer;
  User? _currentUser;
  bool _authStateResolved = false;
  bool _isInitialCloudHydration = false;
  String? _hydratingCloudUid;
  String? _loadedCloudUid;
  bool _isApplyingCloudSnapshot = false;
  bool _isPushingCloudSnapshot = false;
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
      _cloudRepository = FirestoreUserDataRepository();
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
    final repository = _cloudRepository;
    if (repository == null) {
      return;
    }
    final shouldEndInitialHydration =
        asInitialHydration && _hydratingCloudUid == uid;
    try {
      await _waitForStoreLoaded();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final snapshot = await repository.loadUserSnapshot(uid);
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }

      final hasCloudCoreData = snapshot.hasCoreData;
      if (hasCloudCoreData) {
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
          await _store.importBackupJson(payload, replaceExisting: true);
        } finally {
          _isApplyingCloudSnapshot = false;
        }
      }

      final cloudTheme = _parseThemeMode(snapshot.settings.themeMode);
      if (cloudTheme != null && cloudTheme != _themeMode) {
        await _setThemeMode(cloudTheme, syncCloud: false);
      }

      _loadedCloudUid = uid;
      _hasPendingCloudSync = true;
      if (mounted) {
        setState(() {});
      }
      _scheduleCloudSync(immediate: true);
      _ensureCloudRetryTimer();
      await _pushToCloud(uid);
    } catch (error, stack) {
      _logCloudError('pull', error, stack);
      _hasPendingCloudSync = true;
      _notifySuccessOnNextSync = true;
      _ensureCloudRetryTimer();
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
      if (mounted) {
        setState(() {});
      }
    } finally {
      if (shouldEndInitialHydration && mounted) {
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
    if (repository == null ||
        _isPushingCloudSnapshot ||
        _isApplyingCloudSnapshot) {
      return;
    }
    if (_loadedCloudUid != uid) {
      _ensureCloudRetryTimer();
      return;
    }
    if (!_hasNetworkConnection) {
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
      return;
    }

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
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5FAF8),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.3),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.3),
      ),
      cardTheme: const CardThemeData(
        elevation: AppTokens.cardElevation,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusXl)),
        ),
      ),
      appBarTheme: const AppBarTheme(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFFF0F6F4),
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
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F161A),
      textTheme: base.textTheme.copyWith(
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.32),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.32),
      ),
      cardTheme: const CardThemeData(
        elevation: AppTokens.cardElevation,
        margin: EdgeInsets.zero,
        color: Color(0xFF1A252A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusXl)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F161A),
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFF1E2A2F),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
          ),
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
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
                return _buildHomeTransitionShell(
                  stateKey: 'dashboard-auth',
                  child: DashboardPage(
                    store: _store,
                    backupService: _backupService,
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
                  ),
                );
              }

              return _buildHomeTransitionShell(
                stateKey: 'dashboard-local',
                child: DashboardPage(
                  store: _store,
                  backupService: _backupService,
                  themeMode: _themeMode,
                  onThemeModeChanged: _setThemeMode,
                  userDisplayName: null,
                  userEmail: null,
                  userPhotoUrl: null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
