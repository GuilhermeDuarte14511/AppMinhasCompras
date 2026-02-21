import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
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
  }) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> _generateInviteCode(
    SharedShoppingListSummary list,
  ) async {
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

  Future<void> _revokeInviteCode(
    SharedShoppingListSummary list,
  ) async {
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
      _showSnack(
        'Não foi possível revogar: $error',
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
      _showSnack(
        'Não foi possível remover: $error',
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
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return StreamBuilder<SharedShoppingListSummary?>(
      stream: widget.repository.watchSharedList(widget.listId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final list = snapshot.data;
        if (list == null) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Lista compartilhada não encontrada.'),
          );
        }

        final isOwner = widget.currentUid.isNotEmpty &&
            list.isOwner(widget.currentUid);
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
                  color:
                      colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (!hasInvite && isOwner)
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _generateInviteCode(list),
                        icon: const Icon(Icons.qr_code_rounded),
                        label: Text(_busy ? 'Gerando...' : 'Gerar código'),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed:
                                _busy || !hasInvite ? null : () => _copyInviteCode(inviteCode),
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
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _SharedListEditorPageState extends State<SharedListEditorPage> {
  late final TextEditingController _searchController;
  bool _busy = false;
  bool _didShowBudgetWarning = false;
  bool _didShowBudgetNearLimitWarning = false;
  String? _lastReminderFingerprint;

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
      _showSnack('A lista jÃ¡ estÃ¡ fechada.');
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
      _showSnack('FaÃ§a login para fechar a lista.');
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
      _showSnack('Compra fechada e salva no histÃ³rico compartilhado.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(
        'NÃ£o foi possÃ­vel fechar a compra: $error',
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
      _showSnack('FaÃ§a login para reabrir.');
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
      _showSnack(
        'NÃ£o foi possÃ­vel reabrir: $error',
        type: AppToastType.error,
      );
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
      _showSnack('Nao foi possivel renomear: $error', type: AppToastType.error);
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
      _showSnack('Faca login para editar itens.', type: AppToastType.warning);
      return;
    }

    final blockedNames = items
        .where((item) => existing == null || item.id != existing.id)
        .map((item) => normalizeQuery(item.name))
        .toSet();
    final suggestionCatalog = widget.store.suggestProductNames(limit: 20);
    final draft = await showShoppingItemEditorSheet(
      context,
      existingItem: existing?.toShoppingItem(),
      blockedNormalizedNames: blockedNames,
      suggestionCatalog: suggestionCatalog,
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
        'Nao foi possivel salvar item: $error',
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
        'Nao foi possivel alterar status: $error',
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
        'Nao foi possivel atualizar quantidade: $error',
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
        'Nao foi possivel excluir item: $error',
        type: AppToastType.error,
      );
    }
  }

  Widget _buildListHeader(
    BuildContext context,
    SharedShoppingListSummary list,
    List<SharedShoppingItem> items,
  ) {
    final totalValue = items.fold<double>(
      0,
      (sum, item) => sum + item.subtotal,
    );
    final purchasedCount = items.where((item) => item.isPurchased).length;
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

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.88),
            colorScheme.secondaryContainer.withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                  text: '${items.length} item(ns)',
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
                  icon: isOwner
                      ? Icons.verified_user_rounded
                      : Icons.people_alt_rounded,
                  text: isOwner ? 'Dono' : 'Membro',
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
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
                _SharedActionChip(
                  icon: Icons.account_balance_wallet_rounded,
                  text: budgetLabel,
                  onTap: isReadOnly ? null : () => _openBudgetEditor(list),
                ),
                _SharedActionChip(
                  icon: Icons.notifications_active_rounded,
                  text: reminderLabel,
                  onTap: isReadOnly ? null : () => _openReminderEditor(list),
                ),
                _SharedActionChip(
                  icon: Icons.payments_rounded,
                  text: balancesLabel,
                  onTap: isReadOnly
                      ? null
                      : () => _openPaymentBalancesEditor(list),
                ),
                if (isReadOnly)
                  const _SharedMetaChip(
                    icon: Icons.lock_rounded,
                    text: 'Lista fechada',
                  ),
              ],
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final list = listSnapshot.data;
        if (list == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lista compartilhada')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Lista nao encontrada ou sem permissao.'),
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
            final visibleItems = allItems
                .where(
                  (item) => normalizedQuery.isEmpty
                      ? true
                      : normalizeQuery(item.name).contains(normalizedQuery),
                )
                .toList(growable: false);
            final listModel = _toShoppingListModel(list, allItems);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _maybeWarnBudget(listModel);
              _syncReminderIfNeeded(listModel);
            });

            return Scaffold(
              appBar: AppBar(
                title: Text(list.name),
                actions: [
                  if (isOwner)
                    IconButton(
                      tooltip: 'Gerar codigo de compartilhamento',
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
                      Expanded(
                        child: allItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum item nesta lista compartilhada.',
                                ),
                              )
                            : visibleItems.isEmpty
                            ? const Center(
                                child: Text(
                                  'Nenhum item encontrado para a busca.',
                                ),
                              )
                            : ListView.separated(
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
                                  return _SharedItemCard(
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
                                  );
                                },
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
    return Card(
      child: ListTile(
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
              const SizedBox(height: 12),
              ...purchase.items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(item.name, style: textTheme.bodyMedium),
                      ),
                      Text(
                        '${item.quantity} x ${formatCurrency(item.unitPrice)}',
                        style: textTheme.bodySmall,
                      ),
                    ],
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
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
        child: Row(
          children: [
            Checkbox(value: item.isPurchased, onChanged: onPurchasedChanged),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: item.isPurchased
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.quantity} x ${formatCurrency(item.unitPrice)} = ${formatCurrency(item.subtotal)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Diminuir',
              onPressed: onDecrement,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
            Text(
              '${item.quantity}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            IconButton(
              tooltip: 'Aumentar',
              onPressed: onIncrement,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
            PopupMenuButton<String>(
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
      ),
    );
  }
}
