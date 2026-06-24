import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'account_pages.dart';
import 'catalog_products_page.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
import 'my_lists_page.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor_page.dart';
import 'theme/app_tokens.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

enum _DashboardMenuAction { options, catalog, signOut }

bool _prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

Duration _adaptiveMotionDuration(BuildContext context, Duration fallback) =>
    _prefersReducedMotion(context) ? Duration.zero : fallback;

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

  final name = await showListNameDialog(
    context,
    title: 'Nova lista por reposição inteligente',
    confirmLabel: 'Criar lista',
    initialValue: _buildReplenishmentListName(selectedSuggestions.first.source),
  );
  if (!context.mounted || name == null) {
    return null;
  }

  return store.createListFromDrafts(
    name: name,
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
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;
  final SharedListsRepository? sharedListsRepository;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final String? userDisplayName;
  final String? userEmail;
  final String? userPhotoUrl;
  final VoidCallback? onSignOut;
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

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _handledCreateListShortcut = false;
  List<SharedShoppingListSummary> _lastSharedLists =
      const <SharedShoppingListSummary>[];
  Object? _sharedListsLastError;

  @override
  void initState() {
    super.initState();
    _maybeLaunchCreateListShortcut();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCreateListOnStart && !oldWidget.openCreateListOnStart) {
      _handledCreateListShortcut = false;
      _maybeLaunchCreateListShortcut();
    }
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
        ),
      ),
    );
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
      ),
    );
  }

  Future<void> _openOptions() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => AppOptionsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          userDisplayName: widget.userDisplayName,
          userEmail: widget.userEmail,
          userPhotoUrl: widget.userPhotoUrl,
          onSignOut: widget.onSignOut,
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
        ),
      ),
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

  Future<void> _createNewList({ShoppingListModel? basedOn}) async {
    final suggested = basedOn == null ? '' : '${basedOn.name} - nova';
    final name = await showListNameDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
      initialValue: suggested,
    );

    if (!mounted || name == null) {
      return;
    }

    final created = await widget.store.createList(name: name, basedOn: basedOn);

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
      debugPrint('[share_flow] joinByCode start code=$inviteCode uid=$uid');
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
      debugPrint('[share_flow] joinByCode error=$error');
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

  @override
  Widget build(BuildContext context) {
    final lists = widget.store.listsByCreatedAt;
    final totalCatalogProducts = widget.store.catalogProducts.length;
    final openListsCount = lists.where((list) => !list.isClosed).length;
    final closedListsCount = lists.where((list) => list.isClosed).length;
    final pendingValue = lists.fold<double>(
      0,
      (total, list) => total + list.pendingValue,
    );
    final sharedRepository = widget.sharedListsRepository;
    final authUser = sharedRepository == null
        ? null
        : FirebaseAuth.instance.currentUser;
    final canUseSharing = sharedRepository != null;
    final smartSuggestions = widget.store.suggestReplenishmentItems(limit: 5);
    final quickActions = <_DashboardQuickAction>[
      _DashboardQuickAction(
        key: const ValueKey('dash_action_new'),
        title: 'Nova lista',
        subtitle: 'Comece do zero.',
        icon: Icons.playlist_add_rounded,
        onTap: _createNewList,
      ),
      _DashboardQuickAction(
        key: const ValueKey('dash_action_lists'),
        title: 'Listas',
        subtitle: 'Abra e edite.',
        icon: Icons.inventory_2_rounded,
        onTap: _openMyLists,
      ),
      if (canUseSharing)
        _DashboardQuickAction(
          key: const ValueKey('dash_action_join_code'),
          title: 'Entrar com código',
          subtitle: 'Acesse uma lista.',
          icon: Icons.group_add_rounded,
          onTap: _joinSharedListByCode,
        ),
      _DashboardQuickAction(
        key: const ValueKey('dash_action_history'),
        title: 'Histórico',
        subtitle: 'Veja gastos.',
        icon: Icons.event_note_rounded,
        onTap: _openPurchaseHistory,
      ),
      _DashboardQuickAction(
        key: const ValueKey('dash_action_template'),
        title: 'Catálogo',
        subtitle: 'Produtos salvos.',
        icon: Icons.local_offer_rounded,
        onTap: _openCatalog,
      ),
      _DashboardQuickAction(
        key: const ValueKey('dash_action_based'),
        title: 'Usar modelo',
        subtitle: 'Copie uma lista.',
        icon: Icons.copy_all_rounded,
        onTap: _createBasedOnOld,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Compras'),
        actions: [
          PopupMenuButton<_DashboardMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _DashboardMenuAction.options:
                  _openOptions();
                  return;
                case _DashboardMenuAction.catalog:
                  _openCatalog();
                  return;
                case _DashboardMenuAction.signOut:
                  widget.onSignOut?.call();
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
              if (widget.onSignOut != null)
                const PopupMenuItem(
                  value: _DashboardMenuAction.signOut,
                  child: Text('Sair'),
                ),
            ],
          ),
        ],
      ),
      body: AppGradientScene(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EntryAnimation(
                  key: const ValueKey('dash_summary'),
                  delay: Duration.zero,
                  child: _HomeSummaryCard(
                    totalLists: lists.length,
                    totalCatalogProducts: totalCatalogProducts,
                    openListsCount: openListsCount,
                    closedListsCount: closedListsCount,
                    pendingValue: pendingValue,
                    onCreateList: _createNewList,
                    onOpenLists: _openMyLists,
                    onOpenHistory: _openPurchaseHistory,
                  ),
                ),
                const SizedBox(height: 14),
                if (smartSuggestions.isNotEmpty) ...[
                  _EntryAnimation(
                    key: const ValueKey('dash_smart_replenishment_card'),
                    delay: const Duration(milliseconds: 20),
                    child: _SmartReplenishmentCard(
                      suggestions: smartSuggestions,
                      onTap: _createSmartReplenishmentList,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _EntryAnimation(
                  key: const ValueKey('dash_actions_grid'),
                  delay: const Duration(milliseconds: 40),
                  child: _QuickActionsGrid(actions: quickActions),
                ),
                const SizedBox(height: 20),
                _EntryAnimation(
                  key: const ValueKey('dash_recent_title'),
                  delay: const Duration(milliseconds: 160),
                  child: _SectionHeader(
                    title: 'Listas recentes',
                    subtitle: lists.isEmpty
                        ? 'Crie sua primeira lista para começar.'
                        : 'Abra rapidamente suas ultimas listas salvas.',
                    actionLabel: lists.isEmpty ? null : 'Ver todas',
                    onAction: lists.isEmpty ? null : _openMyLists,
                  ),
                ),
                const SizedBox(height: 12),
                if (lists.isEmpty)
                  _EntryAnimation(
                    key: const ValueKey('dash_recent_empty'),
                    delay: const Duration(milliseconds: 190),
                    child: const _EmptyRecentListsCard(),
                  )
                else
                  ...lists.take(3).toList().asMap().entries.map((entry) {
                    final index = entry.key;
                    final list = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _EntryAnimation(
                        key: ValueKey('dash_recent_${list.id}'),
                        delay: Duration(
                          milliseconds: 190 + min(120, index * 35),
                        ),
                        child: _RecentListCard(
                          list: list,
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              buildAppPageRoute(
                                builder: (_) => ShoppingListEditorPage(
                                  store: widget.store,
                                  listId: list.id,
                                  sharedListsRepository:
                                      widget.sharedListsRepository,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  }),
                if (canUseSharing) ...[
                  const SizedBox(height: 14),
                  _EntryAnimation(
                    key: const ValueKey('dash_shared_title'),
                    delay: const Duration(milliseconds: 210),
                    child: Text(
                      'Listas compartilhadas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.idTokenChanges(),
                    builder: (context, authSnapshot) {
                      final user = authSnapshot.data ?? authUser;
                      final uid = user?.uid.trim() ?? '';
                      if (uid.isEmpty) {
                        return Card(
                          elevation: 0,
                          child: ListTile(
                            leading: const Icon(Icons.lock_outline_rounded),
                            title: const Text(
                              'Entre para ver listas compartilhadas',
                            ),
                            subtitle: const Text(
                              'Faça login para carregar seus convites e listas.',
                            ),
                          ),
                        );
                      }
                      return FutureBuilder<String?>(
                        key: ValueKey('auth_token_$uid'),
                        future: user!.getIdToken(true),
                        builder: (context, tokenSnapshot) {
                          if (tokenSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (tokenSnapshot.hasError) {
                            debugPrint(
                              '[share_flow] token error uid=$uid error=${tokenSnapshot.error}',
                            );
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const Icon(Icons.sync_problem_rounded),
                                title: const Text(
                                  'Não foi possível validar o login',
                                ),
                                subtitle: const Text(
                                  'Tente sair e entrar novamente para atualizar o token.',
                                ),
                                trailing: TextButton(
                                  onPressed: () => setState(() {}),
                                  child: const Text('Atualizar'),
                                ),
                              ),
                            );
                          }
                          return StreamBuilder<List<SharedShoppingListSummary>>(
                            key: ValueKey('shared_lists_$uid'),
                            stream: sharedRepository.watchSharedLists(uid),
                            builder: (context, sharedSnapshot) {
                              if (sharedSnapshot.connectionState ==
                                      ConnectionState.waiting &&
                                  !sharedSnapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 18),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              if (sharedSnapshot.hasError) {
                                _sharedListsLastError = sharedSnapshot.error;
                                debugPrint(
                                  '[share_flow] watchSharedLists error uid=$uid error=${sharedSnapshot.error}',
                                );
                              } else if (sharedSnapshot.hasData) {
                                _sharedListsLastError = null;
                                _lastSharedLists =
                                    sharedSnapshot.data ??
                                    const <SharedShoppingListSummary>[];
                              }
                              final sharedLists =
                                  sharedSnapshot.data ?? _lastSharedLists;
                              if (sharedLists.isEmpty) {
                                if (_sharedListsLastError != null) {
                                  return Card(
                                    elevation: 0,
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.sync_problem_rounded,
                                      ),
                                      title: const Text(
                                        'Não foi possível carregar listas compartilhadas',
                                      ),
                                      subtitle: const Text(
                                        'Verifique permissões ou conexão e tente novamente.',
                                      ),
                                      trailing: TextButton(
                                        onPressed: () => setState(() {}),
                                        child: const Text('Atualizar'),
                                      ),
                                    ),
                                  );
                                }
                                return Card(
                                  elevation: 0,
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.group_off_rounded,
                                    ),
                                    title: const Text(
                                      'Nenhuma lista compartilhada',
                                    ),
                                    subtitle: const Text(
                                      'Use "Entrar na lista com código" ou compartilhe uma lista sua.',
                                    ),
                                    trailing: TextButton(
                                      onPressed: _joinSharedListByCode,
                                      child: const Text('Entrar'),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: sharedLists
                                    .take(5)
                                    .map((shared) {
                                      final isOwner = shared.isOwner(uid);
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Card(
                                          elevation: 0,
                                          child: ListTile(
                                            onTap: () => _openSharedListEditor(
                                              shared.id,
                                            ),
                                            leading: Icon(
                                              isOwner
                                                  ? Icons.verified_user_rounded
                                                  : Icons.group_rounded,
                                            ),
                                            title: Text(shared.name),
                                            subtitle: Text(
                                              '${formatCountLabel(shared.memberCount, 'membro', 'membros')} - ${isOwner ? 'Dono' : 'Membro'}',
                                            ),
                                            trailing: const Icon(
                                              Icons.chevron_right_rounded,
                                            ),
                                          ),
                                        ),
                                      );
                                    })
                                    .toList(growable: false),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewList,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova lista'),
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.totalLists,
    required this.totalCatalogProducts,
    required this.openListsCount,
    required this.closedListsCount,
    required this.pendingValue,
    required this.onCreateList,
    required this.onOpenLists,
    required this.onOpenHistory,
  });

  final int totalLists;
  final int totalCatalogProducts;
  final int openListsCount;
  final int closedListsCount;
  final double pendingValue;
  final VoidCallback onCreateList;
  final VoidCallback onOpenLists;
  final VoidCallback onOpenHistory;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label:
          'Resumo das compras. $openListsCount listas abertas e ${formatCurrency(pendingValue)} pendente.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumo das compras',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalLists == 0
                              ? 'Crie uma lista para acompanhar itens e valores.'
                              : 'Veja o que falta comprar e abra suas listas rápido.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onCreateList,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nova lista'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SummaryPill(
                    icon: Icons.pending_actions_rounded,
                    label: 'Pendente',
                    value: formatCurrency(pendingValue),
                  ),
                  _SummaryPill(
                    icon: Icons.radio_button_checked_rounded,
                    label: 'Abertas',
                    value: '$openListsCount',
                  ),
                  _SummaryPill(
                    icon: Icons.lock_rounded,
                    label: 'Fechadas',
                    value: '$closedListsCount',
                  ),
                  _SummaryPill(
                    icon: Icons.list_alt_rounded,
                    label: 'Listas',
                    value: '$totalLists',
                  ),
                  _SummaryPill(
                    icon: Icons.shopping_basket_rounded,
                    label: 'Produtos',
                    value: '$totalCatalogProducts',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickSummaryActionChip(
                    icon: Icons.inventory_2_rounded,
                    label: 'Ver listas',
                    onTap: onOpenLists,
                  ),
                  _QuickSummaryActionChip(
                    icon: Icons.event_note_rounded,
                    label: 'Histórico',
                    onTap: onOpenHistory,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartReplenishmentCard extends StatelessWidget {
  const _SmartReplenishmentCard({
    required this.suggestions,
    required this.onTap,
  });

  final List<ReplenishmentSuggestion> suggestions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final estimatedTotal = suggestions.fold<double>(
      0,
      (sum, suggestion) => sum + suggestion.estimatedTotal,
    );
    final recurringCount = suggestions
        .where(
          (suggestion) =>
              suggestion.source == ReplenishmentSuggestionSource.recurring,
        )
        .length;

    return Semantics(
      container: true,
      button: true,
      label: 'Criar lista por reposição inteligente',
      value: 'Previsto: ${formatCurrency(estimatedTotal)}',
      hint: 'Toque para revisar os itens sugeridos.',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          onTap: () {
            Feedback.forTap(context);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(11),
                        child: Icon(Icons.auto_awesome_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Próxima compra sugerida',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            recurringCount > 0
                                ? 'Baseada nos itens que você repete.'
                                : 'Comece com produtos do seu catálogo.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .take(3)
                          .map(
                            (suggestion) => _PillLabel(
                              icon:
                                  suggestion.source ==
                                      ReplenishmentSuggestionSource.recurring
                                  ? Icons.repeat_rounded
                                  : Icons.shopping_bag_rounded,
                              text: suggestion.name,
                              maxWidth: constraints.maxWidth,
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Previsto: ${formatCurrency(estimatedTotal)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: onTap,
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('Criar lista'),
                    ),
                  ],
                ),
                if (suggestions.length > 3) ...[
                  const SizedBox(height: 8),
                  Text(
                    '+${suggestions.length - 3} itens sugeridos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $value',
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.52),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: _adaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: Text(
                  value,
                  key: ValueKey('$label|$value'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickSummaryActionChip extends StatelessWidget {
  const _QuickSummaryActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label),
        onPressed: () {
          Feedback.forTap(context);
          onTap();
        },
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        backgroundColor: colorScheme.surface,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 12),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class _DashboardQuickAction {
  const _DashboardQuickAction({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final Key key;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_DashboardQuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 3 : 2;
        const spacing = 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final action in actions)
              SizedBox(
                width: itemWidth,
                child: _QuickActionTile(
                  key: action.key,
                  title: action.title,
                  subtitle: action.subtitle,
                  icon: action.icon,
                  onTap: action.onTap,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Feedback.forTap(context);
            onTap();
          },
          child: SizedBox(
            height: 106,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(9),
                      child: Icon(icon, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentListCard extends StatelessWidget {
  const _RecentListCard({required this.list, required this.onTap});

  final ShoppingListModel list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lineItemsCount = list.items.length;
    final purchasedCount = list.purchasedItemsCount;
    final progress = lineItemsCount == 0
        ? 0.0
        : purchasedCount / lineItemsCount;
    final backgroundColor = list.isClosed
        ? colorScheme.surfaceContainerLow
        : colorScheme.surface;
    final borderColor = list.isClosed
        ? colorScheme.outline.withValues(alpha: 0.5)
        : colorScheme.outlineVariant.withValues(alpha: 0.54);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      elevation: 0,
      child: AnimatedContainer(
        duration: _adaptiveMotionDuration(
          context,
          const Duration(milliseconds: 220),
        ),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusXl),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        list.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PillLabel(
                          icon: list.isClosed
                              ? Icons.lock_rounded
                              : Icons.radio_button_checked_rounded,
                          text: list.isClosed ? 'Fechada' : 'Ativa',
                          backgroundColor: list.isClosed
                              ? colorScheme.surfaceContainerHighest
                              : colorScheme.primaryContainer,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatShortDate(list.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lineItemsCount == 0
                      ? 'Sem itens adicionados ainda.'
                      : list.isClosed
                      ? purchasedCount == 1
                            ? 'Compra finalizada com 1 item comprado.'
                            : 'Compra finalizada com $purchasedCount itens comprados.'
                      : '$purchasedCount de ${formatItemCount(lineItemsCount)} já foram comprados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    color: list.isClosed
                        ? colorScheme.tertiary
                        : colorScheme.primary,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PillLabel(
                      icon: Icons.shopping_basket_rounded,
                      text: '${list.totalItems} itens',
                    ),
                    _PillLabel(
                      icon: Icons.check_circle_outline_rounded,
                      text: '$purchasedCount/$lineItemsCount comprados',
                    ),
                    _PillLabel(
                      icon: Icons.attach_money_rounded,
                      text: formatCurrency(list.totalValue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.icon,
    required this.text,
    this.backgroundColor,
    this.maxWidth,
  });

  final IconData icon;
  final String text;
  final Color? backgroundColor;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? colorScheme.surfaceContainerHighest;
    final fg = colorScheme.onSurface;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700);
    final label = Semantics(
      label: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: maxWidth == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 5),
            if (maxWidth == null)
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textStyle,
              )
            else
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
              ),
          ],
        ),
      ),
    );
    final pill = DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: label,
    );

    if (maxWidth == null) {
      return pill;
    }

    return SizedBox(
      width: maxWidth,
      child: Tooltip(
        message: text,
        waitDuration: const Duration(milliseconds: 450),
        child: pill,
      ),
    );
  }
}

class _EmptyRecentListsCard extends StatelessWidget {
  const _EmptyRecentListsCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.inventory_2_rounded),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nenhuma lista recente ainda. Crie a primeira para começar.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryAnimation extends StatelessWidget {
  const _EntryAnimation({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (_prefersReducedMotion(context)) {
      return child;
    }
    return child
        .animate(delay: delay)
        .fadeIn(duration: AppTokens.motionMedium, curve: Curves.easeOutCubic)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppTokens.motionMedium,
          curve: Curves.easeOutCubic,
        )
        .scaleXY(
          begin: 0.985,
          end: 1,
          duration: AppTokens.motionMedium,
          curve: Curves.easeOutBack,
        );
  }
}
