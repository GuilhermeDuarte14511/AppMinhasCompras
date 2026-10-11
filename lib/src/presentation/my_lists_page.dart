import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'my_lists/my_lists_layout.dart';
import 'my_lists/list_ledger_row.dart';
import 'theme/mercado_editorial_theme.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor_page.dart';
import 'trash_lists_page.dart';
import 'utils/app_modal.dart';
import 'utils/app_page_route.dart';
import 'utils/app_toast.dart';

String _myListsCapitalizeText(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

String _myListsBuildReplenishmentListName(
  ReplenishmentSuggestionSource source, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  switch (source) {
    case ReplenishmentSuggestionSource.recurring:
      return 'Lista recorrente';
    case ReplenishmentSuggestionSource.lastMonth:
      final targetMonth = DateTime(reference.year, reference.month - 1);
      final monthLabel = _myListsCapitalizeText(
        DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth),
      );
      return 'Reposição $monthLabel';
    case ReplenishmentSuggestionSource.catalogFallback:
      return 'Reposição inteligente';
  }
}

Future<ShoppingListModel?> _runMyListsSmartReplenishmentFlow(
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
    initialValue: _myListsBuildReplenishmentListName(
      selectedSuggestions.first.source,
    ),
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

List<ShoppingListModel> _filterMyLists(
  List<ShoppingListModel> lists, {
  required String searchQuery,
  required MyListsFilter activeFilter,
  required Map<String, SharedShoppingListSummary> sharedBySource,
}) {
  final normalizedQuery = normalizeQuery(searchQuery);
  return lists
      .where((list) {
        final matchesFilter = switch (activeFilter) {
          MyListsFilter.all => true,
          MyListsFilter.active => !list.isClosed,
          MyListsFilter.closed => list.isClosed,
          MyListsFilter.shared => sharedBySource.containsKey(list.id),
        };
        if (!matchesFilter) {
          return false;
        }
        if (normalizedQuery.isEmpty) {
          return true;
        }
        return normalizeQuery(list.name).contains(normalizedQuery);
      })
      .toList(growable: false);
}

class MyListsPage extends StatefulWidget {
  const MyListsPage({
    super.key,
    required this.store,
    required this.backupService,
    this.sharedListsRepository,
    this.currentUserUid,
    this.voiceRecognitionService,
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;
  final SharedListsRepository? sharedListsRepository;
  final String? currentUserUid;
  final ShoppingVoiceRecognitionService? voiceRecognitionService;

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  bool _selectionMode = false;
  final Set<String> _selectedListIds = <String>{};
  late final TextEditingController _searchController;
  MyListsFilter _activeFilter = MyListsFilter.all;

  String get _searchQuery => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _setActiveFilter(MyListsFilter filter) {
    if (_activeFilter == filter) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _activeFilter = filter;
    });
  }

  void _clearMyListsFilters() {
    if (_searchController.text.isEmpty && _activeFilter == MyListsFilter.all) {
      return;
    }
    _searchController.clear();
    setState(() {
      _activeFilter = MyListsFilter.all;
    });
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

  Future<void> _openTrash() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(builder: (_) => TrashListsPage(store: widget.store)),
    );
  }

  Future<void> _openList(ShoppingListModel list) async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => ShoppingListEditorPage(
          store: widget.store,
          listId: list.id,
          sharedListsRepository: widget.sharedListsRepository,
          voiceRecognitionService: widget.voiceRecognitionService,
        ),
      ),
    );
  }

  Future<void> _openSharedList(SharedShoppingListSummary shared) async {
    final repository = widget.sharedListsRepository;
    if (repository == null) {
      _showSnack('Compartilhamento indisponível neste modo.');
      return;
    }
    HapticFeedback.selectionClick();
    _showSnack('Abrindo lista compartilhada.', type: AppToastType.success);
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => SharedListEditorPage(
          repository: repository,
          store: widget.store,
          listId: shared.id,
        ),
      ),
    );
  }

  Future<void> _createFromSource(ShoppingListModel source) async {
    final setup = await showListSetupDialog(
      context,
      title: 'Criar lista baseada em "${source.name}"',
      confirmLabel: 'Criar lista',
      initialValue: '${source.name} - nova',
      initialBudget: source.budget,
      initialPaymentBalances: source.paymentBalances,
    );

    if (!mounted || setup == null) {
      return;
    }

    final created = await widget.store.createList(
      name: setup.name,
      basedOn: source,
      budget: setup.budget,
      clearBudget: setup.budget == null,
      paymentBalances: setup.paymentBalances,
    );

    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    _showSnack('Lista criada.', type: AppToastType.success);

    await _openList(created);
  }

  Future<void> _createFromPicker() async {
    final lists = widget.store.listsByCreatedAt;
    if (lists.isEmpty) {
      _showSnack('Não há listas antigas para copiar.');
      return;
    }

    final source = await showTemplatePickerSheet(context, lists: lists);

    if (!mounted || source == null) {
      return;
    }

    await _createFromSource(source);
  }

  Future<void> _createNewList() async {
    final setup = await showListSetupDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
    );

    if (!mounted || setup == null) {
      return;
    }

    final created = await widget.store.createList(
      name: setup.name,
      budget: setup.budget,
      paymentBalances: setup.paymentBalances,
    );
    if (!mounted) {
      return;
    }
    HapticFeedback.mediumImpact();
    _showSnack('Lista criada.', type: AppToastType.success);

    await _openList(created);
  }

  Future<void> _createSmartReplenishmentList() async {
    final created = await _runMyListsSmartReplenishmentFlow(
      context,
      store: widget.store,
    );
    if (!mounted || created == null) {
      return;
    }
    HapticFeedback.mediumImpact();
    _showSnack('Lista criada por reposição.', type: AppToastType.success);

    await _openList(created);
  }

  Future<void> _deleteList(ShoppingListModel list) async {
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: Text(
          '“${list.name}” ficará na lixeira por 30 dias antes de ser excluída definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    await widget.store.deleteList(list.id);
    if (!mounted) {
      return;
    }
    _showDeletionUndo({list.id}, 'Lista movida para a lixeira.');
  }

  Future<void> _reopenList(ShoppingListModel list) async {
    final updated = await widget.store.reopenList(list.id);
    if (!mounted || updated == null) {
      return;
    }
    _showSnack('Lista reaberta para edição.');
  }

  void _enterSelectionMode([String? firstId]) {
    setState(() {
      _selectionMode = true;
      if (firstId != null) {
        _selectedListIds.add(firstId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedListIds.clear();
    });
  }

  void _toggleListSelection(String listId) {
    setState(() {
      if (_selectedListIds.contains(listId)) {
        _selectedListIds.remove(listId);
      } else {
        _selectedListIds.add(listId);
      }
    });
  }

  void _toggleSelectAll(List<ShoppingListModel> lists) {
    setState(() {
      if (_selectedListIds.length == lists.length) {
        _selectedListIds.clear();
      } else {
        _selectedListIds
          ..clear()
          ..addAll(lists.map((list) => list.id));
      }
    });
  }

  Future<bool> _confirmBulkDelete({
    required int count,
    required bool clearAll,
  }) async {
    final result = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clearAll ? 'Limpar todas as listas?' : 'Excluir listas?'),
        content: Text(
          clearAll
              ? 'Todas as listas serão movidas para a lixeira por 30 dias.'
              : count == 1
              ? 'A lista selecionada será movida para a lixeira por 30 dias.'
              : '$count listas selecionadas serão movidas para a lixeira por 30 dias.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _deleteSelectedLists() async {
    final availableIds = widget.store.lists.map((entry) => entry.id).toSet();
    final selectedIds = _selectedListIds
        .where((id) => availableIds.contains(id))
        .toSet();

    if (selectedIds.isEmpty) {
      return;
    }

    final shouldDelete = await _confirmBulkDelete(
      count: selectedIds.length,
      clearAll: false,
    );
    if (!mounted || !shouldDelete) {
      return;
    }

    final count = selectedIds.length;
    await widget.store.deleteListsById(selectedIds);
    if (!mounted) {
      return;
    }
    _exitSelectionMode();
    _showDeletionUndo(
      selectedIds,
      count == 1
          ? '1 lista movida para a lixeira.'
          : '$count listas movidas para a lixeira.',
    );
  }

  Future<void> _clearAllLists(List<ShoppingListModel> lists) async {
    if (lists.isEmpty) {
      return;
    }

    final shouldDelete = await _confirmBulkDelete(
      count: lists.length,
      clearAll: true,
    );
    if (!mounted || !shouldDelete) {
      return;
    }

    final count = lists.length;
    await widget.store.clearAllLists();
    if (!mounted) {
      return;
    }
    _exitSelectionMode();
    _showDeletionUndo(
      lists.map((list) => list.id).toSet(),
      count == 1
          ? '1 lista movida para a lixeira.'
          : '$count listas movidas para a lixeira.',
    );
  }

  Future<void> _exportBackup() async {
    final lists = widget.store.lists;
    if (lists.isEmpty) {
      _showSnack('Crie ao menos uma lista antes de exportar backup.');
      return;
    }

    final payload = widget.store.exportBackupJson();
    final result = await widget.backupService.exportBackup(payload);
    if (!mounted) {
      return;
    }

    switch (result.mode) {
      case BackupExportMode.file:
        final location = result.location == null
            ? 'arquivo salvo'
            : 'arquivo salvo em ${result.location}';
        _showSnack('Backup exportado: $location.');
      case BackupExportMode.clipboard:
        _showSnack('Backup copiado para a área de transferência.');
    }
  }

  Future<bool?> _askImportMode(int incomingCount) async {
    if (widget.store.lists.isEmpty) {
      return true;
    }

    return showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar backup'),
        content: Text(
          'Foram encontradas ${formatCountLabel(incomingCount, 'lista', 'listas')} no arquivo. Deseja substituir suas listas atuais ou mesclar com as existentes?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mesclar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Substituir tudo'),
          ),
        ],
      ),
    );
  }

  Future<void> _importBackup() async {
    final payload = await widget.backupService.importBackup();
    if (!mounted || payload == null) {
      return;
    }

    final preview = widget.store.tryParseBackup(payload);
    if (preview == null) {
      _showSnack('Arquivo inválido. Use um backup JSON exportado pelo app.');
      return;
    }

    if (preview.isEmpty) {
      _showSnack('Backup sem listas para importar.');
      return;
    }

    final replaceExisting = await _askImportMode(preview.length);
    if (!mounted || replaceExisting == null) {
      return;
    }

    try {
      final report = await widget.store.importBackupJson(
        payload,
        replaceExisting: replaceExisting,
      );
      if (!mounted) {
        return;
      }
      final action = report.replaced ? 'substituído' : 'mesclado';
      _showSnack(
        '${formatCountLabel(report.importedLists, 'lista', 'listas')}: backup $action com sucesso.',
      );
    } on FormatException {
      _showSnack('Não foi possível interpretar o arquivo selecionado.');
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

  void _showDeletionUndo(Set<String> listIds, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () async {
            await widget.store.restoreListsById(listIds);
            if (mounted) {
              _showSnack('Lista restaurada.', type: AppToastType.success);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.sharedListsRepository;
    final uid = widget.currentUserUid?.trim() ?? '';
    if (repository == null || uid.isEmpty) {
      return _buildWithSharedSourceMap(
        const <String, SharedShoppingListSummary>{},
      );
    }
    return StreamBuilder<List<SharedShoppingListSummary>>(
      stream: repository.watchOwnedSharedLists(uid),
      builder: (context, snapshot) {
        final sharedBySource = <String, SharedShoppingListSummary>{};
        for (final entry
            in snapshot.data ?? const <SharedShoppingListSummary>[]) {
          final sourceId = entry.sourceLocalListId;
          if (sourceId == null || sourceId.isEmpty) {
            continue;
          }
          sharedBySource[sourceId] = entry;
        }
        return _buildWithSharedSourceMap(sharedBySource);
      },
    );
  }

  Widget _buildWithSharedSourceMap(
    Map<String, SharedShoppingListSummary> sharedBySource,
  ) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final lists = widget.store.listsByCreatedAt;
        final visibleLists = _filterMyLists(
          lists,
          searchQuery: _searchQuery,
          activeFilter: _activeFilter,
          sharedBySource: sharedBySource,
        );
        final selectedCount = _selectedListIds
            .where((id) => lists.any((entry) => entry.id == id))
            .length;
        final allSelected =
            visibleLists.isNotEmpty &&
            visibleLists.every((entry) => _selectedListIds.contains(entry.id));
        final sharedListsCount = lists
            .where((entry) => sharedBySource.containsKey(entry.id))
            .length;

        final theme = mercadoEditorialTheme(Theme.of(context));
        return Theme(
          data: theme,
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                leading: _selectionMode
                    ? IconButton(
                        tooltip: 'Cancelar seleção',
                        onPressed: _exitSelectionMode,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
                title: Text(
                  _selectionMode
                      ? selectedCount == 1
                            ? '1 selecionada'
                            : '$selectedCount selecionadas'
                      : 'Minhas listas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  if (_selectionMode) ...[
                    IconButton(
                      tooltip: allSelected
                          ? 'Desmarcar todas'
                          : 'Selecionar todas',
                      onPressed: visibleLists.isEmpty
                          ? null
                          : () => _toggleSelectAll(visibleLists),
                      icon: Icon(
                        allSelected
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Excluir selecionadas',
                      onPressed: selectedCount > 0
                          ? _deleteSelectedLists
                          : null,
                      icon: const Icon(Icons.delete_sweep_rounded),
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Selecionar várias',
                      onPressed: _enterSelectionMode,
                      icon: const Icon(Icons.checklist),
                    ),
                    IconButton(
                      key: const ValueKey('my_lists_trash'),
                      tooltip: 'Abrir lixeira',
                      onPressed: _openTrash,
                      icon: Badge.count(
                        count: widget.store.trashedLists.length,
                        isLabelVisible: widget.store.trashedLists.isNotEmpty,
                        child: const Icon(Icons.delete_outline_rounded),
                      ),
                    ),
                    PopupMenuButton<_MyListsMenuAction>(
                      onSelected: (action) {
                        switch (action) {
                          case _MyListsMenuAction.viewHistory:
                            _openPurchaseHistory();
                          case _MyListsMenuAction.smartReplenishment:
                            _createSmartReplenishmentList();
                          case _MyListsMenuAction.selectMany:
                            _enterSelectionMode();
                          case _MyListsMenuAction.importBackup:
                            _importBackup();
                          case _MyListsMenuAction.exportBackup:
                            _exportBackup();
                          case _MyListsMenuAction.clearAll:
                            _clearAllLists(lists);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: _MyListsMenuAction.viewHistory,
                          child: Text('Histórico mensal'),
                        ),
                        PopupMenuItem(
                          value: _MyListsMenuAction.smartReplenishment,
                          child: Text('Reposição inteligente'),
                        ),
                        PopupMenuItem(
                          value: _MyListsMenuAction.selectMany,
                          child: Text('Selecionar várias'),
                        ),
                        PopupMenuItem(
                          value: _MyListsMenuAction.importBackup,
                          child: Text('Importar backup (JSON)'),
                        ),
                        PopupMenuItem(
                          value: _MyListsMenuAction.exportBackup,
                          child: Text('Exportar backup (JSON)'),
                        ),
                        PopupMenuItem(
                          value: _MyListsMenuAction.clearAll,
                          child: Text('Limpar todas as listas'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              body: SafeArea(
                child: MyListsLayout(
                  lists: lists,
                  sharedCount: sharedListsCount,
                  visibleCount: visibleLists.length,
                  controller: _searchController,
                  filter: _activeFilter,
                  selectionMode: _selectionMode,
                  onFilter: _setActiveFilter,
                  onClear: _clearMyListsFilters,
                  onCreate: _createNewList,
                  onTemplate: _createFromPicker,
                  onHistory: _openPurchaseHistory,
                  onReplenishment: _createSmartReplenishmentList,
                  rows: visibleLists.map((list) {
                    final sharedSummary = sharedBySource[list.id];
                    return ListLedgerRow(
                      key: ValueKey(list.id),
                      list: list,
                      sharedSummary: sharedSummary,
                      currentUserUid: widget.currentUserUid,
                      selectionMode: _selectionMode,
                      isSelected: _selectedListIds.contains(list.id),
                      onToggleSelection: () => _toggleListSelection(list.id),
                      onLongPress: () => _enterSelectionMode(list.id),
                      onOpen: () {
                        if (_selectionMode) {
                          _toggleListSelection(list.id);
                          return;
                        }
                        if (sharedSummary != null) {
                          _openSharedList(sharedSummary);
                          return;
                        }
                        _openList(list);
                      },
                      onOpenShared: sharedSummary == null
                          ? null
                          : () => _openSharedList(sharedSummary),
                      onReopen: () => _reopenList(list),
                      onCreateFromThis: () => _createFromSource(list),
                      onDelete: () => _deleteList(list),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _MyListsMenuAction {
  viewHistory,
  smartReplenishment,
  selectMany,
  importBackup,
  exportBackup,
  clearAll,
}
