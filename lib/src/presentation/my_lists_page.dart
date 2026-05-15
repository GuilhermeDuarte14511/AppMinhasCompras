import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
import 'purchase_history_page.dart';
import 'shared_lists_pages.dart';
import 'shopping_list_editor_page.dart';
import 'theme/app_tokens.dart';
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
  if (source == ReplenishmentSuggestionSource.lastMonth) {
    final targetMonth = DateTime(reference.year, reference.month - 1);
    final monthLabel = _myListsCapitalizeText(
      DateFormat('MMMM yyyy', 'pt_BR').format(targetMonth),
    );
    return 'Reposição $monthLabel';
  }
  return 'Reposição inteligente';
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

  final name = await showListNameDialog(
    context,
    title: 'Nova lista por reposição inteligente',
    confirmLabel: 'Criar lista',
    initialValue: _myListsBuildReplenishmentListName(
      selectedSuggestions.first.source,
    ),
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

enum _MyListsFilter { all, active, closed, shared }

List<ShoppingListModel> _filterMyLists(
  List<ShoppingListModel> lists, {
  required String searchQuery,
  required _MyListsFilter activeFilter,
  required Map<String, SharedShoppingListSummary> sharedBySource,
}) {
  final normalizedQuery = normalizeQuery(searchQuery);
  return lists
      .where((list) {
        final matchesFilter = switch (activeFilter) {
          _MyListsFilter.all => true,
          _MyListsFilter.active => !list.isClosed,
          _MyListsFilter.closed => list.isClosed,
          _MyListsFilter.shared => sharedBySource.containsKey(list.id),
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
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;
  final SharedListsRepository? sharedListsRepository;
  final String? currentUserUid;

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  bool _selectionMode = false;
  final Set<String> _selectedListIds = <String>{};
  late final TextEditingController _searchController;
  _MyListsFilter _activeFilter = _MyListsFilter.all;

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

  void _setActiveFilter(_MyListsFilter filter) {
    if (_activeFilter == filter) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _activeFilter = filter;
    });
  }

  void _clearMyListsFilters() {
    if (_searchController.text.isEmpty && _activeFilter == _MyListsFilter.all) {
      return;
    }
    _searchController.clear();
    setState(() {
      _activeFilter = _MyListsFilter.all;
    });
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      buildAppPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
      ),
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
    final name = await showListNameDialog(
      context,
      title: 'Criar lista baseada em "${source.name}"',
      confirmLabel: 'Criar lista',
      initialValue: '${source.name} - nova',
    );

    if (!mounted || name == null) {
      return;
    }

    final created = await widget.store.createList(name: name, basedOn: source);

    if (!mounted) {
      return;
    }

    await _openList(created);
  }

  Future<void> _createFromPicker() async {
    final lists = widget.store.lists;
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
    final name = await showListNameDialog(
      context,
      title: 'Nova lista de compras',
      confirmLabel: 'Criar lista',
    );

    if (!mounted || name == null) {
      return;
    }

    final created = await widget.store.createList(name: name);
    if (!mounted) {
      return;
    }

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

    await _openList(created);
  }

  Future<void> _deleteList(ShoppingListModel list) async {
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir lista?'),
        content: Text('Deseja excluir "${list.name}"?'),
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
    _showSnack('Lista excluída.');
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
              ? 'Essa ação vai remover todas as listas de compras.'
              : 'Deseja excluir ${formatCountLabel(count, 'lista selecionada', 'listas selecionadas')}?',
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
    _showSnack(count == 1 ? '1 lista removida.' : '$count listas removidas.');
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
    _showSnack(count == 1 ? '1 lista removida.' : '$count listas removidas.');
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

  void _showSnack(String message) {
    AppToast.show(
      context,
      message: message,
      type: AppToastType.info,
      duration: const Duration(seconds: 4),
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
        final lists = widget.store.lists;
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
        final openListsCount = lists.where((entry) => !entry.isClosed).length;
        final closedListsCount = lists.where((entry) => entry.isClosed).length;
        final sharedListsCount = lists
            .where((entry) => sharedBySource.containsKey(entry.id))
            .length;
        final hasActiveFilters =
            _searchQuery.isNotEmpty || _activeFilter != _MyListsFilter.all;

        return Scaffold(
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
            ),
            actions: [
              if (_selectionMode) ...[
                IconButton(
                  tooltip: allSelected ? 'Desmarcar todas' : 'Selecionar todas',
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
                  onPressed: selectedCount > 0 ? _deleteSelectedLists : null,
                  icon: const Icon(Icons.delete_sweep_rounded),
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Criar baseada em antiga',
                  onPressed: _createFromPicker,
                  icon: const Icon(Icons.copy_all_rounded),
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _createNewList,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nova lista'),
          ),
          body: AppGradientScene(
            child: SafeArea(
              child: lists.isEmpty
                  ? _EmptyListsState(onCreatePressed: _createNewList)
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!_selectionMode) ...[
                            _MyListsEntryAnimation(
                              key: const ValueKey('my_lists_overview'),
                              delay: Duration.zero,
                              child: _MyListsOverviewCard(
                                totalLists: lists.length,
                                activeListsCount: openListsCount,
                                closedListsCount: closedListsCount,
                                sharedListsCount: sharedListsCount,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _MyListsEntryAnimation(
                              key: const ValueKey('my_lists_controls'),
                              delay: const Duration(milliseconds: 35),
                              child: _MyListsControlsCard(
                                controller: _searchController,
                                activeFilter: _activeFilter,
                                hasActiveFilters: hasActiveFilters,
                                onFilterChanged: _setActiveFilter,
                                onClearFilters: _clearMyListsFilters,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _MyListsEntryAnimation(
                              key: const ValueKey('my_lists_header'),
                              delay: const Duration(milliseconds: 55),
                              child: _MyListsSectionHeader(
                                title: 'Suas listas',
                                subtitle: hasActiveFilters
                                    ? visibleLists.length == 1
                                          ? '1 resultado filtrado.'
                                          : '${visibleLists.length} resultados filtrados.'
                                    : 'Abertas, fechadas e compartilhadas em um só lugar.',
                                actionLabel: hasActiveFilters
                                    ? 'Limpar filtros'
                                    : null,
                                onAction: hasActiveFilters
                                    ? _clearMyListsFilters
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (visibleLists.isEmpty)
                            _EmptyFilteredListsState(
                              query: _searchQuery,
                              onClearFilters: _clearMyListsFilters,
                            )
                          else
                            ...visibleLists.asMap().entries.map((entry) {
                              final index = entry.key;
                              final list = entry.value;
                              final sharedSummary = sharedBySource[list.id];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _MyListsEntryAnimation(
                                  key: ValueKey(list.id),
                                  delay: Duration(
                                    milliseconds: min(140, index * 20),
                                  ),
                                  child: _MyListCard(
                                    list: list,
                                    sharedSummary: sharedSummary,
                                    currentUserUid: widget.currentUserUid,
                                    selectionMode: _selectionMode,
                                    isSelected: _selectedListIds.contains(
                                      list.id,
                                    ),
                                    onToggleSelection: () =>
                                        _toggleListSelection(list.id),
                                    onLongPress: () =>
                                        _enterSelectionMode(list.id),
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
                                    onCreateFromThis: () =>
                                        _createFromSource(list),
                                    onDelete: () => _deleteList(list),
                                  ),
                                ),
                              );
                            }),
                        ],
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

class _MyListsOverviewCard extends StatelessWidget {
  const _MyListsOverviewCard({
    required this.totalLists,
    required this.activeListsCount,
    required this.closedListsCount,
    required this.sharedListsCount,
  });

  final int totalLists;
  final int activeListsCount;
  final int closedListsCount;
  final int sharedListsCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer.withValues(alpha: 0.78),
            colorScheme.primaryContainer.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Painel das listas',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              totalLists == 1
                  ? 'Você tem 1 lista salva pronta para abrir, editar ou reutilizar.'
                  : 'Você tem $totalLists listas salvas para acompanhar compras e históricos.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MyListsSummaryPill(
                  icon: Icons.inventory_2_rounded,
                  label: 'Total',
                  value: '$totalLists',
                ),
                _MyListsSummaryPill(
                  icon: Icons.radio_button_checked_rounded,
                  label: 'Abertas',
                  value: '$activeListsCount',
                ),
                _MyListsSummaryPill(
                  icon: Icons.lock_rounded,
                  label: 'Fechadas',
                  value: '$closedListsCount',
                ),
                _MyListsSummaryPill(
                  icon: Icons.group_rounded,
                  label: 'Compart.',
                  value: '$sharedListsCount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyListsControlsCard extends StatelessWidget {
  const _MyListsControlsCard({
    required this.controller,
    required this.activeFilter,
    required this.hasActiveFilters,
    required this.onFilterChanged,
    required this.onClearFilters,
  });

  final TextEditingController controller;
  final _MyListsFilter activeFilter;
  final bool hasActiveFilters;
  final ValueChanged<_MyListsFilter> onFilterChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return _MyListsContentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Buscar lista pelo nome',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _MyListsFilterChip(
                  label: 'Todas',
                  selected: activeFilter == _MyListsFilter.all,
                  onTap: () => onFilterChanged(_MyListsFilter.all),
                ),
                const SizedBox(width: 8),
                _MyListsFilterChip(
                  label: 'Abertas',
                  selected: activeFilter == _MyListsFilter.active,
                  onTap: () => onFilterChanged(_MyListsFilter.active),
                ),
                const SizedBox(width: 8),
                _MyListsFilterChip(
                  label: 'Fechadas',
                  selected: activeFilter == _MyListsFilter.closed,
                  onTap: () => onFilterChanged(_MyListsFilter.closed),
                ),
                const SizedBox(width: 8),
                _MyListsFilterChip(
                  label: 'Compartilhadas',
                  selected: activeFilter == _MyListsFilter.shared,
                  onTap: () => onFilterChanged(_MyListsFilter.shared),
                ),
              ],
            ),
          ),
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onClearFilters,
              icon: Icon(
                Icons.filter_alt_off_rounded,
                color: colorScheme.primary,
              ),
              label: const Text('Limpar busca e filtros'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MyListsFilterChip extends StatelessWidget {
  const _MyListsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyFilteredListsState extends StatelessWidget {
  const _EmptyFilteredListsState({
    required this.query,
    required this.onClearFilters,
  });

  final String query;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.search_off_rounded, size: 28),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma lista encontrada',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              query.isEmpty
                  ? 'Ajuste os filtros para ver mais listas.'
                  : 'Não encontramos resultados para "$query".',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded),
              label: const Text('Limpar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyListsState extends StatelessWidget {
  const _EmptyListsState({required this.onCreatePressed});

  final VoidCallback onCreatePressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.24),
                    colorScheme.primary.withValues(alpha: 0.04),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Icon(
                  Icons.inventory_2_rounded,
                  size: 74,
                  color: colorScheme.primary.withValues(alpha: 0.78),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Você ainda Não tem listas',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira lista e acompanhe quantidades e totais em tempo real.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar primeira lista'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyListCard extends StatelessWidget {
  const _MyListCard({
    required this.list,
    this.sharedSummary,
    this.currentUserUid,
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onLongPress,
    required this.onOpen,
    this.onOpenShared,
    required this.onReopen,
    required this.onCreateFromThis,
    required this.onDelete,
  });

  final ShoppingListModel list;
  final SharedShoppingListSummary? sharedSummary;
  final String? currentUserUid;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback? onOpenShared;
  final VoidCallback onReopen;
  final VoidCallback onCreateFromThis;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isShared = sharedSummary != null;
    final lineItemsCount = list.items.length;
    final purchasedCount = list.purchasedItemsCount;
    final progress = lineItemsCount == 0
        ? 0.0
        : purchasedCount / lineItemsCount;
    final resolvedUid = currentUserUid?.trim() ?? '';
    final isSharedOwner = isShared && sharedSummary!.isOwner(resolvedUid);
    final sharedRoleLabel = isSharedOwner ? 'Dono' : 'Membro';
    final sharedRoleIcon = isSharedOwner
        ? Icons.verified_user_rounded
        : Icons.people_alt_rounded;
    final sharedLabelBg = colorScheme.tertiaryContainer.withValues(alpha: 0.72);
    final sharedLabelFg = colorScheme.onTertiaryContainer;
    final sharedMemberLabel =
        '${sharedSummary?.memberCount ?? 0} membro${(sharedSummary?.memberCount ?? 0) == 1 ? '' : 's'}';
    final isSelectedState = selectionMode && isSelected;
    final backgroundColor = isSelectedState
        ? colorScheme.primaryContainer.withValues(alpha: 0.55)
        : list.isClosed
        ? colorScheme.surfaceContainerLow.withValues(alpha: 0.85)
        : isShared
        ? Color.alphaBlend(
            colorScheme.tertiaryContainer.withValues(alpha: 0.32),
            colorScheme.surface,
          )
        : colorScheme.surface;
    final borderColor = isSelectedState
        ? colorScheme.primary.withValues(alpha: 0.55)
        : list.isClosed
        ? colorScheme.outline.withValues(alpha: 0.3)
        : isShared
        ? colorScheme.tertiary.withValues(alpha: 0.42)
        : colorScheme.outlineVariant.withValues(alpha: 0.24);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: Colors.transparent,
      elevation: 0,
      child: AnimatedContainer(
        duration: _myListsAdaptiveMotionDuration(
          context,
          const Duration(milliseconds: 220),
        ),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: selectionMode ? onToggleSelection : onOpen,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    if (selectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onToggleSelection(),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        list.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      formatShortDate(list.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: selectionMode
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (sharedSummary != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MyListsPillLabel(
                        icon: Icons.group_rounded,
                        text: 'Compartilhada',
                        backgroundColor: sharedLabelBg,
                        foregroundColor: sharedLabelFg,
                        onTap: onOpenShared,
                        tooltip: 'Abrir compartilhamento',
                      ),
                      _MyListsPillLabel(
                        icon: sharedRoleIcon,
                        text: sharedRoleLabel,
                        backgroundColor: sharedLabelBg,
                        foregroundColor: sharedLabelFg,
                        onTap: onOpenShared,
                        tooltip: 'Abrir compartilhamento',
                      ),
                      _MyListsPillLabel(
                        icon: Icons.group_add_rounded,
                        text: sharedMemberLabel,
                        backgroundColor: sharedLabelBg,
                        foregroundColor: sharedLabelFg,
                        onTap: onOpenShared,
                        tooltip: 'Abrir compartilhamento',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  lineItemsCount == 0
                      ? 'Sem itens ainda. Abra a lista para começar.'
                      : list.isClosed
                      ? purchasedCount == 1
                            ? 'Compra fechada com 1 item marcado.'
                            : 'Compra fechada com $purchasedCount itens marcados.'
                      : '$purchasedCount de ${formatItemCount(lineItemsCount)} marcados até agora.',
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
                    backgroundColor: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _MyListsPillLabel(
                      icon: Icons.shopping_basket_rounded,
                      text: '${list.totalItems} itens',
                    ),
                    const SizedBox(width: 8),
                    _MyListsPillLabel(
                      icon: Icons.attach_money_rounded,
                      text: formatCurrency(list.totalValue),
                    ),
                    const SizedBox(width: 8),
                    _MyListsPillLabel(
                      icon: Icons.check_circle_outline_rounded,
                      text: '$purchasedCount/$lineItemsCount marcados',
                    ),
                    if (list.isClosed) ...[
                      const SizedBox(width: 8),
                      const _MyListsPillLabel(
                        icon: Icons.lock_rounded,
                        text: 'Fechada',
                      ),
                    ],
                    const Spacer(),
                    if (!selectionMode) ...[
                      if (list.isClosed)
                        IconButton(
                          tooltip: 'Reabrir lista',
                          onPressed: onReopen,
                          icon: const Icon(Icons.lock_open_rounded),
                        ),
                      IconButton(
                        tooltip: 'Criar Baseada Nesta',
                        onPressed: onCreateFromThis,
                        icon: const Icon(Icons.copy_all_rounded),
                      ),
                      IconButton(
                        tooltip: 'Excluir lista',
                        onPressed: onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ] else
                      Text(
                        isSelected ? 'Selecionada' : 'Toque para selecionar',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
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

Duration _myListsAdaptiveMotionDuration(
  BuildContext context,
  Duration fallback,
) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class _MyListsContentPanel extends StatelessWidget {
  const _MyListsContentPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _MyListsSummaryPill extends StatelessWidget {
  const _MyListsSummaryPill({
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
          color: colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.32),
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
                duration: _myListsAdaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
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

class _MyListsSectionHeader extends StatelessWidget {
  const _MyListsSectionHeader({
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

class _MyListsPillLabel extends StatelessWidget {
  const _MyListsPillLabel({
    required this.icon,
    required this.text,
    this.backgroundColor,
    this.foregroundColor,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final String text;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg =
        backgroundColor ??
        colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final fg = foregroundColor ?? colorScheme.onSurface;
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: label,
      );
    }

    final interactiveChip = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: label,
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) {
      return interactiveChip;
    }
    return Tooltip(message: tooltip!, child: interactiveChip);
  }
}

class _MyListsEntryAnimation extends StatelessWidget {
  const _MyListsEntryAnimation({
    super.key,
    required this.child,
    required this.delay,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery?.disableAnimations ?? false) {
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
