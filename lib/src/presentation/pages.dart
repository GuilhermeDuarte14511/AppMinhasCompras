import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../application/ports.dart';
import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'extensions/classification_ui_extensions.dart';
import 'launch.dart';

enum _DashboardMenuAction { options }

class AppOptionsPage extends StatefulWidget {
  const AppOptionsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AppOptionsPage> createState() => _AppOptionsPageState();
}

class _AppOptionsPageState extends State<AppOptionsPage> {
  late ThemeMode _selectedThemeMode;

  @override
  void initState() {
    super.initState();
    _selectedThemeMode = widget.themeMode;
  }

  void _updateThemeMode(ThemeMode mode) {
    if (_selectedThemeMode == mode) {
      return;
    }
    setState(() {
      _selectedThemeMode = mode;
    });
    widget.onThemeModeChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Opções')),
      body: AppGradientScene(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aparência',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Escolha entre modo claro e modo escuro.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded),
                            label: Text('Claro'),
                          ),
                          ButtonSegment<ThemeMode>(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded),
                            label: Text('Escuro'),
                          ),
                        ],
                        selected: <ThemeMode>{_selectedThemeMode},
                        onSelectionChanged: (selected) {
                          if (selected.isEmpty) {
                            return;
                          }
                          _updateThemeMode(selected.first);
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedThemeMode == ThemeMode.dark
                            ? 'Modo escuro ativo com contraste reforçado.'
                            : 'Modo claro ativo (visual original).',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.store,
    required this.backupService,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Future<void> _openMyLists() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MyListsPage(
          store: widget.store,
          backupService: widget.backupService,
        ),
      ),
    );
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
      ),
    );
  }

  Future<void> _openOptions() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AppOptionsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
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

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ShoppingListEditorPage(store: widget.store, listId: created.id),
      ),
    );
  }

  Future<void> _createBasedOnOld() async {
    if (widget.store.lists.isEmpty) {
      _showSnack('Você ainda não tem listas para usar como base.');
      return;
    }

    final source = await showTemplatePickerSheet(
      context,
      lists: widget.store.lists,
    );

    if (!mounted || source == null) {
      return;
    }

    await _createNewList(basedOn: source);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final lists = widget.store.lists;
    final totalItems = lists.fold<int>(0, (sum, list) => sum + list.totalItems);
    final totalValue = lists.fold<double>(
      0,
      (sum, list) => sum + list.totalValue,
    );

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
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DashboardMenuAction.options,
                child: Text('Opções'),
              ),
            ],
          ),
        ],
      ),
      body: AppGradientScene(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              _HomeSummaryCard(
                totalLists: lists.length,
                totalItems: totalItems,
                totalValue: totalValue,
              ),
              const SizedBox(height: 14),
              _ActionTile(
                title: 'Começar nova lista de compras',
                subtitle: 'Crie uma lista do zero e adicione os produtos.',
                icon: Icons.playlist_add_rounded,
                onTap: _createNewList,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                title: 'Minhas listas de compras',
                subtitle: 'Abra, edite e exclua suas listas salvas.',
                icon: Icons.inventory_2_rounded,
                onTap: _openMyLists,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                title: 'Histórico mensal',
                subtitle: 'Revise fechamentos e totais por mês.',
                icon: Icons.event_note_rounded,
                onTap: _openPurchaseHistory,
              ),
              const SizedBox(height: 10),
              _ActionTile(
                title: 'Nova lista baseada em antiga',
                subtitle: 'Use outra lista como modelo e acelere a compra.',
                icon: Icons.copy_all_rounded,
                onTap: _createBasedOnOld,
              ),
              const SizedBox(height: 20),
              Text(
                'Listas recentes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              if (lists.isEmpty)
                const _EmptyRecentListsCard()
              else
                ...lists
                    .take(3)
                    .map(
                      (list) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _RecentListCard(
                          list: list,
                          onTap: () {
                            Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShoppingListEditorPage(
                                  store: widget.store,
                                  listId: list.id,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ],
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

class MyListsPage extends StatefulWidget {
  const MyListsPage({
    super.key,
    required this.store,
    required this.backupService,
  });

  final ShoppingListsStore store;
  final ShoppingBackupService backupService;

  @override
  State<MyListsPage> createState() => _MyListsPageState();
}

class _MyListsPageState extends State<MyListsPage> {
  bool _selectionMode = false;
  final Set<String> _selectedListIds = <String>{};

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
      ),
    );
  }

  Future<void> _openList(ShoppingListModel list) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ShoppingListEditorPage(store: widget.store, listId: list.id),
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
      _showSnack('Não ha listas antigas para copiar.');
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

  Future<void> _deleteList(ShoppingListModel list) async {
    final shouldDelete = await showDialog<bool>(
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
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clearAll ? 'Limpar todas as listas?' : 'Excluir listas?'),
        content: Text(
          clearAll
              ? 'Essa ação vai remover todas as listas de compras.'
              : 'Deseja excluir $count lista(s) selecionada(s)?',
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
    _showSnack('$count lista(s) removida(s).');
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
    _showSnack('$count lista(s) removida(s).');
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
        _showSnack('Backup copiado para a area de transferencia.');
    }
  }

  Future<bool?> _askImportMode(int incomingCount) async {
    if (widget.store.lists.isEmpty) {
      return true;
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar backup'),
        content: Text(
          'Foram encontradas $incomingCount lista(s) no arquivo. Deseja substituir suas listas atuais ou mesclar com as existentes?',
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
      final action = report.replaced ? 'substituido' : 'mesclado';
      _showSnack(
        '${report.importedLists} lista(s): backup $action com sucesso.',
      );
    } on FormatException {
      _showSnack('Não foi possível interpretar o arquivo selecionado.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final lists = widget.store.lists;
        final selectedCount = _selectedListIds
            .where((id) => lists.any((entry) => entry.id == id))
            .length;
        final allSelected = lists.isNotEmpty && selectedCount == lists.length;

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
                  ? '$selectedCount selecionada(s)'
                  : 'Minhas listas',
            ),
            actions: [
              if (_selectionMode) ...[
                IconButton(
                  tooltip: allSelected ? 'Desmarcar todas' : 'Selecionar todas',
                  onPressed: lists.isEmpty
                      ? null
                      : () => _toggleSelectAll(lists),
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
          body: lists.isEmpty
              ? _EmptyListsState(onCreatePressed: _createNewList)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _EntryAnimation(
                        key: ValueKey(list.id),
                        delay: Duration(milliseconds: min(140, index * 20)),
                        child: _MyListCard(
                          list: list,
                          selectionMode: _selectionMode,
                          isSelected: _selectedListIds.contains(list.id),
                          onToggleSelection: () =>
                              _toggleListSelection(list.id),
                          onLongPress: () => _enterSelectionMode(list.id),
                          onOpen: () {
                            if (_selectionMode) {
                              _toggleListSelection(list.id);
                              return;
                            }
                            _openList(list);
                          },
                          onReopen: () => _reopenList(list),
                          onCreateFromThis: () => _createFromSource(list),
                          onDelete: () => _deleteList(list),
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class PurchaseHistoryPage extends StatefulWidget {
  const PurchaseHistoryPage({super.key, required this.store});

  final ShoppingListsStore store;

  @override
  State<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends State<PurchaseHistoryPage> {
  late final TextEditingController _searchController;

  String get _searchQuery => _searchController.text.trim();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<DateTime, List<CompletedPurchase>> _filteredHistoryByMonth() {
    final grouped = widget.store.historyGroupedByMonth();
    final normalizedQuery = normalizeQuery(_searchQuery);
    if (normalizedQuery.isEmpty) {
      return grouped;
    }

    final filtered = <DateTime, List<CompletedPurchase>>{};
    for (final entry in grouped.entries) {
      final matches = entry.value
          .where((purchase) {
            if (normalizeQuery(purchase.listName).contains(normalizedQuery)) {
              return true;
            }
            for (final item in purchase.items) {
              if (normalizeQuery(item.name).contains(normalizedQuery)) {
                return true;
              }
            }
            return false;
          })
          .toList(growable: false);
      if (matches.isNotEmpty) {
        filtered[entry.key] = matches;
      }
    }
    return filtered;
  }

  String _monthLabel(DateTime month) {
    final raw = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    if (raw.isEmpty) {
      return '';
    }
    return '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  Future<void> _showPurchaseDetails(CompletedPurchase purchase) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _CompletedPurchaseDetailsSheet(purchase: purchase),
    );
  }

  Future<void> _deletePurchase(CompletedPurchase purchase) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir fechamento?'),
        content: Text(
          'Deseja remover o fechamento da lista "${purchase.listName}" em ${formatDateTime(purchase.closedAt)}?',
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
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.deleteCompletedPurchase(purchase.id);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Fechamento removido do histórico.'),
        ),
      );
  }

  Future<void> _clearHistory() async {
    if (widget.store.purchaseHistory.isEmpty) {
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico mensal?'),
        content: const Text(
          'Essa ação remove todos os fechamentos salvos no histórico.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    await widget.store.clearPurchaseHistory();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Histórico mensal limpo com sucesso.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final grouped = _filteredHistoryByMonth();
        final totalEntries = grouped.values.fold<int>(
          0,
          (sum, entries) => sum + entries.length,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Histórico mensal'),
            actions: [
              IconButton(
                tooltip: 'Limpar histórico',
                onPressed: widget.store.purchaseHistory.isEmpty
                    ? null
                    : _clearHistory,
                icon: const Icon(Icons.delete_sweep_rounded),
              ),
            ],
          ),
          body: AppGradientScene(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por lista ou produto',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: grouped.isEmpty
                        ? _EmptyPurchaseHistoryState(
                            hasQuery: _searchQuery.isNotEmpty,
                            onClearSearch: _searchController.clear,
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            children: [
                              Text(
                                '$totalEntries fechamento(s) encontrado(s)',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ...grouped.entries.map((group) {
                                final month = group.key;
                                final entries = group.value;
                                final monthTotal = entries.fold<double>(
                                  0,
                                  (sum, purchase) => sum + purchase.totalValue,
                                );
                                final monthPurchased = entries.fold<double>(
                                  0,
                                  (sum, purchase) =>
                                      sum + purchase.purchasedValue,
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _monthLabel(month),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _PillLabel(
                                                icon:
                                                    Icons.receipt_long_rounded,
                                                text:
                                                    '${entries.length} fechamento(s)',
                                              ),
                                              _PillLabel(
                                                icon: Icons.payments_rounded,
                                                text:
                                                    'Planejado ${formatCurrency(monthTotal)}',
                                              ),
                                              _PillLabel(
                                                icon:
                                                    Icons.check_circle_rounded,
                                                text:
                                                    'Comprado ${formatCurrency(monthPurchased)}',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ...entries.map((purchase) {
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 8,
                                              ),
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                onTap: () =>
                                                    _showPurchaseDetails(
                                                      purchase,
                                                    ),
                                                child: Ink(
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          16,
                                                        ),
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withValues(
                                                          alpha: 0.38,
                                                        ),
                                                  ),
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          12,
                                                          10,
                                                          8,
                                                          10,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                purchase
                                                                    .listName,
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .titleSmall
                                                                    ?.copyWith(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w700,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                formatDateTime(
                                                                  purchase
                                                                      .closedAt,
                                                                ),
                                                                style: Theme.of(context)
                                                                    .textTheme
                                                                    .bodySmall
                                                                    ?.copyWith(
                                                                      color: Theme.of(
                                                                        context,
                                                                      ).colorScheme.onSurfaceVariant,
                                                                    ),
                                                              ),
                                                              const SizedBox(
                                                                height: 6,
                                                              ),
                                                              Text(
                                                                'Planejado: ${formatCurrency(purchase.totalValue)}',
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.bodySmall,
                                                              ),
                                                              Text(
                                                                'Comprado: ${formatCurrency(purchase.purchasedValue)}',
                                                                style: Theme.of(
                                                                  context,
                                                                ).textTheme.bodySmall,
                                                              ),
                                                              if (purchase
                                                                  .hasPaymentBalances)
                                                                Text(
                                                                  purchase.uncoveredSpentAmount >
                                                                          0
                                                                      ? 'Falta cobrir: ${formatCurrency(purchase.uncoveredSpentAmount)}'
                                                                      : 'Despesa coberta pelos saldos.',
                                                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                                    color:
                                                                        purchase.uncoveredSpentAmount >
                                                                            0
                                                                        ? Theme.of(
                                                                            context,
                                                                          ).colorScheme.error
                                                                        : Theme.of(
                                                                            context,
                                                                          ).colorScheme.primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                        PopupMenuButton<String>(
                                                          onSelected: (value) {
                                                            switch (value) {
                                                              case 'details':
                                                                _showPurchaseDetails(
                                                                  purchase,
                                                                );
                                                              case 'delete':
                                                                _deletePurchase(
                                                                  purchase,
                                                                );
                                                            }
                                                          },
                                                          itemBuilder:
                                                              (
                                                                context,
                                                              ) => const [
                                                                PopupMenuItem(
                                                                  value:
                                                                      'details',
                                                                  child: Text(
                                                                    'Ver detalhes',
                                                                  ),
                                                                ),
                                                                PopupMenuItem(
                                                                  value:
                                                                      'delete',
                                                                  child: Text(
                                                                    'Excluir fechamento',
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
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyPurchaseHistoryState extends StatelessWidget {
  const _EmptyPurchaseHistoryState({
    required this.hasQuery,
    required this.onClearSearch,
  });

  final bool hasQuery;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final title = hasQuery
        ? 'Nenhum fechamento encontrado'
        : 'Sem histórico de compras';
    final description = hasQuery
        ? 'Tente outro termo para lista ou produto.'
        : 'Feche uma compra para gerar relatorios mensais.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 82,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (hasQuery) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar busca'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedPurchaseDetailsSheet extends StatelessWidget {
  const _CompletedPurchaseDetailsSheet({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final orderedItems = [...purchase.items]
      ..sort((a, b) {
        if (a.isPurchased != b.isPurchased) {
          return a.isPurchased ? -1 : 1;
        }
        return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
      });

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
      children: [
        Text(
          purchase.listName,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Fechada em ${formatDateTime(purchase.closedAt)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PillLabel(
              icon: Icons.shopping_bag_rounded,
              text: '${purchase.productsCount} produto(s)',
            ),
            _PillLabel(
              icon: Icons.confirmation_number_rounded,
              text: '${purchase.totalItems} unidade(s)',
            ),
            _PillLabel(
              icon: Icons.attach_money_rounded,
              text: 'Planejado ${formatCurrency(purchase.totalValue)}',
            ),
            _PillLabel(
              icon: Icons.check_circle_rounded,
              text: 'Comprado ${formatCurrency(purchase.purchasedValue)}',
            ),
            if (purchase.pendingProductsCount > 0)
              _PillLabel(
                icon: Icons.pending_actions_rounded,
                text: '${purchase.pendingProductsCount} pendente(s)',
              ),
            if (purchase.hasBudget)
              _PillLabel(
                icon: Icons.account_balance_wallet_rounded,
                text: 'Orçamento ${formatCurrency(purchase.budget!)}',
              ),
            if (purchase.hasPaymentBalances)
              _PillLabel(
                icon: Icons.payments_rounded,
                text: 'Saldos ${formatCurrency(purchase.paymentBalancesTotal)}',
              ),
            if (purchase.hasPaymentBalances)
              _PillLabel(
                icon: purchase.uncoveredSpentAmount > 0
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                text: purchase.uncoveredSpentAmount > 0
                    ? 'Falta ${formatCurrency(purchase.uncoveredSpentAmount)}'
                    : 'Coberto ${formatCurrency(purchase.coveredSpentAmount)}',
              ),
          ],
        ),
        if (purchase.hasPaymentBalances) ...[
          const SizedBox(height: 12),
          _CompletedPurchasePaymentPanel(purchase: purchase),
        ],
        const SizedBox(height: 12),
        ...orderedItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: Icon(
                  item.isPurchased
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                ),
                title: Text(item.name),
                subtitle: Text(
                  '${item.quantity} x ${formatCurrency(item.unitPrice)} - ${item.category.label}',
                ),
                trailing: Text(
                  formatCurrency(item.subtotal),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CompletedPurchasePaymentPanel extends StatelessWidget {
  const _CompletedPurchasePaymentPanel({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = purchase.paymentUsage
        .where((entry) => entry.balance.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Como a compra foi paga',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Despesa considerada: ${formatCurrency(purchase.spentValue)}',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final progress = entry.balance.value <= 0
                  ? 0.0
                  : (entry.consumed / entry.balance.value)
                        .clamp(0.0, 1.0)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.balance.name} (${entry.balance.type.label})',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${formatCurrency(entry.consumed)} / ${formatCurrency(entry.balance.value)}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isExhausted
                          ? 'Saldo esgotado.'
                          : 'Restante: ${formatCurrency(entry.remaining)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.isExhausted
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (purchase.uncoveredSpentAmount > 0)
              Text(
                'Ainda sem cobertura: ${formatCurrency(purchase.uncoveredSpentAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MyListsMenuAction {
  viewHistory,
  selectMany,
  importBackup,
  exportBackup,
  clearAll,
}

enum _ListEditorMenuAction {
  reopenList,
  importFiscalReceipt,
  finalizePurchase,
  openMarketMode,
  viewHistory,
  editReminder,
  editBudget,
  editPaymentBalances,
  toggleMarketOrdering,
  renameList,
  clearPurchased,
}

class _ListEditorActionsSheet extends StatelessWidget {
  const _ListEditorActionsSheet({
    required this.isReadOnly,
    required this.hasReminder,
    required this.hasPurchasedItems,
    required this.marketOrderingEnabled,
  });

  final bool isReadOnly;
  final bool hasReminder;
  final bool hasPurchasedItems;
  final bool marketOrderingEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final quickActions = isReadOnly
        ? const <_ListEditorMenuAction>[_ListEditorMenuAction.reopenList]
        : const <_ListEditorMenuAction>[
            _ListEditorMenuAction.finalizePurchase,
            _ListEditorMenuAction.importFiscalReceipt,
            _ListEditorMenuAction.openMarketMode,
          ];
    final purchaseActions = <_ListEditorMenuAction>[
      if (!isReadOnly) ...[
        _ListEditorMenuAction.importFiscalReceipt,
        _ListEditorMenuAction.finalizePurchase,
        _ListEditorMenuAction.openMarketMode,
        if (hasPurchasedItems) _ListEditorMenuAction.clearPurchased,
      ],
      if (isReadOnly) _ListEditorMenuAction.reopenList,
      _ListEditorMenuAction.viewHistory,
    ];
    final settingsActions = isReadOnly
        ? const <_ListEditorMenuAction>[]
        : <_ListEditorMenuAction>[
            _ListEditorMenuAction.editReminder,
            _ListEditorMenuAction.editBudget,
            _ListEditorMenuAction.editPaymentBalances,
            _ListEditorMenuAction.toggleMarketOrdering,
            _ListEditorMenuAction.renameList,
          ];

    _ListEditorActionMeta resolveMeta(_ListEditorMenuAction action) {
      switch (action) {
        case _ListEditorMenuAction.reopenList:
          return _ListEditorActionMeta(
            label: 'Reabrir lista',
            shortLabel: 'Reabrir',
            icon: Icons.lock_open_rounded,
            color: const Color(0xFF1E88E5),
          );
        case _ListEditorMenuAction.importFiscalReceipt:
          return _ListEditorActionMeta(
            label: 'Importar cupom fiscal',
            shortLabel: 'Cupom',
            icon: Icons.receipt_long_rounded,
            color: const Color(0xFFF57C00),
          );
        case _ListEditorMenuAction.finalizePurchase:
          return _ListEditorActionMeta(
            label: 'Fechar compra',
            shortLabel: 'Fechar',
            icon: Icons.task_alt_rounded,
            color: const Color(0xFF2E7D32),
          );
        case _ListEditorMenuAction.openMarketMode:
          return _ListEditorActionMeta(
            label: 'Abrir modo compra',
            shortLabel: 'Modo compra',
            icon: Icons.shopping_cart_checkout_rounded,
            color: const Color(0xFF00897B),
          );
        case _ListEditorMenuAction.viewHistory:
          return _ListEditorActionMeta(
            label: 'Histórico mensal',
            shortLabel: 'Histórico',
            icon: Icons.event_note_rounded,
            color: const Color(0xFF6D4C41),
          );
        case _ListEditorMenuAction.editReminder:
          return _ListEditorActionMeta(
            label: 'Configurar lembrete',
            shortLabel: hasReminder ? 'Lembrete on' : 'Lembrete off',
            icon: hasReminder
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
            color: const Color(0xFF8E24AA),
          );
        case _ListEditorMenuAction.editBudget:
          return _ListEditorActionMeta(
            label: 'Definir orçamento',
            shortLabel: 'Orçamento',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF3949AB),
          );
        case _ListEditorMenuAction.editPaymentBalances:
          return _ListEditorActionMeta(
            label: 'Configurar saldos',
            shortLabel: 'Saldos',
            icon: Icons.payments_rounded,
            color: const Color(0xFF00838F),
          );
        case _ListEditorMenuAction.toggleMarketOrdering:
          return _ListEditorActionMeta(
            label: marketOrderingEnabled
                ? 'Desativar ordem de mercado'
                : 'Ativar ordem de mercado',
            shortLabel: marketOrderingEnabled ? 'Ordem off' : 'Ordem on',
            icon: marketOrderingEnabled
                ? Icons.storefront_rounded
                : Icons.storefront_outlined,
            color: const Color(0xFF5E35B1),
          );
        case _ListEditorMenuAction.renameList:
          return _ListEditorActionMeta(
            label: 'Renomear lista',
            shortLabel: 'Renomear',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF546E7A),
          );
        case _ListEditorMenuAction.clearPurchased:
          return _ListEditorActionMeta(
            label: 'Limpar comprados',
            shortLabel: 'Limpar',
            icon: Icons.cleaning_services_rounded,
            color: const Color(0xFFC62828),
          );
      }
    }

    return SizedBox(
      height: min(MediaQuery.sizeOf(context).height * 0.88, 700),
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
        children: [
          Text(
            'Ações da lista',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Tudo em um único menu, com atalhos para as ações principais.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ações rápidas',
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quickActions
                .map((action) {
                  final meta = resolveMeta(action);
                  return _ListEditorQuickActionCard(
                    meta: meta,
                    onTap: () => Navigator.pop(context, action),
                  );
                })
                .toList(growable: false),
          ),
          const SizedBox(height: 14),
          _ListEditorActionSection(
            title: 'Compra',
            actions: purchaseActions,
            resolveMeta: resolveMeta,
            onTap: (action) => Navigator.pop(context, action),
          ),
          if (settingsActions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ListEditorActionSection(
              title: 'Configurações',
              actions: settingsActions,
              resolveMeta: resolveMeta,
              onTap: (action) => Navigator.pop(context, action),
            ),
          ],
        ],
      ),
    );
  }
}

class _ListEditorActionSection extends StatelessWidget {
  const _ListEditorActionSection({
    required this.title,
    required this.actions,
    required this.resolveMeta,
    required this.onTap,
  });

  final String title;
  final List<_ListEditorMenuAction> actions;
  final _ListEditorActionMeta Function(_ListEditorMenuAction action)
  resolveMeta;
  final ValueChanged<_ListEditorMenuAction> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.72),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _ListEditorActionTile(
                  meta: resolveMeta(actions[i]),
                  onTap: () => onTap(actions[i]),
                ),
                if (i < actions.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    endIndent: 12,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.65),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ListEditorActionTile extends StatelessWidget {
  const _ListEditorActionTile({required this.meta, required this.onTap});

  final _ListEditorActionMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: meta.color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(meta.icon, color: meta.color, size: 18),
        ),
      ),
      title: Text(meta.label),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _ListEditorQuickActionCard extends StatelessWidget {
  const _ListEditorQuickActionCard({required this.meta, required this.onTap});

  final _ListEditorActionMeta meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 104, maxWidth: 128),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: meta.color.withValues(alpha: 0.12),
              border: Border.all(color: meta.color.withValues(alpha: 0.26)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(meta.icon, color: meta.color),
                const SizedBox(height: 6),
                Text(
                  meta.shortLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListEditorActionMeta {
  const _ListEditorActionMeta({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.color,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final Color color;
}

class ShoppingListEditorPage extends StatefulWidget {
  const ShoppingListEditorPage({
    super.key,
    required this.store,
    required this.listId,
  });

  final ShoppingListsStore store;
  final String listId;

  @override
  State<ShoppingListEditorPage> createState() => _ShoppingListEditorPageState();
}

class _ShoppingListEditorPageState extends State<ShoppingListEditorPage> {
  late ShoppingListModel _list;
  bool _notFound = false;
  ItemSortOption _sortOption = ItemSortOption.defaultOrder;
  late final TextEditingController _searchController;
  ShoppingCategory? _categoryFilter;
  bool _marketModeEnabled = false;
  bool _summaryCollapsed = true;
  bool _didShowBudgetWarning = false;

  String get _searchQuery => _searchController.text.trim();
  bool get _isReadOnly => _list.isClosed;
  bool get _hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _sortOption != ItemSortOption.defaultOrder ||
      _categoryFilter != null ||
      _marketModeEnabled;

  List<ShoppingItem> get _visibleItems {
    final normalizedQuery = normalizeQuery(_searchQuery);
    final sourceItems = [..._list.items];
    final filteredItems = sourceItems
        .where((item) {
          final matchesName = normalizedQuery.isEmpty
              ? true
              : normalizeQuery(item.name).contains(normalizedQuery);
          final matchesCategory = _categoryFilter == null
              ? true
              : item.category == _categoryFilter;
          return matchesName && matchesCategory;
        })
        .toList(growable: false);

    final originalIndexById = <String, int>{};
    for (var index = 0; index < _list.items.length; index++) {
      originalIndexById[_list.items[index].id] = index;
    }

    int fallback(ShoppingItem a, ShoppingItem b) {
      final left = originalIndexById[a.id] ?? 0;
      final right = originalIndexById[b.id] ?? 0;
      return left.compareTo(right);
    }

    filteredItems.sort((a, b) {
      if (_marketModeEnabled) {
        final byCategory = a.category.marketOrder.compareTo(
          b.category.marketOrder,
        );
        if (byCategory != 0) {
          return byCategory;
        }
        final byName = normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
        return byName != 0 ? byName : fallback(a, b);
      }

      switch (_sortOption) {
        case ItemSortOption.defaultOrder:
          return fallback(a, b);
        case ItemSortOption.nameAsc:
          final byName = normalizeQuery(
            a.name,
          ).compareTo(normalizeQuery(b.name));
          return byName != 0 ? byName : fallback(a, b);
        case ItemSortOption.nameDesc:
          final byName = normalizeQuery(
            b.name,
          ).compareTo(normalizeQuery(a.name));
          return byName != 0 ? byName : fallback(a, b);
        case ItemSortOption.valueAsc:
          final byValue = a.subtotal.compareTo(b.subtotal);
          return byValue != 0 ? byValue : fallback(a, b);
        case ItemSortOption.valueDesc:
          final byValue = b.subtotal.compareTo(a.subtotal);
          return byValue != 0 ? byValue : fallback(a, b);
      }
    });

    return filteredItems;
  }

  bool _ensureEditable([String? message]) {
    if (!_isReadOnly) {
      return true;
    }
    _showSnack(
      message ??
          'Esta lista esta fechada. Reabra a lista para editar produtos.',
    );
    return false;
  }

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchController.addListener(_handleSearchChanged);
    final fromStore = widget.store.findById(widget.listId);
    if (fromStore == null) {
      _notFound = true;
      _list = ShoppingListModel.empty(name: 'Lista removida');
      return;
    }
    _list = fromStore.deepCopy();
    _didShowBudgetWarning = _list.isOverBudget;
  }

  @override
  void dispose() {
    _searchController.removeListener(_handleSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _updateList(ShoppingListModel updated, {String? message}) {
    final normalized = updated.copyWith(updatedAt: DateTime.now());
    setState(() {
      _list = normalized;
    });
    _maybeWarnBudgetExceeded(normalized);
    unawaited(widget.store.upsertList(_list));
    if (message != null) {
      _showSnack(message);
    }
  }

  Future<void> _renameList() async {
    if (!_ensureEditable()) {
      return;
    }
    final newName = await showListNameDialog(
      context,
      title: 'Renomear lista',
      confirmLabel: 'Salvar',
      initialValue: _list.name,
    );

    if (!mounted || newName == null) {
      return;
    }

    _updateList(
      _list.copyWith(name: newName),
      message: 'Nome da lista atualizado.',
    );
  }

  Future<void> _openItemForm({ShoppingItem? existing}) async {
    if (!_ensureEditable()) {
      return;
    }
    final blockedNames = _list.items
        .where((item) => existing == null || item.id != existing.id)
        .map((item) => normalizeQuery(item.name))
        .toSet();
    final suggestionCatalog = widget.store.suggestProductNames(
      currentListId: _list.id,
      limit: 20,
    );

    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: existing,
      blockedNormalizedNames: blockedNames,
      suggestionCatalog: suggestionCatalog,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );

    if (!mounted || draft == null) {
      return;
    }

    final items = [..._list.items];
    if (existing == null) {
      items.add(
        ShoppingItem(
          id: uniqueId(),
          name: draft.name,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          barcode: draft.barcode,
          category: draft.category,
          priceHistory: [
            PriceHistoryEntry(
              price: draft.unitPrice,
              recordedAt: DateTime.now(),
            ),
          ],
        ),
      );
    } else {
      final index = items.indexWhere((item) => item.id == existing.id);
      if (index != -1) {
        final history = [...existing.priceHistory];
        if (history.isEmpty) {
          history.add(
            PriceHistoryEntry(
              price: existing.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }
        final shouldAddHistory =
            history.isEmpty ||
            (history.last.price - draft.unitPrice).abs() > 0.0001;
        if (shouldAddHistory) {
          history.add(
            PriceHistoryEntry(
              price: draft.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }

        items[index] = existing.copyWith(
          name: draft.name,
          quantity: draft.quantity,
          unitPrice: draft.unitPrice,
          barcode: draft.barcode,
          category: draft.category,
          priceHistory: history,
        );
      }
    }

    _updateList(
      _list.copyWith(items: items),
      message: existing == null ? 'Produto adicionado.' : 'Produto atualizado.',
    );
    unawaited(widget.store.saveDraftToCatalog(draft));
  }

  Future<void> _importFromFiscalReceipt() async {
    if (!_ensureEditable()) {
      return;
    }

    final drafts = await showFiscalReceiptImportSheet(context);
    if (!mounted || drafts == null || drafts.isEmpty) {
      return;
    }

    final items = [..._list.items];
    var addedCount = 0;
    var mergedCount = 0;

    for (final draft in drafts) {
      final normalizedDraftName = normalizeQuery(draft.name);
      if (normalizedDraftName.isEmpty) {
        continue;
      }

      final index = items.indexWhere(
        (item) => normalizeQuery(item.name) == normalizedDraftName,
      );
      if (index == -1) {
        items.add(
          ShoppingItem(
            id: uniqueId(),
            name: draft.name,
            quantity: draft.quantity,
            unitPrice: draft.unitPrice,
            category: draft.category,
            priceHistory: [
              PriceHistoryEntry(
                price: draft.unitPrice,
                recordedAt: DateTime.now(),
              ),
            ],
          ),
        );
        addedCount++;
      } else {
        final existing = items[index];
        final history = [...existing.priceHistory];
        if (history.isEmpty) {
          history.add(
            PriceHistoryEntry(
              price: existing.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }
        if ((history.last.price - draft.unitPrice).abs() > 0.0001) {
          history.add(
            PriceHistoryEntry(
              price: draft.unitPrice,
              recordedAt: DateTime.now(),
            ),
          );
        }
        items[index] = existing.copyWith(
          quantity: existing.quantity + draft.quantity,
          unitPrice: draft.unitPrice,
          category: draft.category,
          priceHistory: history,
        );
        mergedCount++;
      }

      unawaited(widget.store.saveDraftToCatalog(draft));
    }

    if (addedCount == 0 && mergedCount == 0) {
      _showSnack('Nenhum item válido foi extraído do cupom.');
      return;
    }

    _updateList(
      _list.copyWith(items: items),
      message:
          'Cupom importado: $addedCount novo(s), $mergedCount atualizado(s).',
    );
  }

  void _togglePurchased(ShoppingItem item, bool? value) {
    if (!_ensureEditable()) {
      return;
    }
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }

    final items = [..._list.items];
    items[index] = item.copyWith(isPurchased: value ?? false);
    _updateList(_list.copyWith(items: items));
  }

  void _changeQuantity(ShoppingItem item, int delta) {
    if (!_ensureEditable()) {
      return;
    }
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }

    final items = [..._list.items];
    items[index] = item.copyWith(quantity: max(1, item.quantity + delta));
    _updateList(_list.copyWith(items: items));
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    if (!_ensureEditable()) {
      return;
    }
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text('Deseja remover "${item.name}" da lista?'),
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

    final items = [..._list.items]..removeWhere((entry) => entry.id == item.id);
    _updateList(
      _list.copyWith(items: items),
      message: '"${item.name}" removido.',
    );
  }

  Future<void> _showPriceHistory(ShoppingItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return _PriceHistorySheet(item: item);
      },
    );
  }

  Future<void> _clearPurchased() async {
    if (!_ensureEditable()) {
      return;
    }
    if (_list.purchasedItemsCount == 0) {
      return;
    }

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar comprados?'),
        content: const Text(
          'Essa ação remove apenas os itens marcados como comprados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (!mounted || shouldClear != true) {
      return;
    }

    final removedCount = _list.purchasedItemsCount;
    final remaining = _list.items
        .where((item) => !item.isPurchased)
        .toList(growable: false);
    _updateList(
      _list.copyWith(items: remaining),
      message: '$removedCount item(ns) removido(s).',
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
      );
  }

  void _maybeWarnBudgetExceeded(ShoppingListModel updatedList) {
    if (updatedList.isOverBudget && !_didShowBudgetWarning) {
      _didShowBudgetWarning = true;
      _showSnack(
        'Orçamento excedido em ${formatCurrency(updatedList.overBudgetAmount)}.',
      );
      return;
    }

    if (!updatedList.isOverBudget) {
      _didShowBudgetWarning = false;
    }
  }

  Future<void> _openBudgetEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final result = await showBudgetEditorDialog(
      context,
      initialValue: _list.budget,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.clear) {
      _updateList(
        _list.copyWith(clearBudget: true),
        message: 'Orçamento removido.',
      );
      return;
    }

    final value = result.value;
    if (value == null || value <= 0) {
      return;
    }

    _updateList(
      _list.copyWith(budget: value),
      message: 'Orçamento atualizado.',
    );
  }

  Future<void> _openPaymentBalancesEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final result = await showPaymentBalancesEditorDialog(
      context,
      initialValues: _list.paymentBalances,
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.clear || (result.value?.isEmpty ?? true)) {
      _updateList(
        _list.copyWith(clearPaymentBalances: true),
        message: 'Saldos removidos.',
      );
      return;
    }

    _updateList(
      _list.copyWith(paymentBalances: result.value),
      message: 'Saldos de pagamento atualizados.',
    );
  }

  Future<void> _openReminderEditor() async {
    if (!_ensureEditable()) {
      return;
    }
    final result = await showReminderEditorDialog(
      context,
      initialValue: _list.reminder,
    );

    if (!mounted || result == null) {
      return;
    }

    if (result.clear || result.value == null) {
      _updateList(
        _list.copyWith(clearReminder: true),
        message: 'Lembrete removido.',
      );
      return;
    }

    final reminder = result.value!;
    _updateList(
      _list.copyWith(reminder: reminder),
      message: 'Lembrete ativo: ${formatDateTime(reminder.scheduledAt)}.',
    );
  }

  Future<void> _openMarketShoppingMode() async {
    if (!_ensureEditable()) {
      return;
    }
    if (_list.items.isEmpty) {
      _showSnack('Adicione produtos antes de abrir o modo compra.');
      return;
    }

    final updated = await Navigator.push<ShoppingListModel>(
      context,
      MaterialPageRoute(
        builder: (_) => ShoppingMarketModePage(initialList: _list),
      ),
    );

    if (!mounted || updated == null) {
      return;
    }

    _updateList(updated, message: 'Modo compra atualizado com sucesso.');
  }

  Future<void> _openPurchaseHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseHistoryPage(store: widget.store),
      ),
    );
  }

  Future<void> _reopenListForEditing() async {
    final updated = await widget.store.reopenList(_list.id);
    if (!mounted || updated == null) {
      return;
    }
    setState(() {
      _list = updated.deepCopy();
      _didShowBudgetWarning = _list.isOverBudget;
    });
    _showSnack('Lista reaberta. Edicoes liberadas.');
  }

  Future<void> _finalizePurchase() async {
    if (_isReadOnly) {
      _showSnack('A lista já está fechada. Toque em reabrir para editar.');
      return;
    }
    if (_list.items.isEmpty) {
      _showSnack('Adicione itens antes de fechar a compra.');
      return;
    }

    final checkout = await showPurchaseCheckoutDialog(context, list: _list);
    if (!mounted || checkout == null) {
      return;
    }

    final didFinalize =
        await widget.store.finalizeList(
          _list.id,
          markPendingAsPurchased: checkout.markPendingAsPurchased,
        ) !=
        null;
    if (!mounted || !didFinalize) {
      return;
    }
    _showSnack('Compra fechada e salva no histórico mensal.');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _sortOption = ItemSortOption.defaultOrder;
      _categoryFilter = null;
      _marketModeEnabled = false;
    });
  }

  void _handleAppBarMenuAction(_ListEditorMenuAction action) {
    switch (action) {
      case _ListEditorMenuAction.reopenList:
        _reopenListForEditing();
        return;
      case _ListEditorMenuAction.importFiscalReceipt:
        _importFromFiscalReceipt();
        return;
      case _ListEditorMenuAction.finalizePurchase:
        _finalizePurchase();
        return;
      case _ListEditorMenuAction.openMarketMode:
        _openMarketShoppingMode();
        return;
      case _ListEditorMenuAction.viewHistory:
        _openPurchaseHistory();
        return;
      case _ListEditorMenuAction.editReminder:
        _openReminderEditor();
        return;
      case _ListEditorMenuAction.editBudget:
        _openBudgetEditor();
        return;
      case _ListEditorMenuAction.editPaymentBalances:
        _openPaymentBalancesEditor();
        return;
      case _ListEditorMenuAction.toggleMarketOrdering:
        setState(() {
          _marketModeEnabled = !_marketModeEnabled;
        });
        return;
      case _ListEditorMenuAction.renameList:
        _renameList();
        return;
      case _ListEditorMenuAction.clearPurchased:
        _clearPurchased();
        return;
    }
  }

  Future<void> _showListActionsSheet() async {
    final selected = await showModalBottomSheet<_ListEditorMenuAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return _ListEditorActionsSheet(
          isReadOnly: _isReadOnly,
          hasReminder: _list.reminder != null,
          hasPurchasedItems: _list.purchasedItemsCount > 0,
          marketOrderingEnabled: _marketModeEnabled,
        );
      },
    );
    if (!mounted || selected == null) {
      return;
    }
    _handleAppBarMenuAction(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Lista não encontrada')),
        body: Center(
          child: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Voltar'),
          ),
        ),
      );
    }

    final visibleItems = _visibleItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          IconButton(
            tooltip: 'Ações da lista',
            onPressed: _showListActionsSheet,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      floatingActionButton: _isReadOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _openItemForm,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Adicionar item'),
            ),
      body: AppGradientScene(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _ListSummaryPanel(
                  list: _list,
                  collapsed: _summaryCollapsed,
                  onBudgetTap: _isReadOnly
                      ? () => _ensureEditable()
                      : _openBudgetEditor,
                  onReminderTap: _isReadOnly
                      ? () => _ensureEditable()
                      : _openReminderEditor,
                  onPaymentBalancesTap: _isReadOnly
                      ? () => _ensureEditable()
                      : _openPaymentBalancesEditor,
                  onReopenTap: _isReadOnly ? _reopenListForEditing : null,
                  onToggleCollapsed: () {
                    setState(() {
                      _summaryCollapsed = !_summaryCollapsed;
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _ItemsToolsBar(
                  controller: _searchController,
                  selectedSort: _sortOption,
                  selectedCategory: _categoryFilter,
                  marketModeEnabled: _marketModeEnabled,
                  visibleCount: visibleItems.length,
                  totalCount: _list.items.length,
                  hasActiveFilters: _hasActiveFilters,
                  onSortChanged: (value) {
                    setState(() {
                      _sortOption = value;
                    });
                  },
                  onCategoryChanged: (value) {
                    setState(() {
                      _categoryFilter = value;
                    });
                  },
                  onClearFilters: _clearFilters,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _list.items.isEmpty
                      ? _EmptyItemsState(onAddPressed: _openItemForm)
                      : visibleItems.isEmpty
                      ? _EmptySearchState(
                          query: _searchQuery,
                          onClearFilters: _clearFilters,
                        )
                      : ListView.separated(
                          key: ValueKey(
                            '${_list.id}-${_sortOption.name}-$_marketModeEnabled-${_categoryFilter?.key ?? 'all'}',
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: visibleItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return _EntryAnimation(
                              key: ValueKey(item.id),
                              delay: Duration(
                                milliseconds: min(160, index * 24),
                              ),
                              child: _ShoppingItemCard(
                                item: item,
                                readOnly: _isReadOnly,
                                onPurchasedChanged: (value) =>
                                    _togglePurchased(item, value),
                                onIncrement: () => _changeQuantity(item, 1),
                                onDecrement: () => _changeQuantity(item, -1),
                                onEdit: () => _openItemForm(existing: item),
                                onViewHistory: () => _showPriceHistory(item),
                                onDelete: () => _deleteItem(item),
                              ),
                            );
                          },
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

class ShoppingMarketModePage extends StatefulWidget {
  const ShoppingMarketModePage({super.key, required this.initialList});

  final ShoppingListModel initialList;

  @override
  State<ShoppingMarketModePage> createState() => _ShoppingMarketModePageState();
}

class _ShoppingMarketModePageState extends State<ShoppingMarketModePage> {
  late ShoppingListModel _list;
  late final TextEditingController _searchController;
  bool _showOnlyPending = true;

  String get _searchQuery => _searchController.text.trim();

  List<ShoppingItem> get _visibleItems {
    final normalizedQuery = normalizeQuery(_searchQuery);
    final filtered = _list.items
        .where((item) {
          final matchesPending = _showOnlyPending ? !item.isPurchased : true;
          final matchesQuery = normalizedQuery.isEmpty
              ? true
              : normalizeQuery(item.name).contains(normalizedQuery);
          return matchesPending && matchesQuery;
        })
        .toList(growable: false);

    filtered.sort((a, b) {
      if (a.isPurchased != b.isPurchased) {
        return a.isPurchased ? 1 : -1;
      }
      final byCategory = a.category.marketOrder.compareTo(
        b.category.marketOrder,
      );
      if (byCategory != 0) {
        return byCategory;
      }
      return normalizeQuery(a.name).compareTo(normalizeQuery(b.name));
    });

    return filtered;
  }

  int get _pendingProductsCount =>
      _list.items.where((item) => !item.isPurchased).length;
  int get _purchasedProductsCount =>
      _list.items.where((item) => item.isPurchased).length;
  int get _pendingUnits => _list.items
      .where((item) => !item.isPurchased)
      .fold<int>(0, (sum, item) => sum + item.quantity);
  double get _pendingValue => _list.items
      .where((item) => !item.isPurchased)
      .fold<double>(0, (sum, item) => sum + item.subtotal);
  double get _completion =>
      _list.items.isEmpty ? 0 : _purchasedProductsCount / _list.items.length;

  @override
  void initState() {
    super.initState();
    _list = widget.initialList.deepCopy();
    _searchController = TextEditingController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _togglePurchased(ShoppingItem item, bool isPurchased) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final updatedItems = [..._list.items];
    updatedItems[index] = item.copyWith(isPurchased: isPurchased);
    setState(() {
      _list = _list.copyWith(items: updatedItems);
    });
  }

  void _changeQuantity(ShoppingItem item, int delta) {
    final index = _list.items.indexWhere((entry) => entry.id == item.id);
    if (index == -1) {
      return;
    }
    final updatedItems = [..._list.items];
    final nextQuantity = max(1, item.quantity + delta);
    updatedItems[index] = item.copyWith(quantity: nextQuantity);
    setState(() {
      _list = _list.copyWith(items: updatedItems);
    });
  }

  void _finishAndReturn() {
    Navigator.pop(context, _list.copyWith(updatedAt: DateTime.now()));
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _finishAndReturn();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _finishAndReturn,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Modo compra'),
          actions: [
            IconButton(
              tooltip: _showOnlyPending
                  ? 'Mostrar todos os itens'
                  : 'Mostrar apenas pendentes',
              onPressed: () {
                setState(() {
                  _showOnlyPending = !_showOnlyPending;
                });
              },
              icon: Icon(
                _showOnlyPending
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
              ),
            ),
            TextButton.icon(
              onPressed: _finishAndReturn,
              icon: const Icon(Icons.check_circle_rounded),
              label: const Text('Concluir'),
            ),
          ],
        ),
        body: AppGradientScene(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _MarketModeSummaryCard(
                    completion: _completion,
                    pendingProductsCount: _pendingProductsCount,
                    purchasedProductsCount: _purchasedProductsCount,
                    pendingUnits: _pendingUnits,
                    pendingValue: _pendingValue,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar item na compra',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _searchController.clear,
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                    ),
                  ),
                ),
                Expanded(
                  child: visibleItems.isEmpty
                      ? _EmptyMarketModeState(
                          showOnlyPending: _showOnlyPending,
                          hasQuery: _searchQuery.isNotEmpty,
                          onShowAllPressed: () {
                            setState(() {
                              _showOnlyPending = false;
                            });
                          },
                          onClearSearch: _searchController.clear,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: visibleItems.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = visibleItems[index];
                            return Dismissible(
                              key: ValueKey('market_${item.id}'),
                              direction: DismissDirection.horizontal,
                              confirmDismiss: (_) async {
                                _togglePurchased(item, !item.isPurchased);
                                return false;
                              },
                              background: _MarketSwipeBackground(
                                icon: item.isPurchased
                                    ? Icons.undo_rounded
                                    : Icons.check_rounded,
                                label: item.isPurchased
                                    ? 'Marcar pendente'
                                    : 'Marcar comprado',
                                alignRight: false,
                              ),
                              secondaryBackground: _MarketSwipeBackground(
                                icon: item.isPurchased
                                    ? Icons.undo_rounded
                                    : Icons.check_rounded,
                                label: item.isPurchased
                                    ? 'Marcar pendente'
                                    : 'Marcar comprado',
                                alignRight: true,
                              ),
                              child: _MarketModeItemCard(
                                item: item,
                                onTogglePurchased: () =>
                                    _togglePurchased(item, !item.isPurchased),
                                onIncrement: () => _changeQuantity(item, 1),
                                onDecrement: () => _changeQuantity(item, -1),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketModeSummaryCard extends StatelessWidget {
  const _MarketModeSummaryCard({
    required this.completion,
    required this.pendingProductsCount,
    required this.purchasedProductsCount,
    required this.pendingUnits,
    required this.pendingValue,
  });

  final double completion;
  final int pendingProductsCount;
  final int purchasedProductsCount;
  final int pendingUnits;
  final double pendingValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final percent = (completion * 100).clamp(0, 100).round();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Roteiro do mercado',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: completion,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PillLabel(
                  icon: Icons.pending_actions_rounded,
                  text: '$pendingProductsCount pendentes',
                ),
                _PillLabel(
                  icon: Icons.check_circle_rounded,
                  text: '$purchasedProductsCount comprados',
                ),
                _PillLabel(
                  icon: Icons.confirmation_number_rounded,
                  text: '$pendingUnits unidades',
                ),
                _PillLabel(
                  icon: Icons.payments_rounded,
                  text: 'Falta ${formatCurrency(pendingValue)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketModeItemCard extends StatelessWidget {
  const _MarketModeItemCard({
    required this.item,
    required this.onTogglePurchased,
    required this.onIncrement,
    required this.onDecrement,
  });

  final ShoppingItem item;
  final VoidCallback onTogglePurchased;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: item.isPurchased ? 0.62 : 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTogglePurchased,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    '${item.quantity}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              decoration: item.isPurchased
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category.label} â€¢ ${formatCurrency(item.unitPrice)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Subtotal: ${formatCurrency(item.subtotal)}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton.filledTonal(
                      onPressed: onIncrement,
                      icon: const Icon(Icons.add_rounded),
                    ),
                    const SizedBox(height: 6),
                    IconButton.filledTonal(
                      onPressed: item.quantity > 1 ? onDecrement : null,
                      icon: const Icon(Icons.remove_rounded),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onTogglePurchased,
                  icon: Icon(
                    item.isPurchased
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: item.isPurchased
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MarketSwipeBackground extends StatelessWidget {
  const _MarketSwipeBackground({
    required this.icon,
    required this.label,
    required this.alignRight,
  });

  final IconData icon;
  final String label;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: colorScheme.primaryContainer.withValues(alpha: 0.75),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (alignRight) Text(label),
          if (alignRight) const SizedBox(width: 8),
          Icon(icon),
          if (!alignRight) const SizedBox(width: 8),
          if (!alignRight) Text(label),
        ],
      ),
    );
  }
}

class _EmptyMarketModeState extends StatelessWidget {
  const _EmptyMarketModeState({
    required this.showOnlyPending,
    required this.hasQuery,
    required this.onShowAllPressed,
    required this.onClearSearch,
  });

  final bool showOnlyPending;
  final bool hasQuery;
  final VoidCallback onShowAllPressed;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final title = hasQuery
        ? 'Nenhum item encontrado'
        : showOnlyPending
        ? 'Tudo comprado'
        : 'Sem itens para mostrar';
    final description = hasQuery
        ? 'Ajuste sua busca para localizar produtos.'
        : showOnlyPending
        ? 'Parabens. Todos os itens estao marcados como comprados.'
        : 'Sua lista esta vazia.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_cart_checkout_rounded,
              size: 78,
              color: colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            if (hasQuery)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close_rounded),
                label: const Text('Limpar busca'),
              )
            else if (showOnlyPending)
              OutlinedButton.icon(
                onPressed: onShowAllPressed,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Mostrar todos'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  const _HomeSummaryCard({
    required this.totalLists,
    required this.totalItems,
    required this.totalValue,
  });

  final int totalLists;
  final int totalItems;
  final double totalValue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Centro de controle',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gerencie listas, acompanhe valores e reutilize compras antigas.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.86),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricTag(
                  icon: Icons.list_alt_rounded,
                  label: 'Listas',
                  value: '$totalLists',
                ),
                _MetricTag(
                  icon: Icons.shopping_basket_rounded,
                  label: 'Produtos',
                  value: '$totalItems',
                ),
                _MetricTag(
                  icon: Icons.attach_money_rounded,
                  label: 'Valor total',
                  value: formatCurrency(totalValue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTag extends StatelessWidget {
  const _MetricTag({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.36),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 6),
            Text('$label: $value'),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ],
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

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatShortDate(list.updatedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PillLabel(
                    icon: Icons.shopping_basket_rounded,
                    text: '${list.totalItems} itens',
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
    );
  }
}

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 5),
            Text(text),
          ],
        ),
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
        padding: const EdgeInsets.all(18),
        child: Text(
          'Nenhuma lista encontrada. Crie a primeira para começar.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
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
            Icon(
              Icons.inventory_2_rounded,
              size: 96,
              color: colorScheme.primary.withValues(alpha: 0.72),
            ),
            const SizedBox(height: 14),
            Text(
              'Você ainda não tem listas',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira lista e acompanhe quantidade e total automaticamente.',
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
    required this.selectionMode,
    required this.isSelected,
    required this.onToggleSelection,
    required this.onLongPress,
    required this.onOpen,
    required this.onReopen,
    required this.onCreateFromThis,
    required this.onDelete,
  });

  final ShoppingListModel list;
  final bool selectionMode;
  final bool isSelected;
  final VoidCallback onToggleSelection;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onReopen;
  final VoidCallback onCreateFromThis;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: selectionMode && isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : null,
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              const SizedBox(height: 10),
              Row(
                children: [
                  _PillLabel(
                    icon: Icons.shopping_basket_rounded,
                    text: '${list.totalItems} itens',
                  ),
                  const SizedBox(width: 8),
                  _PillLabel(
                    icon: Icons.attach_money_rounded,
                    text: formatCurrency(list.totalValue),
                  ),
                  if (list.isClosed) ...[
                    const SizedBox(width: 8),
                    const _PillLabel(icon: Icons.lock_rounded, text: 'Fechada'),
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
                      tooltip: 'Criar baseada nesta',
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
    );
  }
}

class _ListSummaryPanel extends StatelessWidget {
  const _ListSummaryPanel({
    required this.list,
    required this.collapsed,
    required this.onBudgetTap,
    required this.onReminderTap,
    required this.onPaymentBalancesTap,
    required this.onToggleCollapsed,
    this.onReopenTap,
  });

  final ShoppingListModel list;
  final bool collapsed;
  final VoidCallback onBudgetTap;
  final VoidCallback onReminderTap;
  final VoidCallback onPaymentBalancesTap;
  final VoidCallback onToggleCollapsed;
  final VoidCallback? onReopenTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, collapsed ? 12 : 16, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Resumo da lista',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: collapsed ? 'Expandir resumo' : 'Recolher resumo',
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleCollapsed,
                  icon: AnimatedRotation(
                    duration: const Duration(milliseconds: 220),
                    turns: collapsed ? 0 : 0.5,
                    child: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ),
              ],
            ),
            if (list.isClosed) ...[
              const SizedBox(height: 2),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compra fechada. Reabra para editar itens.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (onReopenTap != null)
                        TextButton(
                          onPressed: onReopenTap,
                          child: const Text('Reabrir'),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 260),
              crossFadeState: collapsed
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricTag(
                        icon: Icons.attach_money_rounded,
                        label: 'Total',
                        value: formatCurrency(list.totalValue),
                      ),
                      _MetricTag(
                        icon: Icons.inventory_2_rounded,
                        label: 'Itens',
                        value: '${list.totalItems}',
                      ),
                      _MetricTag(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pend.',
                        value: formatCurrency(list.pendingValue),
                      ),
                      _MetricTag(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Orçamento',
                        value: list.hasBudget
                            ? formatCurrency(list.budget!)
                            : 'Não definido',
                        onTap: onBudgetTap,
                      ),
                      _MetricTag(
                        icon: Icons.payments_rounded,
                        label: 'Saldos',
                        value: list.hasPaymentBalances
                            ? formatCurrency(list.paymentBalancesTotal)
                            : 'Não definido',
                        onTap: onPaymentBalancesTap,
                      ),
                      _MetricTag(
                        icon: list.reminder == null
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        label: 'Lembrete',
                        value: list.reminder == null
                            ? 'Desligado'
                            : formatDateTime(list.reminder!.scheduledAt),
                        onTap: onReminderTap,
                      ),
                    ],
                  ),
                  if (list.isOverBudget) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Acima do orçamento: ${formatCurrency(list.overBudgetAmount)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    'Valor, quantidade e status atualizados em tempo real.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.86,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetricTag(
                        icon: Icons.attach_money_rounded,
                        label: 'Total',
                        value: formatCurrency(list.totalValue),
                      ),
                      _MetricTag(
                        icon: Icons.inventory_2_rounded,
                        label: 'Itens',
                        value: '${list.totalItems}',
                      ),
                      _MetricTag(
                        icon: Icons.pending_actions_rounded,
                        label: 'Pendentes',
                        value: formatCurrency(list.pendingValue),
                      ),
                      _MetricTag(
                        icon: Icons.check_circle_rounded,
                        label: 'Comprados',
                        value: '${list.purchasedItemsCount}',
                      ),
                      _MetricTag(
                        icon: Icons.account_balance_wallet_rounded,
                        label: 'Orçamento',
                        value: list.hasBudget
                            ? formatCurrency(list.budget!)
                            : 'Não definido',
                        onTap: onBudgetTap,
                      ),
                      _MetricTag(
                        icon: Icons.payments_rounded,
                        label: 'Saldos',
                        value: list.hasPaymentBalances
                            ? formatCurrency(list.paymentBalancesTotal)
                            : 'Não definido',
                        onTap: onPaymentBalancesTap,
                      ),
                      _MetricTag(
                        icon: list.reminder == null
                            ? Icons.notifications_off_rounded
                            : Icons.notifications_active_rounded,
                        label: 'Lembrete',
                        value: list.reminder == null
                            ? 'Desligado'
                            : formatDateTime(list.reminder!.scheduledAt),
                        onTap: onReminderTap,
                      ),
                      if (list.hasBudget)
                        _MetricTag(
                          icon: list.isOverBudget
                              ? Icons.warning_amber_rounded
                              : Icons.savings_rounded,
                          label: list.isOverBudget ? 'Excesso' : 'Saldo',
                          value: list.isOverBudget
                              ? formatCurrency(list.overBudgetAmount)
                              : formatCurrency(list.budgetRemaining),
                        ),
                      if (list.hasPaymentBalances)
                        _MetricTag(
                          icon: list.uncoveredAmount > 0
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_rounded,
                          label: list.uncoveredAmount > 0
                              ? 'Falta pagar'
                              : 'Coberto',
                          value: list.uncoveredAmount > 0
                              ? formatCurrency(list.uncoveredAmount)
                              : formatCurrency(list.coveredAmount),
                        ),
                    ],
                  ),
                  if (list.hasPaymentBalances) ...[
                    const SizedBox(height: 12),
                    _PaymentBalancesUsagePanel(list: list),
                  ],
                  if (list.isOverBudget) ...[
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.85,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Valor total acima do orçamento por ${formatCurrency(list.overBudgetAmount)}.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentBalancesUsagePanel extends StatelessWidget {
  const _PaymentBalancesUsagePanel({required this.list});

  final ShoppingListModel list;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final entries = list.paymentUsage
        .where((entry) => entry.balance.value > 0)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surface.withValues(alpha: 0.68),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Consumo por prioridade',
              style: textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...entries.map((entry) {
              final progress = entry.balance.value <= 0
                  ? 0.0
                  : (entry.consumed / entry.balance.value)
                        .clamp(0.0, 1.0)
                        .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${entry.balance.name} (${entry.balance.type.label})',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${formatCurrency(entry.consumed)} / ${formatCurrency(entry.balance.value)}',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.isExhausted
                          ? 'Saldo esgotado.'
                          : 'Restante: ${formatCurrency(entry.remaining)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: entry.isExhausted
                            ? colorScheme.error
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (list.uncoveredAmount > 0)
              Text(
                'Total sem cobertura de saldo: ${formatCurrency(list.uncoveredAmount)}',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemsToolsBar extends StatelessWidget {
  const _ItemsToolsBar({
    required this.controller,
    required this.selectedSort,
    required this.selectedCategory,
    required this.marketModeEnabled,
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
    required this.onSortChanged,
    required this.onCategoryChanged,
    required this.onClearFilters,
  });

  final TextEditingController controller;
  final ItemSortOption selectedSort;
  final ShoppingCategory? selectedCategory;
  final bool marketModeEnabled;
  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;
  final ValueChanged<ItemSortOption> onSortChanged;
  final ValueChanged<ShoppingCategory?> onCategoryChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Buscar produto',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: controller.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: controller.clear,
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<ItemSortOption>(
              tooltip: 'Ordenar itens',
              onSelected: onSortChanged,
              itemBuilder: (context) {
                return [
                  for (final option in ItemSortOption.values)
                    CheckedPopupMenuItem<ItemSortOption>(
                      value: option,
                      checked: option == selectedSort,
                      child: Text(option.label),
                    ),
                ];
              },
              child: _SortTag(option: selectedSort),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryFilterChip(
                    selectedCategory: selectedCategory,
                    onSelected: onCategoryChanged,
                  ),
                  if (marketModeEnabled)
                    Chip(
                      avatar: const Icon(Icons.storefront_rounded, size: 18),
                      label: const Text('Modo mercado ativo'),
                      backgroundColor: colorScheme.primaryContainer.withValues(
                        alpha: 0.85,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('$visibleCount de $totalCount item(ns)'),
            const Spacer(),
            if (hasActiveFilters)
              TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: const Text('Limpar'),
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.selectedCategory,
    required this.onSelected,
  });

  final ShoppingCategory? selectedCategory;
  final ValueChanged<ShoppingCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ShoppingCategory?>(
      tooltip: 'Filtrar categoria',
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          CheckedPopupMenuItem<ShoppingCategory?>(
            value: null,
            checked: selectedCategory == null,
            child: const Text('Todas as categorias'),
          ),
          ...ShoppingCategory.values.map(
            (category) => CheckedPopupMenuItem<ShoppingCategory?>(
              value: category,
              checked: selectedCategory == category,
              child: Row(
                children: [
                  Icon(category.icon, size: 18),
                  const SizedBox(width: 8),
                  Text(category.label),
                ],
              ),
            ),
          ),
        ];
      },
      child: Chip(
        avatar: Icon(
          selectedCategory?.icon ?? Icons.category_rounded,
          size: 18,
        ),
        label: Text(
          selectedCategory == null
              ? 'Categoria: todas'
              : 'Categoria: ${selectedCategory!.label}',
        ),
      ),
    );
  }
}

class _SortTag extends StatelessWidget {
  const _SortTag({required this.option});

  final ItemSortOption option;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(option.icon, size: 18),
            const SizedBox(width: 6),
            Text(option.shortLabel),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItemCard extends StatelessWidget {
  const _ShoppingItemCard({
    required this.item,
    this.readOnly = false,
    required this.onPurchasedChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onViewHistory,
    required this.onDelete,
  });

  final ShoppingItem item;
  final bool readOnly;
  final ValueChanged<bool?> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPurchased = item.isPurchased;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPurchased
                ? [
                    colorScheme.primaryContainer.withValues(alpha: 0.45),
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                  ]
                : [
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow.withValues(alpha: 0.45),
                  ],
          ),
          border: Border.all(
            color: isPurchased
                ? colorScheme.primary.withValues(alpha: 0.45)
                : colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        style: textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          decoration: isPurchased
                              ? TextDecoration.lineThrough
                              : null,
                          color: colorScheme.onSurface,
                        ),
                        child: Text(item.name),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Subtotal: ${formatCurrency(item.subtotal)}',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: Icon(item.category.icon, size: 17),
                            label: Text(item.category.label),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.65),
                          ),
                          if (item.barcode != null && item.barcode!.isNotEmpty)
                            Chip(
                              avatar: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 17,
                              ),
                              label: Text(item.barcode!),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colorScheme.surfaceContainerHigh
                                  .withValues(alpha: 0.72),
                            ),
                          if (item.priceHistory.length > 1)
                            Chip(
                              avatar: const Icon(
                                Icons.show_chart_rounded,
                                size: 17,
                              ),
                              label: Text('${item.priceHistory.length} preços'),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: colorScheme.secondaryContainer
                                  .withValues(alpha: 0.7),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isPurchased ? 1.05 : 1,
                  child: Checkbox(
                    value: isPurchased,
                    onChanged: readOnly ? null : onPurchasedChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Editar',
                  onPressed: readOnly ? null : onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
                IconButton(
                  tooltip: 'Histórico de preço',
                  onPressed: onViewHistory,
                  icon: const Icon(Icons.query_stats_rounded),
                ),
                IconButton(
                  tooltip: 'Excluir',
                  onPressed: readOnly ? null : onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  onPressed: readOnly
                      ? null
                      : (item.quantity > 1 ? onDecrement : null),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${item.quantity}',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: readOnly ? null : onIncrement,
                  icon: const Icon(Icons.add_rounded),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: isPurchased
                      ? Chip(
                          key: const ValueKey('purchased-chip'),
                          avatar: const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                          ),
                          label: const Text('Comprado'),
                          backgroundColor: colorScheme.primaryContainer,
                        )
                      : Chip(
                          key: const ValueKey('pending-chip'),
                          avatar: const Icon(Icons.timelapse_rounded, size: 18),
                          label: const Text('Pendente'),
                          backgroundColor: colorScheme.surfaceContainerHigh,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceHistorySheet extends StatelessWidget {
  const _PriceHistorySheet({required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final history = [...item.priceHistory]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
      children: [
        Text(
          'Histórico de preço',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          item.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (history.isEmpty)
          const ListTile(title: Text('Sem histórico registrado ainda.'))
        else
          ...history.asMap().entries.map((entry) {
            final index = entry.key;
            final record = entry.value;
            final previous = index + 1 < history.length
                ? history[index + 1]
                : null;
            final delta = previous == null
                ? null
                : record.price - previous.price;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.monetization_on_rounded),
                title: Text(formatCurrency(record.price)),
                subtitle: Text(formatDateTime(record.recordedAt)),
                trailing: delta == null
                    ? const Text('Inicial')
                    : Text(
                        '${delta >= 0 ? '+' : '-'} ${formatCurrency(delta.abs())}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: delta > 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
              ),
            );
          }),
      ],
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({required this.query, required this.onClearFilters});

  final String query;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      key: const ValueKey('empty-search-results'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max(0, constraints.maxHeight - 48),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 80,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nenhum produto encontrado',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nenhum item corresponde a "$query".',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('Limpar filtros'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyItemsState extends StatelessWidget {
  const _EmptyItemsState({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      key: const ValueKey('empty-items'),
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: max(0, constraints.maxHeight - 52),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(scale: value, child: child);
                  },
                  child: Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 92,
                    color: colorScheme.primary.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Esta lista esta vazia',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Adicione o primeiro produto e acompanhe subtotal e total automaticos.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAddPressed,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar produto'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntryAnimation extends StatefulWidget {
  const _EntryAnimation({super.key, required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_EntryAnimation> createState() => _EntryAnimationState();
}

class _EntryAnimationState extends State<_EntryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(_fade);

    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
