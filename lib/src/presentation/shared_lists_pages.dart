import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
import 'theme/app_tokens.dart';
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
    showDragHandle: true,
    useSafeArea: true,
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

class _SharedSummarySkeleton extends StatelessWidget {
  const _SharedSummarySkeleton();

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lista compartilhada carregando',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text('Sincronizando membros e configuracoes.'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: const [
                      Chip(label: Text('Membros')),
                      Chip(label: Text('Convites')),
                      Chip(label: Text('Status')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedEditorLoadingScaffold extends StatelessWidget {
  const _SharedEditorLoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lista compartilhada')),
      body: AppGradientScene(
        child: SafeArea(
          child: Skeletonizer(
            enabled: true,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mercado da semana',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text('3 membros ativos na compra'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            Chip(label: Text('Valor total')),
                            Chip(label: Text('Valor pego')),
                            Chip(label: Text('Falta pegar')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(
                  5,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.shopping_bag_rounded),
                        ),
                        title: Text('Item compartilhado ${index + 1}'),
                        subtitle: const Text('Quantidade, valor e status'),
                        trailing: const Icon(Icons.more_horiz_rounded),
                      ),
                    ),
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

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _generateInviteCode(SharedShoppingListSummary list) async {
    setState(() => _busy = true);
    try {
      _log('invite generate listId=${list.id}');
      await widget.repository.generateInviteCode(
        listId: list.id,
        requesterUid: widget.currentUid,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Novo código gerado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('invite generate error=$error');
      _showSnack(
        'Não foi possível gerar código: $error',
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
      _log('invite revoke listId=${list.id}');
      await widget.repository.revokeInviteCode(
        listId: list.id,
        requesterUid: widget.currentUid,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Código revogado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('invite revoke error=$error');
      _showSnack('Não foi possível revogar: $error', type: AppToastType.error);
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
    _showSnack('Código copiado.');
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
      builder: (dialogContext) => AlertDialog(
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
    );
    if (!mounted || confirm != true) {
      return;
    }
    setState(() => _busy = true);
    try {
      _log('remove member listId=${list.id} member=$memberUid');
      await widget.repository.removeMember(
        listId: list.id,
        requesterUid: widget.currentUid,
        memberUid: memberUid,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Membro removido.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _log('remove member error=$error');
      _showSnack('Não foi possível remover: $error', type: AppToastType.error);
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<SharedShoppingListSummary?>(
      stream: widget.repository.watchSharedList(widget.listId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: _SharedSummarySkeleton(),
          );
        }

        final list = snapshot.data;
        if (list == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Lista compartilhada não encontrada.'),
          );
        }

        final isOwner =
            widget.currentUid.isNotEmpty && list.isOwner(widget.currentUid);
        final inviteCode = list.inviteCode ?? '';
        final hasInvite = inviteCode.trim().isNotEmpty;
        final members = _sortedMembers(list);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Compartilhamento',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Convide pessoas para editar esta lista em tempo real.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.7,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de convite',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasInvite ? inviteCode : 'Nenhum código ativo',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (!hasInvite && isOwner)
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _generateInviteCode(list),
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(_busy ? 'Gerando...' : 'Gerar código'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: _busy || !hasInvite
                                ? null
                                : () => _copyInviteCode(inviteCode),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Copiar'),
                          ),
                          if (isOwner)
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _generateInviteCode(list),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Regenerar'),
                            ),
                          if (isOwner)
                            TextButton(
                              onPressed: _busy || !hasInvite
                                  ? null
                                  : () => _revokeInviteCode(list),
                              child: const Text('Revogar'),
                            ),
                        ],
                      ),
                    if (!isOwner)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Somente o dono pode gerenciar o código.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Membros',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${members.length}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: members.map((uid) {
                  final isOwnerUid = uid == list.ownerUid;
                  final isCurrent = uid == widget.currentUid;
                  final shortUid = uid.length <= 6
                      ? uid
                      : uid.substring(uid.length - 6);
                  final roleLabel = isOwnerUid ? 'Dono' : 'Membro';
                  final displayLabel =
                      '$roleLabel${isCurrent ? ' (você)' : ''} • $shortUid';
                  return InputChip(
                    label: Text(displayLabel),
                    onDeleted: isOwner && !isOwnerUid && !_busy
                        ? () => _removeMember(list: list, memberUid: uid)
                        : null,
                    deleteIcon: const Icon(Icons.close_rounded),
                    avatar: CircleAvatar(
                      radius: 12,
                      backgroundColor: isOwnerUid
                          ? colorScheme.tertiaryContainer
                          : colorScheme.secondaryContainer,
                      child: Icon(
                        isOwnerUid
                            ? Icons.workspace_premium_rounded
                            : Icons.person_rounded,
                        size: 14,
                        color: isOwnerUid
                            ? colorScheme.onTertiaryContainer
                            : colorScheme.onSecondaryContainer,
                      ),
                    ),
                  );
                }).toList(),
              ),
              if (widget.onOpenSharedList != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _openSharedList,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir lista compartilhada'),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class SharedListEditorPage extends StatefulWidget {
  const SharedListEditorPage({
    super.key,
    required this.repository,
    required this.store,
    required this.listId,
  });

  final SharedListsRepository repository;
  final ShoppingListsStore store;
  final String listId;

  @override
  State<SharedListEditorPage> createState() => _SharedListEditorPageState();
}

enum _SharedHeaderSection { summary, budget, balances, reminder }

enum _SharedItemsFilter { pending, all, purchased }

class _SharedListEditorPageState extends State<SharedListEditorPage> {
  late final TextEditingController _searchController;
  bool _busy = false;
  bool _isHeaderExpanded = false;
  bool _didShowBudgetWarning = false;
  bool _didShowBudgetNearLimitWarning = false;
  String? _lastReminderFingerprint;
  String? _lastLocalMirrorFingerprint;
  _SharedHeaderSection? _expandedHeaderSection;
  _SharedItemsFilter _itemsFilter = _SharedItemsFilter.pending;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
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

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
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

  void _setItemsFilter(_SharedItemsFilter filter) {
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
            _SharedItemsFilter.pending => !item.isPurchased,
            _SharedItemsFilter.all => true,
            _SharedItemsFilter.purchased => item.isPurchased,
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
    _log('mirror local listId=$sourceId from shared=${list.id}');
    unawaited(widget.store.upsertList(mirrored));
  }

  Future<void> _openBudgetEditor(SharedShoppingListSummary list) async {
    if (!_ensureEditable(list)) {
      return;
    }
    final result = await showBudgetEditorDialog(
      context,
      initialValue: list.budget,
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
    await widget.repository.updateListMeta(listId: list.id, budget: value);
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
      await widget.repository.finalizeSharedList(
        listId: list.id,
        updatedBy: uid,
        markPendingAsPurchased: checkout.markPendingAsPurchased,
      );
      if (!mounted) {
        return;
      }
      _showSnack('Compra fechada e salva no histórico compartilhado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível fechar a compra: $error',
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
      _showSnack('Lista reaberta.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Não foi possível reabrir: $error', type: AppToastType.error);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openSharedHistory(SharedShoppingListSummary list) async {
    await showAppModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) =>
          _SharedHistorySheet(list: list, repository: widget.repository),
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
      _showSnack('Nome da lista atualizado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack('Não foi possível renomear: $error', type: AppToastType.error);
    }
  }

  Future<void> _openInviteDialog(SharedShoppingListSummary list) async {
    final uid = _currentUid;
    _log(
      'openInviteSheet listId=${list.id} owner=${list.ownerUid} '
      'currentUid=$uid invite=${list.inviteCode ?? '-'}',
    );
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
      isPurchased: existing?.isPurchased ?? false,
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
      _showSnack(existing == null ? 'Item adicionado.' : 'Item atualizado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível salvar item: $error',
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
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'Não foi possível alterar status: $error',
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
        'Não foi possível atualizar quantidade: $error',
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
        'Não foi possível excluir item: $error',
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
    final colorScheme = Theme.of(context).colorScheme;
    final budgetLabel = list.hasBudget && list.budget != null
        ? 'Orçamento: ${formatCurrency(list.budget!)}'
        : 'Orçamento: indefinido';
    final reminderLabel = list.reminder != null
        ? 'Lembrete: ${formatDateTime(list.reminder!.scheduledAt)}'
        : 'Lembrete: desligado';
    final balancesLabel = list.hasPaymentBalances
        ? 'Saldos: ${formatCurrency(list.paymentBalancesTotal)}'
        : 'Saldos: indefinido';
    final isReadOnly = list.isClosed;
    final headerSubtitle =
        '${formatItemCount(items.length)} • $purchasedCount comprados • ${formatCurrency(pickedValue)} pego';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colorScheme.primaryContainer.withValues(alpha: 0.56),
          colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _toggleHeaderExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Painel da lista',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            headerSubtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surface.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isHeaderExpanded ? 'Fechar' : 'Abrir',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: _isHeaderExpanded ? 0.5 : 0,
                              duration: _adaptiveMotionDuration(
                                context,
                                AppTokens.motionMedium,
                              ),
                              child: const Icon(
                                Icons.keyboard_arrow_down_rounded,
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
            ClipRect(
              child: AnimatedAlign(
                duration: _adaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: _isHeaderExpanded ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SharedMetaChip(
                            icon: Icons.group_rounded,
                            text:
                                '${list.memberCount} membro${list.memberCount == 1 ? '' : 's'}',
                          ),
                          _SharedMetaChip(
                            icon: Icons.shopping_basket_rounded,
                            text: formatItemCount(items.length),
                          ),
                          _SharedMetaChip(
                            icon: Icons.check_circle_rounded,
                            text: '$purchasedCount comprados',
                          ),
                          _SharedMetaChip(
                            icon: Icons.attach_money_rounded,
                            text: formatCurrency(totalValue),
                          ),
                          _SharedMetaChip(
                            icon: Icons.shopping_cart_checkout_rounded,
                            text: 'Pego ${formatCurrency(pickedValue)}',
                          ),
                          _SharedMetaChip(
                            icon: Icons.pending_actions_rounded,
                            text: 'Falta ${formatCurrency(remainingValue)}',
                          ),
                          _SharedMetaChip(
                            icon: isOwner
                                ? Icons.verified_user_rounded
                                : Icons.people_alt_rounded,
                            text: isOwner ? 'Dono' : 'Membro',
                          ),
                          if (isReadOnly)
                            const _SharedMetaChip(
                              icon: Icons.lock_rounded,
                              text: 'Lista fechada',
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _SharedHeaderSectionCard(
                        title: 'Resumo da compra',
                        subtitle:
                            '${formatCurrency(pickedValue)} pego de ${formatCurrency(totalValue)}',
                        expanded:
                            _expandedHeaderSection ==
                            _SharedHeaderSection.summary,
                        onToggle: () =>
                            _toggleHeaderSection(_SharedHeaderSection.summary),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _SharedMetricCard(
                              icon: Icons.attach_money_rounded,
                              label: 'Total planejado',
                              value: formatCurrency(totalValue),
                            ),
                            _SharedMetricCard(
                              icon: Icons.shopping_cart_checkout_rounded,
                              label: 'Valor pego',
                              value: formatCurrency(pickedValue),
                            ),
                            _SharedMetricCard(
                              icon: Icons.pending_actions_rounded,
                              label: 'Falta pegar',
                              value: formatCurrency(remainingValue),
                            ),
                            _SharedMetricCard(
                              icon: Icons.check_circle_rounded,
                              label: 'Comprados',
                              value: formatItemCount(purchasedCount),
                            ),
                            _SharedMetricCard(
                              icon: Icons.playlist_add_check_circle_rounded,
                              label: 'Pendentes',
                              value: formatItemCount(pendingCount),
                            ),
                            _SharedMetricCard(
                              icon: Icons.inventory_2_rounded,
                              label: 'Total de itens',
                              value: formatItemCount(items.length),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SharedHeaderSectionCard(
                        title: 'Orçamento',
                        subtitle: budgetLabel,
                        expanded:
                            _expandedHeaderSection ==
                            _SharedHeaderSection.budget,
                        onToggle: () =>
                            _toggleHeaderSection(_SharedHeaderSection.budget),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _SharedMetricCard(
                                  icon: Icons.account_balance_wallet_rounded,
                                  label: 'Orçamento',
                                  value: derivedList.hasBudget
                                      ? formatCurrency(derivedList.budget ?? 0)
                                      : 'Não definido',
                                ),
                                _SharedMetricCard(
                                  icon: derivedList.isOverBudget
                                      ? Icons.warning_amber_rounded
                                      : Icons.savings_rounded,
                                  label: derivedList.isOverBudget
                                      ? 'Excesso'
                                      : 'Saldo',
                                  value: derivedList.hasBudget
                                      ? formatCurrency(
                                          derivedList.isOverBudget
                                              ? derivedList.overBudgetAmount
                                              : max(
                                                  0,
                                                  derivedList.budgetRemaining,
                                                ),
                                        )
                                      : 'Não definido',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _SharedActionChip(
                              icon: Icons.edit_rounded,
                              text: list.hasBudget
                                  ? 'Editar orçamento'
                                  : 'Definir orçamento',
                              onTap: isReadOnly
                                  ? null
                                  : () => _openBudgetEditor(list),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SharedHeaderSectionCard(
                        title: 'Carteiras e saldos',
                        subtitle: balancesLabel,
                        expanded:
                            _expandedHeaderSection ==
                            _SharedHeaderSection.balances,
                        onToggle: () =>
                            _toggleHeaderSection(_SharedHeaderSection.balances),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                _SharedMetricCard(
                                  icon: Icons.payments_rounded,
                                  label: 'Total de saldos',
                                  value: derivedList.hasPaymentBalances
                                      ? formatCurrency(
                                          derivedList.paymentBalancesTotal,
                                        )
                                      : 'Não definido',
                                ),
                                _SharedMetricCard(
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
                                  child: _SharedBalanceRow(entry: entry),
                                );
                              }),
                            ],
                            const SizedBox(height: 2),
                            _SharedActionChip(
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
                      _SharedHeaderSectionCard(
                        title: 'Lembrete',
                        subtitle: reminderLabel,
                        expanded:
                            _expandedHeaderSection ==
                            _SharedHeaderSection.reminder,
                        onToggle: () =>
                            _toggleHeaderSection(_SharedHeaderSection.reminder),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SharedMetricCard(
                              icon: list.reminder == null
                                  ? Icons.notifications_off_rounded
                                  : Icons.notifications_active_rounded,
                              label: 'Status',
                              value: list.reminder == null
                                  ? 'Lembrete desligado'
                                  : formatDateTime(list.reminder!.scheduledAt),
                            ),
                            const SizedBox(height: 10),
                            _SharedActionChip(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SharedShoppingListSummary?>(
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
            final allItems = itemsSnapshot.data ?? const <SharedShoppingItem>[];
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
            });

            return Scaffold(
              appBar: AppBar(
                title: Text(list.name),
                actions: [
                  if (isOwner)
                    IconButton(
                      tooltip: 'Gerar código de compartilhamento',
                      onPressed: _busy ? null : () => _openInviteDialog(list),
                      icon: const Icon(Icons.qr_code_rounded),
                    ),
                  PopupMenuButton<String>(
                    tooltip: 'Mais ações',
                    onSelected: (value) {
                      if (value == 'history') {
                        _openSharedHistory(list);
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
              floatingActionButton: isReadOnly
                  ? null
                  : FloatingActionButton.extended(
                      onPressed: _busy
                          ? null
                          : () => _openItemEditor(list: list, items: allItems),
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_shopping_cart_rounded),
                      label: Text(_busy ? 'Salvando...' : 'Adicionar item'),
                    ),
              body: AppGradientScene(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: _buildListHeader(context, list, allItems),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _SharedItemsToolbar(
                          controller: _searchController,
                          selectedFilter: _itemsFilter,
                          totalCount: allItems.length,
                          pendingCount: pendingItemsCount,
                          purchasedCount: purchasedItemsCount,
                          matchingCount: matchingItems.length,
                          onFilterSelected: _setItemsFilter,
                        ),
                      ),
                      if (_itemsFilter == _SharedItemsFilter.pending &&
                          purchasedItemsCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _SharedItemsHintCard(
                            hiddenCount: purchasedItemsCount,
                            onPressed: () =>
                                _setItemsFilter(_SharedItemsFilter.purchased),
                          ),
                        ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: AppTokens.motionMedium,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: allItems.isEmpty
                              ? const _SharedItemsEmptyState(
                                  key: ValueKey<String>('shared-empty-all'),
                                  icon: Icons.playlist_add_check_rounded,
                                  title: 'Nenhum item nessa lista ainda',
                                  description:
                                      'Adicione os primeiros produtos para começar a compra compartilhada.',
                                )
                              : visibleItems.isEmpty
                              ? _SharedItemsEmptyState(
                                  key: ValueKey<String>(
                                    'shared-empty-${_itemsFilter.name}-$normalizedQuery',
                                  ),
                                  icon: normalizedQuery.isNotEmpty
                                      ? Icons.search_off_rounded
                                      : Icons.check_circle_outline_rounded,
                                  title: normalizedQuery.isNotEmpty
                                      ? 'Nada encontrado nessa busca'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.pending
                                      ? 'Tudo foi pego'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.purchased
                                      ? 'Nenhum item marcado ainda'
                                      : 'Nenhum item disponível',
                                  description: normalizedQuery.isNotEmpty
                                      ? 'Tente outro nome ou limpe a busca para ver mais itens.'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.pending
                                      ? 'Você pode revisar os comprados ou continuar pela visão completa.'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.purchased
                                      ? 'Marque os itens durante a compra para acompanhar o que já foi pego.'
                                      : 'Adicione novos itens para preencher essa lista.',
                                  primaryActionLabel: normalizedQuery.isNotEmpty
                                      ? 'Limpar busca'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.pending
                                      ? 'Ver comprados'
                                      : _itemsFilter ==
                                            _SharedItemsFilter.purchased
                                      ? 'Ver pendentes'
                                      : null,
                                  onPrimaryAction: normalizedQuery.isNotEmpty
                                      ? () => _searchController.clear()
                                      : _itemsFilter ==
                                            _SharedItemsFilter.pending
                                      ? () => _setItemsFilter(
                                          _SharedItemsFilter.purchased,
                                        )
                                      : _itemsFilter ==
                                            _SharedItemsFilter.purchased
                                      ? () => _setItemsFilter(
                                          _SharedItemsFilter.pending,
                                        )
                                      : null,
                                )
                              : ListView.separated(
                                  key: ValueKey<String>(
                                    'shared-items-${_itemsFilter.name}-$normalizedQuery-${visibleItems.length}',
                                  ),
                                  keyboardDismissBehavior:
                                      ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    120,
                                  ),
                                  itemCount: visibleItems.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = visibleItems[index];
                                    return RepaintBoundary(
                                      child: _SharedItemCard(
                                        key: ValueKey<String>(item.id),
                                        item: item,
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
          },
        );
      },
    );
  }
}

class _SharedItemsToolbar extends StatelessWidget {
  const _SharedItemsToolbar({
    required this.controller,
    required this.selectedFilter,
    required this.totalCount,
    required this.pendingCount,
    required this.purchasedCount,
    required this.matchingCount,
    required this.onFilterSelected,
  });

  final TextEditingController controller;
  final _SharedItemsFilter selectedFilter;
  final int totalCount;
  final int pendingCount;
  final int purchasedCount;
  final int matchingCount;
  final ValueChanged<_SharedItemsFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final searchIsActive = matchingCount != totalCount;
    final filterEntries =
        <({String label, int count, _SharedItemsFilter value})>[
          (
            label: 'Pendentes',
            count: pendingCount,
            value: _SharedItemsFilter.pending,
          ),
          (label: 'Todos', count: totalCount, value: _SharedItemsFilter.all),
          (
            label: 'Comprados',
            count: purchasedCount,
            value: _SharedItemsFilter.purchased,
          ),
        ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Buscar item por nome...',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in filterEntries)
                  ChoiceChip(
                    selected: selectedFilter == filter.value,
                    showCheckmark: false,
                    label: Text('${filter.label} ${filter.count}'),
                    avatar: Icon(switch (filter.value) {
                      _SharedItemsFilter.pending =>
                        Icons.pending_actions_rounded,
                      _SharedItemsFilter.all =>
                        Icons.format_list_bulleted_rounded,
                      _SharedItemsFilter.purchased =>
                        Icons.check_circle_rounded,
                    }, size: 16),
                    onSelected: (_) => onFilterSelected(filter.value),
                  ),
              ],
            ),
            if (searchIsActive) ...[
              const SizedBox(height: 8),
              Text(
                '${formatCountLabel(matchingCount, 'resultado', 'resultados')} na busca atual.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SharedItemsHintCard extends StatelessWidget {
  const _SharedItemsHintCard({
    required this.hiddenCount,
    required this.onPressed,
  });

  final int hiddenCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, color: colorScheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hiddenCount == 1
                    ? '1 item já pego está oculto para deixar a lista mais prática.'
                    : '$hiddenCount itens já pegos estão ocultos para deixar a lista mais prática.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(onPressed: onPressed, child: const Text('Ver')),
          ],
        ),
      ),
    );
  }
}

class _SharedItemsEmptyState extends StatelessWidget {
  const _SharedItemsEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(AppTokens.radiusXl),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 32, color: colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (primaryActionLabel != null &&
                      onPrimaryAction != null) ...[
                    const SizedBox(height: 16),
                    FilledButton.tonal(
                      onPressed: onPrimaryAction,
                      child: Text(primaryActionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedMetaChip extends StatelessWidget {
  const _SharedMetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _SharedActionChip extends StatelessWidget {
  const _SharedActionChip({required this.icon, required this.text, this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isEnabled
                ? colorScheme.surface.withValues(alpha: 0.75)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                text,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isEnabled
                      ? colorScheme.onSurface
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedHeaderSectionCard extends StatelessWidget {
  const _SharedHeaderSectionCard({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      toggled: expanded,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: _adaptiveMotionDuration(
                        context,
                        AppTokens.motionMedium,
                      ),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  ],
                ),
              ),
            ),
            ClipRect(
              child: AnimatedAlign(
                duration: _adaptiveMotionDuration(
                  context,
                  AppTokens.motionMedium,
                ),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                heightFactor: expanded ? 1 : 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedMetricCard extends StatelessWidget {
  const _SharedMetricCard({
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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 138),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SharedBalanceRow extends StatelessWidget {
  const _SharedBalanceRow({required this.entry});

  final PaymentBalance entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label:
          'Carteira ${entry.name}, tipo ${entry.type.label}, saldo ${formatCurrency(entry.value)}',
      readOnly: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.type.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatCurrency(entry.value),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedHistorySheet extends StatelessWidget {
  const _SharedHistorySheet({required this.list, required this.repository});

  final SharedShoppingListSummary list;
  final SharedListsRepository repository;

  Map<DateTime, List<CompletedPurchase>> _groupByMonth(
    List<CompletedPurchase> entries,
  ) {
    final groups = <DateTime, List<CompletedPurchase>>{};
    for (final entry in entries) {
      final key = DateTime(entry.closedAt.year, entry.closedAt.month);
      groups.putIfAbsent(key, () => <CompletedPurchase>[]).add(entry);
    }
    final orderedKeys = groups.keys.toList(growable: false)
      ..sort((a, b) => b.compareTo(a));
    final ordered = <DateTime, List<CompletedPurchase>>{};
    for (final key in orderedKeys) {
      final entriesForMonth = groups[key]!
        ..sort((a, b) => b.closedAt.compareTo(a.closedAt));
      ordered[key] = List.unmodifiable(entriesForMonth);
    }
    return Map.unmodifiable(ordered);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Histórico compartilhado',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Compras fechadas da lista "${list.name}".',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: min(MediaQuery.sizeOf(context).height * 0.6, 420),
            child: StreamBuilder<List<CompletedPurchase>>(
              stream: repository.watchSharedHistory(list.id),
              builder: (context, snapshot) {
                final entries = snapshot.data ?? const <CompletedPurchase>[];
                if (entries.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma compra fechada ainda.'),
                  );
                }
                final grouped = _groupByMonth(entries);
                return ListView(
                  children: grouped.entries
                      .map((entry) {
                        final monthKey = entry.key;
                        final monthLabel = DateFormat(
                          'MMMM yyyy',
                          'pt_BR',
                        ).format(monthKey);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                monthLabel,
                                style: textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...entry.value.map((purchase) {
                                return _SharedHistoryCard(purchase: purchase);
                              }),
                            ],
                          ),
                        );
                      })
                      .toList(growable: false),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SharedHistoryCard extends StatelessWidget {
  const _SharedHistoryCard({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(
          formatDateTime(purchase.closedAt),
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${purchase.productsCount} itens · Total ${formatCurrency(purchase.totalValue)}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => showAppDialog<void>(
          context: context,
          builder: (_) => _SharedHistoryDetailsSheet(purchase: purchase),
        ),
      ),
    );
  }
}

class _SharedHistoryDetailsSheet extends StatelessWidget {
  const _SharedHistoryDetailsSheet({required this.purchase});

  final CompletedPurchase purchase;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Detalhes da compra'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.28),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatDateTime(purchase.closedAt),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total: ${formatCurrency(purchase.totalValue)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...purchase.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.24,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.name, style: textTheme.bodyMedium),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (purchase.hasPaymentBalances) ...[
                const SizedBox(height: 10),
                Text(
                  'Saldos utilizados',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                ...purchase.paymentUsage.map((entry) {
                  return Text(
                    '${entry.balance.name}: ${formatCurrency(entry.consumed)}',
                    style: textTheme.bodySmall,
                  );
                }),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

class _SharedItemCard extends StatelessWidget {
  const _SharedItemCard({
    super.key,
    required this.item,
    required this.onPurchasedChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onDelete,
  });

  final SharedShoppingItem item;
  final ValueChanged<bool?> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cardColor = item.isPurchased
        ? colorScheme.surfaceContainerLow.withValues(alpha: 0.95)
        : colorScheme.surface;
    return Card(
      elevation: 0,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Checkbox(
                    value: item.isPurchased,
                    onChanged: onPurchasedChanged,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            decoration: item.isPurchased
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Mais acoes do item',
                  onSelected: (action) {
                    if (action == 'edit') {
                      onEdit();
                      return;
                    }
                    if (action == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar item')),
                    PopupMenuItem(value: 'delete', child: Text('Excluir item')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _SharedItemInfoChip(
                  icon: item.isPurchased
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  label: item.isPurchased ? 'Pego' : 'Pendente',
                  emphasized: item.isPurchased,
                ),
                _SharedItemInfoChip(
                  icon: Icons.receipt_long_rounded,
                  label: formatCurrency(item.subtotal),
                ),
                _SharedQuantityStepper(
                  quantity: item.quantity,
                  onIncrement: onIncrement,
                  onDecrement: onDecrement,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedItemInfoChip extends StatelessWidget {
  const _SharedItemInfoChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = emphasized
        ? colorScheme.primaryContainer.withValues(alpha: 0.82)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.58);
    final foregroundColor = emphasized
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedQuantityStepper extends StatelessWidget {
  const _SharedQuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.26),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Diminuir',
            visualDensity: VisualDensity.compact,
            onPressed: onDecrement,
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(
            '$quantity',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          IconButton(
            tooltip: 'Aumentar',
            visualDensity: VisualDensity.compact,
            onPressed: onIncrement,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
