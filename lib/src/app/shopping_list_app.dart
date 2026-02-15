import 'dart:async';
import 'dart:convert';

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

  late final ShoppingListsStore _store;
  late final ShoppingBackupService _backupService;
  late final Future<void> _launchDelay;
  FirestoreUserDataRepository? _cloudRepository;

  StreamSubscription<User?>? _authSubscription;
  Timer? _cloudSyncDebounce;
  Timer? _cloudSyncRetryTimer;
  String? _loadedCloudUid;
  bool _isApplyingCloudSnapshot = false;
  bool _isPushingCloudSnapshot = false;
  bool _hasPendingCloudSync = false;

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
      _store.addListener(_handleStoreChanged);
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
        user,
      ) {
        if (user == null) {
          _loadedCloudUid = null;
          _hasPendingCloudSync = false;
          _cloudSyncDebounce?.cancel();
          _stopCloudRetryTimer();
          return;
        }
        _hasPendingCloudSync = true;
        _ensureCloudRetryTimer();
        unawaited(_pullFromCloud(user.uid));
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

  Future<void> _pullFromCloud(String uid) async {
    if (_loadedCloudUid == uid) {
      return;
    }
    final repository = _cloudRepository;
    if (repository == null) {
      return;
    }
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
      _scheduleCloudSync(immediate: true);
      _ensureCloudRetryTimer();
      await _pushToCloud(uid);
    } catch (_) {
      _hasPendingCloudSync = true;
      _ensureCloudRetryTimer();
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
    _hasPendingCloudSync = true;
    _ensureCloudRetryTimer();
    _cloudSyncDebounce?.cancel();
    final delay = immediate ? Duration.zero : _cloudSyncDebounceDuration;
    _cloudSyncDebounce = Timer(delay, () {
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
    if (!_hasPendingCloudSync && _loadedCloudUid == uid) {
      return;
    }

    _isPushingCloudSnapshot = true;
    try {
      await repository.saveUserSnapshot(
        uid: uid,
        lists: _store.lists,
        history: _store.purchaseHistory,
        catalog: _store.catalogProducts,
        settings: FirestoreUserAppSettings(
          themeMode: _themeMode == ThemeMode.dark ? 'dark' : 'light',
        ),
      );
      _hasPendingCloudSync = false;
      _loadedCloudUid = uid;
      _stopCloudRetryTimer();
    } catch (_) {
      _hasPendingCloudSync = true;
      _ensureCloudRetryTimer();
    } finally {
      _isPushingCloudSnapshot = false;
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

  ThemeData _buildLightTheme() {
    const seed = Color(0xFF008577);
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.light,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF3F8F7),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      appBarTheme: const AppBarTheme(surfaceTintColor: Colors.transparent),
    );
  }

  ThemeData _buildDarkTheme() {
    const seed = Color(0xFF00A896);
    final base = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: seed,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.dark,
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0D1214),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Color(0xFF172024),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0D1214),
        foregroundColor: base.colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFF1B262B),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = _buildLightTheme();
    final darkTheme = _buildDarkTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
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
                return LoadingScreen(
                  showReadyHint: launchReady && _store.isLoading,
                );
              }

              if (widget._storage == null) {
                return StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, authSnapshot) {
                    if (authSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingScreen(showReadyHint: true);
                    }
                    if (authSnapshot.data == null) {
                      return AuthPage(
                        themeMode: _themeMode,
                        onThemeModeChanged: (mode) {
                          unawaited(_setThemeMode(mode));
                        },
                      );
                    }
                    final user = authSnapshot.data;
                    return DashboardPage(
                      store: _store,
                      backupService: _backupService,
                      themeMode: _themeMode,
                      onThemeModeChanged: _setThemeMode,
                      userDisplayName: user?.displayName,
                      userEmail: user?.email,
                      onSignOut: _signOut,
                    );
                  },
                );
              }

              return DashboardPage(
                store: _store,
                backupService: _backupService,
                themeMode: _themeMode,
                onThemeModeChanged: _setThemeMode,
                userDisplayName: null,
                userEmail: null,
              );
            },
          );
        },
      ),
    );
  }
}
