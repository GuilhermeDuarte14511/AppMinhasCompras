import 'shared_lists/widgets/shared_lists_overview.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/sign_out_coordinator.dart';
import '../application/sign_out_policy.dart';
import '../application/shared_lists_refresh_coordinator.dart';
import '../application/store_and_services.dart';
import '../application/sync_diagnostics.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'account_pages.dart';
import 'catalog_products_page.dart';
import 'dialogs_and_sheets.dart';
import 'dashboard/dashboard_content.dart';
import 'dashboard/dashboard_icons.dart';
import 'my_lists_page.dart';
import 'pantry_page.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor_page.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

enum _DashboardMenuAction { options, catalog, pantry, signOut }

String _capitalizeText(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _buildReplenishmentListName(
  ReplenishmentSuggestionSource source, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  switch (source) {
    case ReplenishmentSuggestionSource.recurring:
      return 'Reposição inteligente';
    case ReplenishmentSuggestionSource.lastMonth:
      final targetMonth = DateTime(reference.year, reference.month - 1);
      final monthLabel = _capitalizeText(
        DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth),
      );
      return 'Reposição $monthLabel';
    case ReplenishmentSuggestionSource.catalogFallback:
      return 'Reposição inteligente';
  }
}

Future<ShoppingListModel?> _runSmartReplenishmentFlow(
  BuildContext context, {
  required ShoppingListsStore store,
}) async {
  final suggestions = store.suggestReplenishmentItems(limit: 24);
  if (suggestions.isEmpty) {
    AppToast.show(
      context,
      message:
          'Ainda não há dados suficientes para sugerir uma reposição inteligente.',
      type: AppToastType.warning,
      duration: const Duration(seconds: 4),
    );
    return null;
  }

  final selectedSuggestions = await showReplenishmentSuggestionsSheet(
    context,
    suggestions: suggestions,
  );
  if (!context.mounted || selectedSuggestions == null) {
    return null;
  }
  if (selectedSuggestions.isEmpty) {
    AppToast.show(
      context,
      message: 'Selecione ao menos um item para criar a lista.',
      type: AppToastType.warning,
      duration: const Duration(seconds: 4),
    );
    return null;
  }

  final setup = await showListSetupDialog(
    context,
    title: 'Nova lista por reposição inteligente',
    confirmLabel: 'Criar lista',
    initialValue: _buildReplenishmentListName(selectedSuggestions.first.source),
  );
  if (!context.mounted || setup == null) {
    return null;
  }

  return store.createListFromDrafts(
    name: setup.name,
    budget: setup.budget,
    paymentBalances: setup.paymentBalances,
    drafts: selectedSuggestions
        .map((suggestion) => suggestion.toDraft())
        .toList(growable: false),
  );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.store,
    required this.backupService,
    this.sharedListsRepository,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.userDisplayName,
    this.userEmail,
    this.userPhotoUrl,
    this.onSignOut,
    this.onProfileUpdated,
    this.onReplayOnboarding,
    this.openCreateListOnStart = false,
    this.onCreateListShortcutConsumed,
    this.showCloudSyncStatus = false,
    this.hasInternetConnection = true,
    this.hasPendingCloudSync = false,
    this.isCloudSyncing = false,
    this.lastCloudSyncAt,
    this.totalSyncRecords = 0,
    this.pendingSyncRecords = 0,
    this.listRecords = 0,
    this.historyRecords = 0,
    this.catalogRecords = 0,
    this.pantryRecords = 0,
    this.syncDiagnostics,
    this.onSyncNow,
    this.onRefreshSyncDiagnostics,
    this.voiceRecognitionService,
    this.homeWidgetLaunchUri,
    this.homeWidgetActionId = 0,
    this.onHomeWidgetActionConsumed,
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;
  final SharedListsRepository? sharedListsRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? userDisplayName;
  final String? userEmail;
  final String? userPhotoUrl;
  final Future<void> Function({required bool discardPendingChanges})? onSignOut;
  final Future<void> Function()? onProfileUpdated;
  final VoidCallback? onReplayOnboarding;
  final bool openCreateListOnStart;
  final VoidCallback? onCreateListShortcutConsumed;
  final bool showCloudSyncStatus;
  final bool hasInternetConnection;
  final bool hasPendingCloudSync;
  final bool isCloudSyncing;
  final DateTime? lastCloudSyncAt;
  final int totalSyncRecords;
  final int pendingSyncRecords;
  final int listRecords;
  final int historyRecords;
  final int catalogRecords;
  final int pantryRecords;
  final SyncDiagnosticsSnapshot? syncDiagnostics;
  final Future<void> Function()? onSyncNow;
  final Future<SyncDiagnosticsSnapshot?> Function()? onRefreshSyncDiagnostics;
  final ShoppingVoiceRecognitionService? voiceRecognitionService;
  final Uri? homeWidgetLaunchUri;
  final int homeWidgetActionId;
  final VoidCallback? onHomeWidgetActionConsumed;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _handledCreateListShortcut = false;
  bool _isSigningOut = false;
  List<SharedShoppingListSummary> _lastSharedLists =
      const <SharedShoppingListSummary>[];
  String? _lastSharedListsUid;
  Object? _sharedListsLastError;
  int _handledHomeWidgetActionId = -1;
  final SharedListsRefreshCoordinator _sharedListsRefreshCoordinator =
      SharedListsRefreshCoordinator();
  final SharedListsStreamCache<List<SharedShoppingListSummary>>
  _sharedListsStreamCache =
      SharedListsStreamCache<List<SharedShoppingListSummary>>();

  @override
  void initState() {
    super.initState();
    _maybeLaunchCreateListShortcut();
    _maybeHandleHomeWidgetAction();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.sharedListsRepository,
      widget.sharedListsRepository,
    )) {
      _clearSharedListsStream();
    }
    if (widget.openCreateListOnStart && !oldWidget.openCreateListOnStart) {
      _handledCreateListShortcut = false;
      _maybeLaunchCreateListShortcut();
    }
    _maybeHandleHomeWidgetAction();
  }

  void _clearSharedListsStream() {
    _sharedListsStreamCache.clear();
  }

  Stream<List<SharedShoppingListSummary>> _watchSharedLists({
    required SharedListsRepository repository,
    required String uid,
  }) {
    return _sharedListsStreamCache.resolve(
      sourceIdentity: repository,
      userId: uid,
      revision: _sharedListsRefreshCoordinator.revision,
      create: () => repository.watchSharedLists(uid),
    );
  }

  bool _isAuthenticationError(Object? error) {
    return error is FirebaseException &&
        (error.code == 'unauthenticated' || error.code == 'permission-denied');
  }

  Future<void> _retrySharedLists(User user, Object? error) async {
    if (_sharedListsRefreshCoordinator.isRefreshing) {
      return;
    }
    final operation = _sharedListsRefreshCoordinator.retry(
      refreshAuthentication: _isAuthenticationError(error),
      refreshToken: () async {
        final currentUser = FirebaseAuth.instance.currentUser ?? user;
        final token = await currentUser.getIdToken(true);
        if (token == null || token.trim().isEmpty) {
          throw FirebaseAuthException(
            code: 'missing-id-token',
            message: 'O Firebase não retornou um token de autenticação.',
          );
        }
      },
    );
    if (mounted) {
      setState(() {});
    }
    try {
      await operation;
      _sharedListsLastError = null;
      _clearSharedListsStream();
      if (mounted) {
        setState(() {});
      }
    } catch (refreshError) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível atualizar as listas compartilhadas. Verifique a conexão e tente novamente.',
        type: AppToastType.error,
      );
      setState(() {});
    }
  }

  void _maybeHandleHomeWidgetAction() {
    final uri = widget.homeWidgetLaunchUri;
    final actionId = widget.homeWidgetActionId;
    if (uri == null || actionId == _handledHomeWidgetActionId) {
      return;
    }
    _handledHomeWidgetActionId = actionId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onHomeWidgetActionConsumed?.call();
      unawaited(_handleHomeWidgetUri(uri));
    });
  }

  Future<void> _handleHomeWidgetUri(Uri uri) async {
    final action = uri.queryParameters['action']?.trim() ?? '';
    if (action == 'pantry') {
      await _openPantry();
      return;
    }
    if (action != 'voice' && action != 'open_list') {
      return;
    }
    final requestedListId = uri.queryParameters['listId']?.trim() ?? '';
    final requestedList = requestedListId.isEmpty
        ? null
        : widget.store.findById(requestedListId);
    final target = requestedList?.isClosed == false
        ? requestedList
        : _preferredOpenList();

    if (target == null) {
      if (action == 'voice') {
        await _createNewList(startVoiceCapture: true);
      }
      return;
    }
    await _openListEditor(target, startVoiceCapture: action == 'voice');
  }

  ShoppingListModel? _preferredOpenList() {
    final openLists = widget.store.lists
        .where((list) => !list.isClosed)
        .toList(growable: false);
    if (openLists.isEmpty) {
      return null;
    }
    openLists.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return openLists.first;
  }

  Future<void> _openListEditor(
    ShoppingListModel list, {
    bool startVoiceCapture = false,
    bool startMarketMode = false,
  }) {
    return Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: list.id,
          sharedListsRepository: widget.sharedListsRepository,
          voiceRecognitionService: widget.voiceRecognitionService,
          startVoiceCapture: startVoiceCapture,
          startMarketMode: startMarketMode,
        ),
      ),
    );
  }

  Future<void> _openVoiceQuickAdd() async {
    final target = _preferredOpenList();
    if (target == null) {
      await _createNewList(startVoiceCapture: true);
      return;
    }
    await _openListEditor(target, startVoiceCapture: true);
  }

  void _maybeLaunchCreateListShortcut() {
    if (!widget.openCreateListOnStart || _handledCreateListShortcut) {
      return;
    }
    _handledCreateListShortcut = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      widget.onCreateListShortcutConsumed?.call();
      await _createNewList();
    });
  }

  Future<void> _openMyLists() async {
    final sharedRepository = widget.sharedListsRepository;
    final currentUserUid = sharedRepository == null
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => MyListsPage(
          store: widget.store,
          backupService: widget.backupService,
          sharedListsRepository: sharedRepository,
          currentUserUid: currentUserUid,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => PurchaseHistoryPage(
          store: widget.store,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  Future<void> _openOptions() async {
    final syncDiagnostics = await _buildSyncDiagnosticsSnapshot();
    if (!mounted) {
      return;
    }
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => AppOptionsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          autoImportOwnedSharedCatalogs:
              widget.store.autoImportOwnedSharedCatalogs,
          onAutoImportOwnedSharedCatalogsChanged: (enabled) {
            unawaited(widget.store.setAutoImportOwnedSharedCatalogs(enabled));
          },
          userDisplayName: widget.userDisplayName,
          userEmail: widget.userEmail,
          userPhotoUrl: widget.userPhotoUrl,
          onSignOut: _requestSignOut,
          onProfileUpdated: widget.onProfileUpdated,
          onReplayOnboarding: widget.onReplayOnboarding,
          showCloudSyncStatus: widget.showCloudSyncStatus,
          hasInternetConnection: widget.hasInternetConnection,
          hasPendingCloudSync: widget.hasPendingCloudSync,
          isCloudSyncing: widget.isCloudSyncing,
          lastCloudSyncAt: widget.lastCloudSyncAt,
          totalSyncRecords: widget.totalSyncRecords,
          pendingSyncRecords: widget.pendingSyncRecords,
          listRecords: widget.listRecords,
          historyRecords: widget.historyRecords,
          catalogRecords: widget.catalogRecords,
          pantryRecords: widget.pantryRecords,
          syncDiagnostics: syncDiagnostics,
          onSyncNow: widget.onSyncNow,
          onRefreshSyncDiagnostics: _buildSyncDiagnosticsSnapshot,
        ),
      ),
    );
  }

  Future<SyncDiagnosticsSnapshot?> _buildSyncDiagnosticsSnapshot() async {
    final refreshBase = widget.onRefreshSyncDiagnostics;
    final snapshot = refreshBase == null
        ? widget.syncDiagnostics
        : await refreshBase();
    if (snapshot == null) {
      return null;
    }
    final sharedRepository = widget.sharedListsRepository;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final entries = <SharedListDiagnosticEntry>[];
    for (final shared in _lastSharedLists) {
      var itemCount = 0;
      String? lastError;
      if (sharedRepository != null) {
        try {
          itemCount = (await sharedRepository.fetchListItems(shared.id)).length;
        } catch (error) {
          lastError = error.toString();
        }
      }
      final sourceId = shared.sourceLocalListId?.trim() ?? '';
      entries.add(
        SharedListDiagnosticEntry(
          id: shared.id,
          name: shared.name,
          ownerUid: shared.ownerUid,
          isOwner: uid.isNotEmpty && shared.isOwner(uid),
          memberCount: shared.memberCount,
          itemCount: itemCount,
          isCatalogImportEnabled:
              (shared.isOwner(uid) &&
                  widget.store.autoImportOwnedSharedCatalogs) ||
              widget.store.isSharedCatalogImportEnabled(shared.id),
          isMirroredLocally:
              sourceId.isNotEmpty && widget.store.findById(sourceId) != null,
          updatedAt: shared.updatedAt,
          lastError: lastError,
        ),
      );
    }
    return snapshot.copyWith(
      generatedAt: DateTime.now(),
      sharedListCount: entries.length,
      sharedLists: List.unmodifiable(entries),
      lastError: _sharedListsLastError?.toString(),
    );
  }

  Future<void> _openCatalog() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => CatalogProductsPage(store: widget.store),
      ),
    );
  }

  Future<void> _openPantry() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(builder: (_) => PantryPage(store: widget.store)),
    );
  }

  Future<void> _createNewList({
    ShoppingListModel? basedOn,
    bool startVoiceCapture = false,
  }) async {
    final suggested = basedOn == null ? '' : '${basedOn.name} - nova';
    final setup = await showListSetupDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
      initialValue: suggested,
      initialBudget: basedOn?.budget,
      initialPaymentBalances: basedOn?.paymentBalances ?? const [],
    );

    if (!mounted || setup == null) {
      return;
    }

    final created = await widget.store.createList(
      name: setup.name,
      basedOn: basedOn,
      budget: setup.budget,
      clearBudget: setup.budget == null,
      paymentBalances: setup.paymentBalances,
    );

    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    _showSnack('Lista criada.', type: AppToastType.success);

    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: created.id,
          sharedListsRepository: widget.sharedListsRepository,
          voiceRecognitionService: widget.voiceRecognitionService,
          startVoiceCapture: startVoiceCapture,
        ),
      ),
    );
  }

  Future<void> _createSmartReplenishmentList() async {
    final created = await _runSmartReplenishmentFlow(
      context,
      store: widget.store,
    );
    if (!mounted || created == null) {
      return;
    }
    HapticFeedback.mediumImpact();
    _showSnack('Lista criada por reposição.', type: AppToastType.success);

    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: created.id,
          sharedListsRepository: widget.sharedListsRepository,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  Future<void> _createBasedOnOld() async {
    final lists = widget.store.listsByCreatedAt;
    if (lists.isEmpty) {
      _showSnack('Você ainda Não tem listas para usar como base.');
      return;
    }

    final source = await showTemplatePickerSheet(context, lists: lists);

    if (!mounted || source == null) {
      return;
    }

    await _createNewList(basedOn: source);
  }

  Future<void> _openSharedListEditor(String listId) async {
    final repository = widget.sharedListsRepository;
    if (repository == null) {
      _showSnack('Compartilhamento indisponível neste modo.');
      return;
    }
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => SharedListEditorPage(
          repository: repository,
          store: widget.store,
          listId: listId,
        ),
      ),
    );
  }

  Future<void> _joinSharedListByCode() async {
    final repository = widget.sharedListsRepository;
    final uid = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    if (repository == null) {
      _showSnack('Compartilhamento indisponível neste modo.');
      return;
    }
    if (uid.isEmpty) {
      _showSnack('Faça login para entrar em lista compartilhada.');
      return;
    }
    final controller = TextEditingController();
    final rawCode = await showAppDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entrar na lista com código'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Código',
            hintText: 'Ex.: A1B2C3D4',
            prefixIcon: Icon(Icons.qr_code_rounded),
          ),
          onSubmitted: (value) => Navigator.pop(context, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    final inviteCode = (rawCode ?? '').trim();
    if (!mounted || inviteCode.isEmpty) {
      return;
    }
    try {
      final listId = await repository.joinByCode(
        inviteCode: inviteCode,
        uid: uid,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack(
        'Entrada confirmada. Abrindo lista compartilhada.',
        type: AppToastType.success,
      );
      await _openSharedListEditor(listId);
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (error is FirebaseException) {
        final code = error.code.trim().toLowerCase();
        if (code == 'permission-denied') {
          _showSnack(
            'Permissão negada. Verifique se o código ainda está ativo.',
          );
          return;
        }
        _showSnack(
          'Não foi possível entrar. Verifique se o código ainda está ativo.',
        );
        return;
      }
      if (error is StateError) {
        _showSnack(error.message);
        return;
      }
      _showSnack('Não foi possível entrar com o código.');
    }
  }

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
  }

  Future<SignOutDecision> _confirmPendingSignOut(SignOutAction action) async {
    final isOnline = action == SignOutAction.syncThenSignOut;
    final result = await showAppDialog<SignOutDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isOnline ? 'Sincronizar antes de sair?' : 'Sair sem sincronizar?',
        ),
        content: Text(
          isOnline
              ? 'Há alterações que ainda não foram salvas na nuvem. '
                    'Sincronize para não perdê-las neste aparelho.'
              : 'Você está sem internet e há alterações apenas neste aparelho. '
                    'Ao sair agora, essas alterações serão descartadas.',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, SignOutDecision.cancel),
            child: Text(isOnline ? 'Cancelar' : 'Continuar no app'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, SignOutDecision.discardAndSignOut),
            child: Text(
              isOnline ? 'Sair sem sincronizar' : 'Sair e descartar alterações',
            ),
          ),
          if (isOnline && widget.onSyncNow != null)
            FilledButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, SignOutDecision.syncAndSignOut),
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text('Sincronizar e sair'),
            ),
        ],
      ),
    );
    return result ?? SignOutDecision.cancel;
  }

  Future<void> _requestSignOut() async {
    final signOut = widget.onSignOut;
    if (signOut == null || _isSigningOut) {
      return;
    }

    _isSigningOut = true;
    final navigator = Navigator.of(context);
    try {
      final action = resolveSignOutAction(
        hasPendingChanges: widget.hasPendingCloudSync,
        isSyncing: widget.isCloudSyncing,
        hasNetworkConnection: widget.hasInternetConnection,
      );

      try {
        final signedOut = await const SignOutCoordinator().execute(
          action: action,
          requestDecision: _confirmPendingSignOut,
          synchronize: widget.onSyncNow,
          signOut: signOut,
        );
        if (!signedOut || !mounted) {
          return;
        }
      } on SignOutFailure catch (failure) {
        if (mounted) {
          _showSnack(
            failure.step == SignOutFailureStep.synchronize
                ? 'Não foi possível sincronizar. Você continua conectado.'
                : 'Não foi possível sair agora. Tente novamente.',
            type: AppToastType.error,
          );
        }
        return;
      }
      navigator.popUntil((route) => route.isFirst);
    } finally {
      _isSigningOut = false;
    }
  }

  Widget _buildSharedListsPanel(SharedListsRepository repository, User? user) {
    final uid = user?.uid.trim() ?? '';
    if (uid.isEmpty) {
      _lastSharedLists = const <SharedShoppingListSummary>[];
      _lastSharedListsUid = null;
      return SharedListsOverview(
        lists: const [],
        currentUid: '',
        onJoin: _joinSharedListByCode,
        onOpen: _openSharedListEditor,
      );
    }
    if (_lastSharedListsUid != uid) {
      _lastSharedLists = const <SharedShoppingListSummary>[];
      _sharedListsLastError = null;
      _lastSharedListsUid = uid;
    }

    return StreamBuilder<List<SharedShoppingListSummary>>(
      key: ValueKey(
        'shared_lists_${uid}_${_sharedListsRefreshCoordinator.revision}',
      ),
      stream: _watchSharedLists(repository: repository, uid: uid),
      initialData: _lastSharedListsUid == uid && _lastSharedLists.isNotEmpty
          ? _lastSharedLists
          : null,
      builder: (context, sharedSnapshot) {
        if (sharedSnapshot.connectionState == ConnectionState.waiting &&
            !sharedSnapshot.hasData) {
          return SharedListsOverview(
            lists: const [],
            currentUid: uid,
            onJoin: _joinSharedListByCode,
            onOpen: _openSharedListEditor,
            loading: true,
          );
        }
        if (sharedSnapshot.hasError) {
          _sharedListsLastError = sharedSnapshot.error;
          debugPrint(
            '[share_flow] falha ao observar listas compartilhadas: '
            '${sharedSnapshot.error.runtimeType}',
          );
        } else if (sharedSnapshot.hasData) {
          _sharedListsLastError = null;
          _lastSharedLists =
              sharedSnapshot.data ?? const <SharedShoppingListSummary>[];
        }

        final sharedLists = (sharedSnapshot.data ?? _lastSharedLists).where(
          (list) =>
              !list.isOwner(uid) ||
              !widget.store.isListPermanentlyDeleted(
                list.sourceLocalListId ?? '',
              ),
        );
        return SharedListsOverview(
          lists: sharedLists.take(5).toList(growable: false),
          currentUid: uid,
          onJoin: _joinSharedListByCode,
          onOpen: _openSharedListEditor,
          hasError: _sharedListsLastError != null,
          refreshing: _sharedListsRefreshCoordinator.isRefreshing,
          onRetry: () =>
              unawaited(_retrySharedLists(user!, _sharedListsLastError)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = widget.store.listsByCreatedAt;
    final sharedRepository = widget.sharedListsRepository;
    final authUser = sharedRepository == null
        ? null
        : FirebaseAuth.instance.currentUser;
    final canUseSharing = sharedRepository != null;
    final quickActions = <DashboardShortcut>[
      DashboardShortcut(
        key: const ValueKey('dash_action_new'),
        title: 'Nova lista',
        subtitle: 'Comece do zero.',
        icon: DashboardIcons.add,
        onTap: _createNewList,
      ),
      if (widget.voiceRecognitionService != null)
        DashboardShortcut(
          key: const ValueKey('dash_action_voice'),
          title: 'Adicionar por voz',
          subtitle: 'Fale vários itens.',
          icon: DashboardIcons.voice,
          onTap: _openVoiceQuickAdd,
        ),
      DashboardShortcut(
        key: const ValueKey('dash_action_lists'),
        title: 'Minhas listas',
        subtitle: '${lists.where((list) => !list.isClosed).length} ativas',
        icon: DashboardIcons.lists,
        onTap: _openMyLists,
      ),
      if (canUseSharing)
        DashboardShortcut(
          key: const ValueKey('dash_action_join_code'),
          title: 'Entrar com código',
          subtitle: 'Acesse uma lista.',
          icon: DashboardIcons.join,
          onTap: _joinSharedListByCode,
        ),
      DashboardShortcut(
        key: const ValueKey('dash_action_history'),
        title: 'Histórico mensal',
        subtitle: 'Compras finalizadas',
        icon: DashboardIcons.history,
        onTap: _openPurchaseHistory,
      ),
      DashboardShortcut(
        key: const ValueKey('dash_action_template'),
        title: 'Catálogo',
        subtitle: '${widget.store.catalogProducts.length} produtos cadastrados',
        icon: DashboardIcons.catalog,
        onTap: _openCatalog,
      ),
      DashboardShortcut(
        key: const ValueKey('dash_action_pantry'),
        title: 'Despensa',
        subtitle: 'Veja o que repor.',
        icon: DashboardIcons.pantry,
        onTap: _openPantry,
      ),
      DashboardShortcut(
        key: const ValueKey('dash_action_based'),
        title: 'Usar modelo',
        subtitle: 'Copie uma lista.',
        icon: DashboardIcons.copy,
        onTap: _createBasedOnOld,
      ),
    ];
    final theme = dashboardTheme(Theme.of(context));
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text(
              'Minhas Compras',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            titleSpacing: 4,
            leading: IconButton(
              tooltip: 'Minhas listas',
              onPressed: _openMyLists,
              icon: const Icon(DashboardIcons.book),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            actions: [
              if (widget.showCloudSyncStatus)
                IconButton(
                  tooltip: widget.isCloudSyncing
                      ? 'Sincronizando'
                      : !widget.hasInternetConnection
                      ? 'Sem internet'
                      : widget.hasPendingCloudSync
                      ? 'Alterações pendentes'
                      : 'Sincronizado',
                  onPressed: _openOptions,
                  icon: Icon(
                    widget.isCloudSyncing
                        ? DashboardIcons.sync
                        : !widget.hasInternetConnection
                        ? DashboardIcons.offline
                        : widget.hasPendingCloudSync
                        ? DashboardIcons.upload
                        : DashboardIcons.synced,
                  ),
                ),
              PopupMenuButton<_DashboardMenuAction>(
                tooltip: 'Perfil e ajustes',
                icon: const Icon(DashboardIcons.profile),
                onSelected: (action) {
                  switch (action) {
                    case _DashboardMenuAction.options:
                      _openOptions();
                      return;
                    case _DashboardMenuAction.catalog:
                      _openCatalog();
                      return;
                    case _DashboardMenuAction.pantry:
                      _openPantry();
                      return;
                    case _DashboardMenuAction.signOut:
                      unawaited(_requestSignOut());
                      return;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _DashboardMenuAction.options,
                    child: Text('Opções'),
                  ),
                  const PopupMenuItem(
                    value: _DashboardMenuAction.catalog,
                    child: Text('Catálogo de produtos'),
                  ),
                  const PopupMenuItem(
                    value: _DashboardMenuAction.pantry,
                    child: Text('Despensa'),
                  ),
                  if (widget.onSignOut != null)
                    const PopupMenuItem(
                      value: _DashboardMenuAction.signOut,
                      child: Text('Sair'),
                    ),
                ],
              ),
            ],
          ),

          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: DashboardContent(
                  lists: lists,
                  catalogCount: widget.store.catalogProducts.length,
                  pantry: widget.store.pantryItems,
                  suggestions: widget.store.suggestReplenishmentItems(limit: 5),
                  shortcuts: quickActions,
                  onCreate: _createNewList,
                  onLists: _openMyLists,
                  onReplenish: _createSmartReplenishmentList,
                  onPantry: _openPantry,
                  activeList: _preferredOpenList(),
                  onOpenList: (list) => _openListEditor(list),
                  onContinue: (list) => _openListEditor(
                    list,
                    startMarketMode: list.items.isNotEmpty,
                  ),
                  sharedSection: !canUseSharing
                      ? null
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Listas compartilhadas',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed:
                                      authUser == null ||
                                          _sharedListsRefreshCoordinator
                                              .isRefreshing
                                      ? null
                                      : () => unawaited(
                                          _retrySharedLists(authUser, null),
                                        ),
                                  icon:
                                      _sharedListsRefreshCoordinator
                                          .isRefreshing
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.refresh, size: 18),
                                  label: Text(
                                    _sharedListsRefreshCoordinator.isRefreshing
                                        ? 'Atualizando'
                                        : 'Atualizar',
                                  ),
                                ),
                              ],
                            ),
                            _buildSharedListsPanel(sharedRepository, authUser),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
