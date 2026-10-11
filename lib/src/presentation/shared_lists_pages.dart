import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/finance_integration_dependencies.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'shared_lists/shared_list_editor_models.dart';
import 'shared_lists/widgets/shared_history_sheet.dart';
import 'shared_lists/widgets/shared_items_widgets.dart';
import 'shared_lists/widgets/shared_summary_widgets.dart';
import 'theme/editorial_workspace_theme.dart';
import 'shared_lists/widgets/shared_editorial_summary.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

Future<void> showSharedInviteSheet({
  required BuildContext context,
  required SharedListsRepository repository,
  required String listId,
  required String currentUid,
  Future<void> Function()? onOpenSharedList,
}) async {
  await showAppModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _SharedInviteSheet(
      repository: repository,
      listId: listId,
      currentUid: currentUid,
      onOpenSharedList: onOpenSharedList,
    ),
  );
}

bool _prefersReducedMotion(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

Duration _adaptiveMotionDuration(BuildContext context, Duration fallback) =>
    _prefersReducedMotion(context) ? Duration.zero : fallback;

class _SharedEditorLoadingScaffold extends StatelessWidget {
  const _SharedEditorLoadingScaffold();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lista compartilhada')),
    body: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Carregando lista compartilhada...'),
        ],
      ),
    ),
  );
}

class _SharedInviteSheet extends StatefulWidget {
  const _SharedInviteSheet({
    required this.repository,
    required this.listId,
    required this.currentUid,
    this.onOpenSharedList,
  });

  final SharedListsRepository repository;
  final String listId;
  final String currentUid;
  final Future<void> Function()? onOpenSharedList;

  @override
  State<_SharedInviteSheet> createState() => _SharedInviteSheetState();
}

class _SharedInviteSheetState extends State<_SharedInviteSheet> {
  bool _busy = false;

  void _log(String message) {
    debugPrint('[share_flow] $message');
    developer.log(message, name: 'share_flow');
  }

  void _showSnack(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    AppToast.show(context, message: message, type: type, duration: duration);
  }

  Future<void> _generateInviteCode(SharedShoppingListSummary list) async {
    setState(() => _busy = true);
    try {
      _log('invite generation started');
      await widget.repository.generateInviteCode(
        listId: list.id,
        requesterUid: widget.currentUid,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack('Novo código gerado.', type: AppToastType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('invite generation failed kind=${error.runtimeType}');
      _showSnack(
        'Não foi possível gerar o código. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _revokeInviteCode(SharedShoppingListSummary list) async {
    setState(() => _busy = true);
    try {
      _log('invite revocation started');
      await widget.repository.revokeInviteCode(
        listId: list.id,
        requesterUid: widget.currentUid,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack('Código revogado.', type: AppToastType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('invite revocation failed kind=${error.runtimeType}');
      _showSnack(
        'Não foi possível revogar o código. Tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copyInviteCode(String code) async {
    if (code.trim().isEmpty) {
      _showSnack('Nenhum código ativo.', type: AppToastType.warning);
      return;
    }
    await Clipboard.setData(ClipboardData(text: code.trim()));
    if (!mounted) {
      return;
    }
    _log('invite code copied code=$code');
    HapticFeedback.selectionClick();
    _showSnack('Código copiado.', type: AppToastType.success);
  }

  Future<void> _removeMember({
    required SharedShoppingListSummary list,
    required String memberUid,
  }) async {
    final isOwner = list.isOwner(widget.currentUid);
    if (!isOwner) {
      _showSnack(
        'Apenas o dono pode remover membros.',
        type: AppToastType.warning,
      );
      return;
    }
    if (memberUid == list.ownerUid) {
      _showSnack(
        'O dono da lista não pode ser removido.',
        type: AppToastType.warning,
      );
      return;
    }
    final confirm = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => Theme(
        data: editorialWorkspaceTheme(Theme.of(dialogContext)),
        child: AlertDialog(
          title: const Text('Remover membro'),
          content: const Text(
            'Tem certeza que deseja remover este membro da lista compartilhada?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remover'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirm != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      _log('member removal started');
      await widget.repository.removeMember(
        listId: list.id,
        requesterUid: widget.currentUid,
        memberUid: memberUid,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack('Membro removido.', type: AppToastType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('member removal failed kind=${error.runtimeType}');
      _showSnack(
        'Não foi possível remover o membro. Tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openSharedList() async {
    if (widget.onOpenSharedList == null) {
      return;
    }
    Navigator.pop(context);
    await Future<void>.delayed(
      Duration.zero,
      () => widget.onOpenSharedList?.call(),
    );
  }

  List<String> _sortedMembers(SharedShoppingListSummary list) {
    final members = list.memberUids.toSet().toList();
    members.sort((a, b) {
      if (a == list.ownerUid) {
        return -1;
      }
      if (b == list.ownerUid) {
        return 1;
      }
      return a.compareTo(b);
    });
    return members;
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: editorialWorkspaceTheme(Theme.of(context)),
    child: Builder(builder: _buildSheet),
  );

  Widget _buildSheet(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .94,
      child: Material(
        color: colors.surface,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colors.outlineVariant),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Voltar',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, size: 22),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Convidar para lista',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<SharedShoppingListSummary?>(
                  stream: widget.repository.watchSharedList(widget.listId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Não foi possível carregar o compartilhamento. Feche e tente novamente.',
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Carregando compartilhamento...'),
                          ],
                        ),
                      );
                    }
                    final list = snapshot.data;
                    if (list == null) {
                      return const Center(
                        child: Text('Lista compartilhada não encontrada.'),
                      );
                    }
                    final isOwner =
                        widget.currentUid.isNotEmpty &&
                        list.isOwner(widget.currentUid);
                    final inviteCode = list.inviteCode?.trim() ?? '';
                    final hasInvite = inviteCode.isNotEmpty;
                    final members = _sortedMembers(list);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionLabel(
                                  context,
                                  'Código da lista compartilhada',
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerLowest,
                                    border: Border.all(
                                      color: colors.outlineVariant,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              colors.brightness ==
                                                  Brightness.light
                                              ? const Color(0xFFF6FBF2)
                                              : colors.surfaceContainerLow,
                                          border: Border.all(
                                            color: colors.outlineVariant,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: SelectableText(
                                          hasInvite
                                              ? inviteCode
                                              : 'Nenhum código ativo',
                                          textAlign: TextAlign.center,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontFamily: 'MercadoPublicSans',
                                                fontWeight: FontWeight.w600,
                                                fontSize: hasInvite ? 22 : 16,
                                                letterSpacing: hasInvite
                                                    ? 2
                                                    : 0,
                                                color: colors.primary,
                                              ),
                                        ),
                                      ),
                                      if (hasInvite) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.circle,
                                              size: 6,
                                              color: colors.primary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Ativo',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color: colors.primary,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        Divider(
                                          height: 1,
                                          color: colors.outlineVariant,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _codeAction(
                                                context,
                                                label: 'Copiar',
                                                icon: Icons.content_copy,
                                                onPressed: _busy
                                                    ? null
                                                    : () => _copyInviteCode(
                                                        inviteCode,
                                                      ),
                                              ),
                                            ),
                                            if (isOwner) ...[
                                              Expanded(
                                                child: _codeAction(
                                                  context,
                                                  label: 'Regenerar',
                                                  icon: Icons.refresh,
                                                  onPressed: _busy
                                                      ? null
                                                      : () =>
                                                            _generateInviteCode(
                                                              list,
                                                            ),
                                                ),
                                              ),
                                              Expanded(
                                                child: _codeAction(
                                                  context,
                                                  label: 'Revogar',
                                                  icon: Icons.link_off,
                                                  destructive: true,
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _revokeInviteCode(
                                                          list,
                                                        ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (!hasInvite && isOwner) ...[
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _generateInviteCode(list),
                                    child: const Text('Gerar código'),
                                  ),
                                ],
                                if (!isOwner) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Somente o dono pode gerenciar o código.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                if (_busy) ...[
                                  const SizedBox(height: 12),
                                  const LinearProgressIndicator(minHeight: 2),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Atualizando compartilhamento...',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 28),
                                _sectionLabel(context, 'Membros da lista'),
                                const SizedBox(height: 8),
                                for (final uid in members)
                                  _memberRow(
                                    context,
                                    list: list,
                                    uid: uid,
                                    isOwner: isOwner,
                                  ),
                                if (members.isNotEmpty)
                                  Divider(
                                    height: 1,
                                    color: colors.outlineVariant,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.onOpenSharedList != null)
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: colors.outlineVariant),
                              ),
                            ),
                            child: FilledButton(
                              onPressed: _busy ? null : _openSharedList,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: const Text('Abrir lista compartilhada'),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .8,
    ),
  );

  Widget _codeAction(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool destructive = false,
  }) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 64),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: onPressed == null
              ? Theme.of(context).disabledColor
              : destructive
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11),
        ),
      ],
    ),
  );

  Widget _memberRow(
    BuildContext context, {
    required SharedShoppingListSummary list,
    required String uid,
    required bool isOwner,
  }) {
    final theme = Theme.of(context);
    final owner = uid == list.ownerUid;
    final current = uid == widget.currentUid;
    final shortUid = uid.length <= 6
        ? uid
        : '...${uid.substring(uid.length - 6)}';
    final label = current
        ? (owner ? 'Você (dono)' : 'Você (membro)')
        : owner
        ? 'Dono'
        : 'Membro';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text('uid: $shortUid', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (isOwner && !owner)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => _removeMember(list: list, memberUid: uid),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Remover membro'),
            ),
        ],
      ),
    );
  }
}

class SharedListEditorPage extends StatefulWidget {
  const SharedListEditorPage({
    super.key,
    required this.repository,
    required this.store,
    required this.listId,
    this.currentUidProvider,
  });

  final SharedListsRepository repository;
  final ShoppingListsStore store;
  final String listId;
  final String Function()? currentUidProvider;

  @override
  State<SharedListEditorPage> createState() => _SharedListEditorPageState();
}

enum _SharedHeaderSection { summary, budget, balances, reminder }

class _SharedCatalogImportPromptResult {
  const _SharedCatalogImportPromptResult({
    required this.enableImport,
    required this.enableForFutureLists,
  });

  final bool enableImport;
  final bool enableForFutureLists;
}

class _SharedListEditorPageState extends State<SharedListEditorPage> {
  late final TextEditingController _searchController;
  bool _busy = false;
  bool _isHeaderExpanded = false;
  bool _didShowBudgetWarning = false;
  bool _didShowBudgetNearLimitWarning = false;
  String? _lastReminderFingerprint;
  String? _lastLocalMirrorFingerprint;
  final Set<String> _catalogImportPromptedListIds = <String>{};
  final Set<String> _catalogImportPromptInFlightListIds = <String>{};
  final Map<String, String> _catalogImportFingerprints = <String, String>{};
  _SharedHeaderSection? _expandedHeaderSection;
  SharedItemsFilter _itemsFilter = SharedItemsFilter.pending;

  String get _currentUid =>
      widget.currentUidProvider?.call().trim() ??
      FirebaseAuth.instance.currentUser?.uid.trim() ??
      '';
  String get _searchQuery => _searchController.text.trim();

  void _log(String message) {
    debugPrint('[shared_lists_ui] $message');
    developer.log(message, name: 'shared_lists_ui');
  }

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

  void _showSnack(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(seconds: 4),
  }) {
    AppToast.show(context, message: message, type: type, duration: duration);
  }

  String _sharedCatalogImportFingerprint(
    SharedShoppingListSummary list,
    List<SharedShoppingItem> items,
  ) {
    final itemParts =
        items
            .map(
              (item) => '${item.id}:${item.updatedAt.millisecondsSinceEpoch}',
            )
            .toList(growable: false)
          ..sort();
    return [
      list.id,
      list.updatedAt.millisecondsSinceEpoch,
      items.length,
      ...itemParts,
    ].join('|');
  }

  String _buildCatalogImportMessage(SharedCatalogImportResult report) {
    if (report.changedCount == 0) {
      return 'Seu catálogo já está atualizado com esta lista.';
    }
    if (report.createdCount > 0 && report.mergedCount > 0) {
      return 'Catálogo atualizado: ${report.createdCount} novos e ${report.mergedCount} mesclados.';
    }
    if (report.createdCount > 0) {
      return 'Catálogo atualizado: ${report.createdCount} novos produtos.';
    }
    return 'Catálogo atualizado: ${report.mergedCount} produtos mesclados.';
  }

  Future<void> _importSharedItemsToCatalog(
    SharedShoppingListSummary list,
    ShoppingListModel listModel, {
    required bool showSnack,
    bool force = false,
  }) async {
    if (listModel.items.isEmpty) {
      if (showSnack) {
        _showSnack('Esta lista ainda não tem produtos para importar.');
      }
      return;
    }
    final fingerprint = [
      list.updatedAt.millisecondsSinceEpoch,
      listModel.items.length,
      listModel.totalValue.toStringAsFixed(2),
      listModel.items
          .map((item) => '${item.id}:${item.name}:${item.barcode ?? ''}')
          .join('|'),
    ].join('|');
    if (!force && _catalogImportFingerprints[list.id] == fingerprint) {
      return;
    }
    _catalogImportFingerprints[list.id] = fingerprint;
    final report = await widget.store.importSharedListItemsToCatalog(listModel);
    if (!mounted || !showSnack) {
      return;
    }
    _showSnack(
      _buildCatalogImportMessage(report),
      type: report.changedCount > 0 ? AppToastType.success : AppToastType.info,
    );
  }

  Future<_SharedCatalogImportPromptResult?> _showCatalogImportPrompt(
    SharedShoppingListSummary list,
  ) {
    var enableForFutureLists = widget.store.autoImportAllSharedCatalogs;
    return showAppDialog<_SharedCatalogImportPromptResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Adicionar produtos ao seu catálogo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Os produtos de "${list.name}" entram nas suas sugestões, no scanner e nas próximas compras. Duplicados serão mesclados por código de barras e nome.',
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: enableForFutureLists,
                    onChanged: (value) {
                      setDialogState(() {
                        enableForFutureLists = value ?? false;
                      });
                    },
                    title: const Text(
                      'Fazer isso automaticamente para novas listas compartilhadas',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(
                    context,
                    const _SharedCatalogImportPromptResult(
                      enableImport: false,
                      enableForFutureLists: false,
                    ),
                  ),
                  child: const Text('Agora não'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _SharedCatalogImportPromptResult(
                      enableImport: true,
                      enableForFutureLists: enableForFutureLists,
                    ),
                  ),
                  child: const Text('Adicionar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _enableSharedCatalogImport(
    SharedShoppingListSummary list,
    ShoppingListModel listModel, {
    bool askForFutureLists = true,
  }) async {
    final result = askForFutureLists
        ? await _showCatalogImportPrompt(list)
        : const _SharedCatalogImportPromptResult(
            enableImport: true,
            enableForFutureLists: false,
          );
    if (result == null) {
      return true;
    }
    if (!mounted) {
      return true;
    }
    if (!result.enableImport) {
      return true;
    }
    await widget.store.setSharedCatalogImportEnabled(
      list.id,
      enabled: true,
      enableForFutureLists: result.enableForFutureLists,
    );
    await _importSharedItemsToCatalog(
      list,
      listModel,
      showSnack: true,
      force: true,
    );
    return true;
  }

  Future<void> _promptSharedCatalogImport(
    SharedShoppingListSummary list,
    ShoppingListModel listModel,
    List<SharedShoppingItem> items,
  ) async {
    final fingerprint = _sharedCatalogImportFingerprint(list, items);
    final promptKey = '${list.id}|$fingerprint';
    if (_catalogImportPromptedListIds.contains(promptKey) ||
        _catalogImportPromptInFlightListIds.contains(promptKey)) {
      return;
    }

    _catalogImportPromptInFlightListIds.add(promptKey);
    try {
      await Future<void>.delayed(
        _adaptiveMotionDuration(context, const Duration(milliseconds: 450)),
      );
      if (!mounted) {
        return;
      }
      if (ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final promptResolved = await _enableSharedCatalogImport(list, listModel);
      if (promptResolved) {
        _catalogImportPromptedListIds.add(promptKey);
      }
    } finally {
      _catalogImportPromptInFlightListIds.remove(promptKey);
    }
  }

  void _maybeHandleSharedCatalogImport(
    SharedShoppingListSummary list,
    ShoppingListModel listModel,
    List<SharedShoppingItem> items,
  ) {
    if (_currentUid.isEmpty || items.isEmpty) {
      return;
    }
    if (widget.store.isSharedCatalogImportEnabled(list.id)) {
      unawaited(_importSharedItemsToCatalog(list, listModel, showSnack: false));
      return;
    }
    if (list.isOwner(_currentUid)) {
      if (widget.store.autoImportOwnedSharedCatalogs) {
        unawaited(
          _importSharedItemsToCatalog(list, listModel, showSnack: false),
        );
      }
      return;
    }
    unawaited(_promptSharedCatalogImport(list, listModel, items));
  }

  bool _ensureEditable(SharedShoppingListSummary list) {
    if (!list.isClosed) {
      return true;
    }
    _showSnack(
      'Lista fechada. Reabra para editar.',
      type: AppToastType.warning,
    );
    return false;
  }

  ShoppingListModel _toShoppingListModel(
    SharedShoppingListSummary list,
    List<SharedShoppingItem> items,
  ) {
    return ShoppingListModel(
      id: list.id,
      name: list.name,
      createdAt: list.createdAt,
      updatedAt: list.updatedAt,
      items: items
          .map((entry) => entry.toShoppingItem())
          .toList(growable: false),
      budget: list.budget,
      reminder: list.reminder,
      paymentBalances: list.paymentBalances,
      isClosed: list.isClosed,
      closedAt: list.closedAt,
    );
  }

  void _toggleHeaderSection(_SharedHeaderSection section) {
    HapticFeedback.selectionClick();
    setState(() {
      _expandedHeaderSection = _expandedHeaderSection == section
          ? null
          : section;
    });
  }

  void _toggleHeaderExpanded() {
    HapticFeedback.selectionClick();
    setState(() {
      _isHeaderExpanded = !_isHeaderExpanded;
    });
  }

  void _setItemsFilter(SharedItemsFilter filter) {
    if (_itemsFilter == filter) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _itemsFilter = filter;
    });
  }

  List<SharedShoppingItem> _applyItemsFilter(List<SharedShoppingItem> items) {
    final filteredItems = items
        .where((item) {
          return switch (_itemsFilter) {
            SharedItemsFilter.pending => !item.isPurchased,
            SharedItemsFilter.all => true,
            SharedItemsFilter.purchased => item.isPurchased,
          };
        })
        .toList(growable: false);

    final sortedItems = filteredItems.toList(growable: false)
      ..sort((left, right) {
        if (left.isPurchased != right.isPurchased) {
          return left.isPurchased ? 1 : -1;
        }
        return normalizeQuery(left.name).compareTo(normalizeQuery(right.name));
      });
    return sortedItems;
  }

  void _maybeWarnBudget(ShoppingListModel list) {
    if (list.hasBudget) {
      final budget = list.budget ?? 0;
      if (budget > 0) {
        final usageRatio = (list.totalValue / budget).clamp(0.0, 1.5);
        final isNearLimit = usageRatio >= 0.85 && usageRatio < 1.0;
        if (isNearLimit && !_didShowBudgetNearLimitWarning) {
          _didShowBudgetNearLimitWarning = true;
          _showSnack(
            'Orçamento em 85% ou mais. Restante: ${formatCurrency(list.budgetRemaining)}.',
          );
          unawaited(
            widget.store.notifyBudgetNearLimit(
              list,
              budgetUsageRatio: usageRatio,
            ),
          );
        } else if (usageRatio < 0.8) {
          _didShowBudgetNearLimitWarning = false;
        }
      }
    } else {
      _didShowBudgetNearLimitWarning = false;
    }

    if (list.isOverBudget && !_didShowBudgetWarning) {
      _didShowBudgetWarning = true;
      _showSnack(
        'Orçamento excedido em ${formatCurrency(list.overBudgetAmount)}.',
      );
      return;
    }

    if (!list.isOverBudget) {
      _didShowBudgetWarning = false;
    }
  }

  void _syncReminderIfNeeded(ShoppingListModel list) {
    final reminder = list.reminder?.scheduledAt;
    final fingerprint = [
      list.id,
      list.isClosed,
      reminder?.toIso8601String() ?? 'none',
    ].join('|');
    if (fingerprint == _lastReminderFingerprint) {
      return;
    }
    _lastReminderFingerprint = fingerprint;
    unawaited(widget.store.syncExternalReminder(list));
  }

  void _mirrorToLocalIfNeeded(
    SharedShoppingListSummary list,
    ShoppingListModel listModel,
  ) {
    final uid = _currentUid;
    if (uid.isEmpty || !list.isOwner(uid)) {
      return;
    }
    final sourceId = list.sourceLocalListId?.trim() ?? '';
    if (sourceId.isEmpty) {
      return;
    }
    final fingerprint = [
      list.updatedAt.millisecondsSinceEpoch,
      listModel.items.length,
      listModel.totalValue.toStringAsFixed(2),
      listModel.purchasedItemsCount,
      listModel.isClosed,
    ].join('|');
    if (_lastLocalMirrorFingerprint == fingerprint) {
      return;
    }
    _lastLocalMirrorFingerprint = fingerprint;
    final existing = widget.store.findById(sourceId);
    final mirrored = listModel.copyWith(
      id: sourceId,
      createdAt: existing?.createdAt ?? listModel.createdAt,
    );
    _log('shared list mirror started');
    unawaited(
      widget.store.upsertList(
        mirrored,
        ingestCatalog: widget.store.autoImportOwnedSharedCatalogs,
      ),
    );
  }

  Future<void> _openBudgetEditor(SharedShoppingListSummary list) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final result = await showBudgetEditorDialog(
      context,
      initialValue: list.budget,
      initialPaymentBalances: list.paymentBalances,
      financeRepository: createFinanceIntegrationRepository(),
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.clear) {
      await widget.repository.updateListMeta(
        listId: list.id,
        clearBudget: true,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Orçamento removido.');
      return;
    }

    final value = result.value;
    if (value == null || value <= 0) {
      return;
    }
    await widget.repository.updateListMeta(
      listId: list.id,
      budget: value,
      paymentBalances: result.paymentBalances,
    );
    if (!mounted) {
      return;
    }
    _showSnack('Orçamento atualizado.');
  }

  Future<void> _openReminderEditor(SharedShoppingListSummary list) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final result = await showReminderEditorDialog(
      context,
      initialValue: list.reminder,
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.clear || result.value == null) {
      await widget.repository.updateListMeta(
        listId: list.id,
        clearReminder: true,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Lembrete removido.');
      return;
    }

    final reminder = result.value!;
    await widget.repository.updateListMeta(listId: list.id, reminder: reminder);
    if (!mounted) {
      return;
    }
    _showSnack('Lembrete atualizado.');
  }

  Future<void> _openPaymentBalancesEditor(
    SharedShoppingListSummary list,
  ) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final previousBalancesTotal = list.paymentBalancesTotal;
    final previousBudget = list.budget;
    final result = await showPaymentBalancesEditorDialog(
      context,
      initialValues: list.paymentBalances,
      financeRepository: createFinanceIntegrationRepository(),
    );
    if (!mounted || result == null) {
      return;
    }

    if (result.clear || (result.value?.isEmpty ?? true)) {
      await widget.repository.updateListMeta(
        listId: list.id,
        clearPaymentBalances: true,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Saldos removidos.');
      return;
    }

    final updatedBalances = result.value ?? const <PaymentBalance>[];
    final updatedBalancesTotal = updatedBalances.fold<double>(
      0,
      (sum, entry) => sum + entry.value,
    );
    final delta = updatedBalancesTotal - previousBalancesTotal;
    final double nextBudget = previousBudget == null
        ? updatedBalancesTotal
        : max<double>(0, previousBudget + delta);

    await widget.repository.updateListMeta(
      listId: list.id,
      paymentBalances: updatedBalances,
      budget: nextBudget,
    );
    if (!mounted) {
      return;
    }
    _showSnack(
      'Saldos atualizados. Orçamento ajustado para ${formatCurrency(nextBudget)}.',
    );
  }

  Future<void> _finalizeSharedList(
    SharedShoppingListSummary list,
    List<SharedShoppingItem> items,
  ) async {
    if (list.isClosed) {
      _showSnack('A lista já está fechada.');
      return;
    }
    if (items.isEmpty) {
      _showSnack('Adicione itens antes de fechar a compra.');
      return;
    }
    final checkout = await showPurchaseCheckoutDialog(
      context,
      list: _toShoppingListModel(list, items),
    );
    if (!mounted || checkout == null) {
      return;
    }
    final uid = _currentUid;
    if (uid.isEmpty) {
      _showSnack('Faça login para fechar a lista.');
      return;
    }
    setState(() => _busy = true);
    try {
      final originalById = {for (final item in items) item.id: item};
      for (final corrected in checkout.reviewedItems) {
        final original = originalById[corrected.id];
        if (original == null ||
            (original.quantity == corrected.quantity &&
                original.unitPrice == corrected.unitPrice &&
                original.isPurchased == corrected.isPurchased)) {
          continue;
        }
        await widget.repository.upsertItem(
          listId: list.id,
          updatedBy: uid,
          item: original.copyWith(
            quantity: corrected.quantity,
            unitPrice: corrected.unitPrice,
            isPurchased: corrected.isPurchased,
            updatedBy: uid,
            updatedAt: DateTime.now(),
          ),
        );
      }
      await widget.repository.finalizeSharedList(
        listId: list.id,
        updatedBy: uid,
        markPendingAsPurchased: checkout.markPendingAsPurchased,
        finalTotalCents: checkout.finalTotalCents,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      await showPurchaseCompletionDialog(
        context,
        financeMessage: 'Compra fechada e salva no histórico compartilhado.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível fechar a compra. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reopenSharedList(SharedShoppingListSummary list) async {
    final uid = _currentUid;
    if (uid.isEmpty) {
      _showSnack('Faça login para reabrir.');
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.repository.reopenSharedList(listId: list.id, updatedBy: uid);
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack('Lista reaberta.', type: AppToastType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível reabrir a lista. Tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openSharedHistory(SharedShoppingListSummary list) async {
    final theme = editorialWorkspaceTheme(Theme.of(context));
    await showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => Theme(
        data: theme,
        child: SharedHistorySheet(list: list, repository: widget.repository),
      ),
    );
  }

  Future<void> _renameSharedList(SharedShoppingListSummary list) async {
    final name = await showListNameDialog(
      context,
      title: 'Renomear lista compartilhada',
      confirmLabel: 'Salvar',
      initialValue: list.name,
    );
    if (!mounted || name == null) {
      return;
    }
    try {
      await widget.repository.updateListMeta(listId: list.id, name: name);
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack('Nome da lista atualizado.', type: AppToastType.success);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível renomear a lista. Tente novamente.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _openInviteDialog(SharedShoppingListSummary list) async {
    final uid = _currentUid;
    _log('open invite sheet');
    if (uid.isEmpty) {
      _showSnack('Faça login para compartilhar.', type: AppToastType.warning);
      return;
    }
    await showSharedInviteSheet(
      context: context,
      repository: widget.repository,
      listId: list.id,
      currentUid: uid,
    );
  }

  Future<void> _openItemEditor({
    required SharedShoppingListSummary list,
    required List<SharedShoppingItem> items,
    SharedShoppingItem? existing,
  }) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final uid = _currentUid;
    if (uid.isEmpty) {
      _showSnack('Faça login para editar itens.', type: AppToastType.warning);
      return;
    }

    final blockedNames = items
        .where((item) => existing == null || item.id != existing.id)
        .map((item) => normalizeQuery(item.name))
        .toSet();
    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: existing?.toShoppingItem(),
      blockedNormalizedNames: blockedNames,
      catalogProducts: widget.store.catalogProducts,
      onLookupBarcode: widget.store.lookupProductByBarcode,
      onLookupCatalogByName: widget.store.lookupCatalogProductByName,
    );
    if (!mounted || draft == null) {
      return;
    }

    final now = DateTime.now();
    final item = SharedShoppingItem(
      id: existing?.id ?? uniqueId(),
      name: draft.name,
      quantity: max(1, draft.quantity),
      unitPrice: max(0, draft.unitPrice),
      isPurchased: draft.isPurchased,
      updatedBy: uid,
      updatedAt: now,
      createdAt: existing?.createdAt ?? now,
      category: draft.category,
      barcode: draft.barcode,
    );

    setState(() {
      _busy = true;
    });
    try {
      await widget.repository.upsertItem(
        listId: list.id,
        item: item,
        updatedBy: uid,
      );
      await widget.store.saveDraftToCatalog(draft);
      if (!mounted) {
        return;
      }
      HapticFeedback.mediumImpact();
      _showSnack(
        existing == null ? 'Item adicionado.' : 'Item atualizado.',
        type: AppToastType.success,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível salvar o item. Verifique sua conexão e tente novamente.',
        type: AppToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _togglePurchased(
    SharedShoppingListSummary list,
    SharedShoppingItem item,
    bool? value,
  ) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }
    try {
      await widget.repository.togglePurchased(
        listId: list.id,
        itemId: item.id,
        isPurchased: value ?? false,
        updatedBy: uid,
      );
      if (!mounted) {
        return;
      }
      HapticFeedback.selectionClick();
      _showSnack(
        (value ?? false) ? 'Item pego.' : 'Item pendente.',
        type: AppToastType.success,
        duration: const Duration(milliseconds: 900),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível atualizar o item. Tente novamente.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _changeQuantity(
    SharedShoppingListSummary list,
    SharedShoppingItem item,
    int delta,
  ) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final uid = _currentUid;
    if (uid.isEmpty) {
      return;
    }
    final next = max(1, item.quantity + delta);
    try {
      await widget.repository.changeQuantity(
        listId: list.id,
        itemId: item.id,
        quantity: next,
        updatedBy: uid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível atualizar a quantidade. Tente novamente.',
        type: AppToastType.error,
      );
    }
  }

  Future<void> _deleteItem(
    SharedShoppingListSummary list,
    SharedShoppingItem item,
  ) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final shouldDelete = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir item?'),
        content: Text('Deseja remover "${item.name}" da lista compartilhada?'),
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
    try {
      await widget.repository.deleteItem(listId: list.id, itemId: item.id);
      if (!mounted) {
        return;
      }
      _showSnack('Item removido.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível excluir o item. Tente novamente.',
        type: AppToastType.error,
      );
    }
  }

  Widget _buildListHeader(
    BuildContext context,
    SharedShoppingListSummary list,
    List<SharedShoppingItem> items,
  ) {
    final derivedList = _toShoppingListModel(list, items);
    final totalValue = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final pickedValue = items
        .where((item) => item.isPurchased)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
    final remainingValue = max<double>(0, totalValue - pickedValue);
    final purchasedCount = items.where((item) => item.isPurchased).length;
    final pendingCount = max(0, items.length - purchasedCount);
    final currentUid = _currentUid;
    final isOwner = currentUid.isNotEmpty && list.isOwner(currentUid);
    final budgetLabel = list.hasBudget && list.budget != null
        ? 'Orçamento: ${formatCurrency(list.budget!)}'
        : 'Sem orçamento';
    final reminderLabel = list.reminder != null
        ? 'Lembrete: ${formatDateTime(list.reminder!.scheduledAt)}'
        : 'Sem lembrete';
    final balancesLabel = list.hasPaymentBalances
        ? 'Saldos: ${formatCurrency(list.paymentBalancesTotal)}'
        : 'Sem saldos';
    final isReadOnly = list.isClosed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SharedEditorialSummary(list: list, items: items, isOwner: isOwner),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _toggleHeaderExpanded,
            icon: Icon(
              _isHeaderExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _isHeaderExpanded
                  ? 'Fechar detalhes da lista'
                  : 'Detalhes da lista',
            ),
          ),
        ),
        if (_isHeaderExpanded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SharedHeaderSectionCard(
                title: 'Resumo da compra',
                subtitle:
                    '${formatCurrency(pickedValue)} pego de ${formatCurrency(totalValue)}',
                expanded:
                    _expandedHeaderSection == _SharedHeaderSection.summary,
                onToggle: () =>
                    _toggleHeaderSection(_SharedHeaderSection.summary),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SharedMetricCard(
                      icon: Icons.attach_money_rounded,
                      label: 'Total planejado',
                      value: formatCurrency(totalValue),
                    ),
                    SharedMetricCard(
                      icon: Icons.shopping_cart_checkout_rounded,
                      label: 'Valor pego',
                      value: formatCurrency(pickedValue),
                    ),
                    SharedMetricCard(
                      icon: Icons.pending_actions_rounded,
                      label: 'Falta pegar',
                      value: formatCurrency(remainingValue),
                    ),
                    SharedMetricCard(
                      icon: Icons.check_circle_rounded,
                      label: 'Pegos',
                      value: formatItemCount(purchasedCount),
                    ),
                    SharedMetricCard(
                      icon: Icons.playlist_add_check_circle_rounded,
                      label: 'Pendentes',
                      value: formatItemCount(pendingCount),
                    ),
                    SharedMetricCard(
                      icon: Icons.inventory_2_rounded,
                      label: 'Total de itens',
                      value: formatItemCount(items.length),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SharedHeaderSectionCard(
                title: 'Orçamento',
                subtitle: budgetLabel,
                expanded: _expandedHeaderSection == _SharedHeaderSection.budget,
                onToggle: () =>
                    _toggleHeaderSection(_SharedHeaderSection.budget),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SharedMetricCard(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Orçamento',
                          value: derivedList.hasBudget
                              ? formatCurrency(derivedList.budget ?? 0)
                              : 'Não definido',
                        ),
                        SharedMetricCard(
                          icon: derivedList.isOverBudget
                              ? Icons.warning_amber_rounded
                              : Icons.savings_rounded,
                          label: derivedList.isOverBudget ? 'Excesso' : 'Saldo',
                          value: derivedList.hasBudget
                              ? formatCurrency(
                                  derivedList.isOverBudget
                                      ? derivedList.overBudgetAmount
                                      : max(0, derivedList.budgetRemaining),
                                )
                              : 'Não definido',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SharedActionChip(
                      icon: Icons.edit_rounded,
                      text: list.hasBudget
                          ? 'Editar orçamento'
                          : 'Definir orçamento',
                      onTap: isReadOnly ? null : () => _openBudgetEditor(list),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SharedHeaderSectionCard(
                title: 'Carteiras e saldos',
                subtitle: balancesLabel,
                expanded:
                    _expandedHeaderSection == _SharedHeaderSection.balances,
                onToggle: () =>
                    _toggleHeaderSection(_SharedHeaderSection.balances),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SharedMetricCard(
                          icon: Icons.payments_rounded,
                          label: 'Total de saldos',
                          value: derivedList.hasPaymentBalances
                              ? formatCurrency(derivedList.paymentBalancesTotal)
                              : 'Não definido',
                        ),
                        SharedMetricCard(
                          icon: derivedList.uncoveredAmount > 0
                              ? Icons.error_outline_rounded
                              : Icons.check_circle_rounded,
                          label: derivedList.uncoveredAmount > 0
                              ? 'Falta cobrir'
                              : 'Coberto',
                          value: derivedList.hasPaymentBalances
                              ? formatCurrency(
                                  derivedList.uncoveredAmount > 0
                                      ? derivedList.uncoveredAmount
                                      : derivedList.coveredAmount,
                                )
                              : 'Não definido',
                        ),
                      ],
                    ),
                    if (derivedList.hasPaymentBalances) ...[
                      const SizedBox(height: 10),
                      ...list.paymentBalances.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SharedBalanceRow(entry: entry),
                        );
                      }),
                    ],
                    const SizedBox(height: 2),
                    SharedActionChip(
                      icon: Icons.account_balance_wallet_rounded,
                      text: list.hasPaymentBalances
                          ? 'Editar saldos'
                          : 'Definir saldos',
                      onTap: isReadOnly
                          ? null
                          : () => _openPaymentBalancesEditor(list),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SharedHeaderSectionCard(
                title: 'Lembrete',
                subtitle: reminderLabel,
                expanded:
                    _expandedHeaderSection == _SharedHeaderSection.reminder,
                onToggle: () =>
                    _toggleHeaderSection(_SharedHeaderSection.reminder),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SharedMetricCard(
                      icon: list.reminder == null
                          ? Icons.notifications_off_rounded
                          : Icons.notifications_active_rounded,
                      label: 'Status',
                      value: list.reminder == null
                          ? 'Sem lembrete'
                          : formatDateTime(list.reminder!.scheduledAt),
                    ),
                    const SizedBox(height: 10),
                    SharedActionChip(
                      icon: Icons.notifications_active_rounded,
                      text: list.reminder == null
                          ? 'Definir lembrete'
                          : 'Editar lembrete',
                      onTap: isReadOnly
                          ? null
                          : () => _openReminderEditor(list),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: editorialWorkspaceTheme(Theme.of(context)),
      child: Builder(
        builder: (context) => StreamBuilder<SharedShoppingListSummary?>(
          stream: widget.repository.watchSharedList(widget.listId),
          builder: (context, listSnapshot) {
            if (listSnapshot.connectionState == ConnectionState.waiting &&
                !listSnapshot.hasData) {
              return const _SharedEditorLoadingScaffold();
            }
            final list = listSnapshot.data;
            if (list == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Lista compartilhada')),
                body: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Lista não encontrada ou sem permissão.'),
                  ),
                ),
              );
            }

            final uid = _currentUid;
            final isOwner = uid.isNotEmpty && list.isOwner(uid);
            final isReadOnly = list.isClosed;
            return StreamBuilder<List<SharedShoppingItem>>(
              stream: widget.repository.watchListItems(list.id),
              builder: (context, itemsSnapshot) {
                final allItems =
                    itemsSnapshot.data ?? const <SharedShoppingItem>[];
                final normalizedQuery = normalizeQuery(_searchQuery);
                final matchingItems = allItems
                    .where(
                      (item) => normalizedQuery.isEmpty
                          ? true
                          : normalizeQuery(item.name).contains(normalizedQuery),
                    )
                    .toList(growable: false);
                final visibleItems = _applyItemsFilter(matchingItems);
                final listModel = _toShoppingListModel(list, allItems);
                final pendingItemsCount = allItems
                    .where((item) => !item.isPurchased)
                    .length;
                final purchasedItemsCount = allItems.length - pendingItemsCount;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  _maybeWarnBudget(listModel);
                  _syncReminderIfNeeded(listModel);
                  _mirrorToLocalIfNeeded(list, listModel);
                  _maybeHandleSharedCatalogImport(list, listModel, allItems);
                });

                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      list.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    actions: [
                      if (isOwner)
                        IconButton(
                          tooltip: 'Gerar código de compartilhamento',
                          onPressed: _busy
                              ? null
                              : () => _openInviteDialog(list),
                          icon: const Icon(Icons.qr_code_rounded),
                        ),
                      PopupMenuButton<String>(
                        tooltip: 'Mais ações',
                        onSelected: (value) {
                          if (value == 'history') {
                            _openSharedHistory(list);
                            return;
                          }
                          if (value == 'catalog_import') {
                            _enableSharedCatalogImport(
                              list,
                              listModel,
                              askForFutureLists: true,
                            );
                            return;
                          }
                          if (value == 'close') {
                            _finalizeSharedList(list, allItems);
                            return;
                          }
                          if (value == 'reopen') {
                            _reopenSharedList(list);
                            return;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'history',
                            child: Text('Histórico compartilhado'),
                          ),
                          PopupMenuItem(
                            value: 'catalog_import',
                            child: Text(
                              widget.store.isSharedCatalogImportEnabled(list.id)
                                  ? 'Atualizar meu catálogo'
                                  : 'Adicionar produtos ao catálogo',
                            ),
                          ),
                          if (!list.isClosed)
                            const PopupMenuItem(
                              value: 'close',
                              child: Text('Fechar compra'),
                            ),
                          if (list.isClosed)
                            const PopupMenuItem(
                              value: 'reopen',
                              child: Text('Reabrir lista'),
                            ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Renomear lista',
                        onPressed: _busy ? null : () => _renameSharedList(list),
                        icon: const Icon(Icons.edit_rounded),
                      ),
                    ],
                  ),
                  bottomNavigationBar: isReadOnly
                      ? null
                      : SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: FilledButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _openItemEditor(
                                      list: list,
                                      items: allItems,
                                    ),
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_rounded, size: 18),
                              label: Text(
                                _busy ? 'Salvando...' : 'Adicionar item',
                              ),
                            ),
                          ),
                        ),
                  body: SafeArea(
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildListHeader(context, list, allItems),
                                    if (!isReadOnly) ...[
                                      const SizedBox(height: 8),
                                      OutlinedButton.icon(
                                        onPressed: _busy
                                            ? null
                                            : () => _finalizeSharedList(
                                                list,
                                                allItems,
                                              ),
                                        icon: const Icon(
                                          Icons.shopping_bag_outlined,
                                          size: 18,
                                        ),
                                        label: const Text('Fechar compra'),
                                      ),
                                    ],
                                    const SizedBox(height: 12),
                                    SharedItemsToolbar(
                                      controller: _searchController,
                                      selectedFilter: _itemsFilter,
                                      totalCount: allItems.length,
                                      pendingCount: pendingItemsCount,
                                      purchasedCount: purchasedItemsCount,
                                      matchingCount: matchingItems.length,
                                      onFilterSelected: _setItemsFilter,
                                    ),
                                    if (_itemsFilter ==
                                            SharedItemsFilter.pending &&
                                        purchasedItemsCount > 0)
                                      SharedItemsHintCard(
                                        hiddenCount: purchasedItemsCount,
                                        onPressed: () => _setItemsFilter(
                                          SharedItemsFilter.purchased,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (allItems.isEmpty || visibleItems.isEmpty)
                          SliverToBoxAdapter(
                            child: allItems.isEmpty
                                ? const SharedItemsEmptyState(
                                    key: ValueKey<String>('shared-empty-all'),
                                    icon: Icons.playlist_add_check_rounded,
                                    title: 'Nenhum item nessa lista ainda',
                                    description:
                                        'Adicione os primeiros produtos para começar a compra compartilhada.',
                                  )
                                : visibleItems.isEmpty
                                ? SharedItemsEmptyState(
                                    key: ValueKey<String>(
                                      'shared-empty-${_itemsFilter.name}-$normalizedQuery',
                                    ),
                                    icon: normalizedQuery.isNotEmpty
                                        ? Icons.search_off_rounded
                                        : Icons.check_circle_outline_rounded,
                                    title: normalizedQuery.isNotEmpty
                                        ? 'Nada encontrado nessa busca'
                                        : _itemsFilter ==
                                              SharedItemsFilter.pending
                                        ? 'Tudo foi pego'
                                        : _itemsFilter ==
                                              SharedItemsFilter.purchased
                                        ? 'Nenhum item pego ainda'
                                        : 'Nenhum item disponível',
                                    description: normalizedQuery.isNotEmpty
                                        ? 'Tente outro nome ou limpe a busca para ver mais itens.'
                                        : _itemsFilter ==
                                              SharedItemsFilter.pending
                                        ? 'Você pode revisar os itens pegos ou continuar pela visão completa.'
                                        : _itemsFilter ==
                                              SharedItemsFilter.purchased
                                        ? 'Marque os itens durante a compra para acompanhar o que já foi pego.'
                                        : 'Adicione novos itens para preencher essa lista.',
                                    primaryActionLabel:
                                        normalizedQuery.isNotEmpty
                                        ? 'Limpar busca'
                                        : _itemsFilter ==
                                              SharedItemsFilter.pending
                                        ? 'Ver pegos'
                                        : _itemsFilter ==
                                              SharedItemsFilter.purchased
                                        ? 'Ver pendentes'
                                        : null,
                                    onPrimaryAction: normalizedQuery.isNotEmpty
                                        ? () => _searchController.clear()
                                        : _itemsFilter ==
                                              SharedItemsFilter.pending
                                        ? () => _setItemsFilter(
                                            SharedItemsFilter.purchased,
                                          )
                                        : _itemsFilter ==
                                              SharedItemsFilter.purchased
                                        ? () => _setItemsFilter(
                                            SharedItemsFilter.pending,
                                          )
                                        : null,
                                  )
                                : const SizedBox.shrink(),
                          )
                        else
                          SliverList.builder(
                            itemCount: visibleItems.length,
                            itemBuilder: (context, index) {
                              final item = visibleItems[index];
                              return Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 600,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: SharedItemCard(
                                      key: ValueKey(item.id),
                                      item: item,
                                      enabled: !isReadOnly && !_busy,
                                      onPurchasedChanged: (value) =>
                                          _togglePurchased(list, item, value),
                                      onIncrement: () =>
                                          _changeQuantity(list, item, 1),
                                      onDecrement: () =>
                                          _changeQuantity(list, item, -1),
                                      onEdit: () => _openItemEditor(
                                        list: list,
                                        items: allItems,
                                        existing: item,
                                      ),
                                      onDelete: () => _deleteItem(list, item),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
