import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/store_and_services.dart';
import '../core/utils/format_utils.dart';
import '../data/remote/shared_lists_repository.dart';
import '../domain/models_and_utils.dart';
import 'dialogs_and_sheets.dart';
import 'launch.dart';
import 'utils/app_modal.dart';
import 'utils/app_toast.dart';

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

enum _InviteDialogAction { copy, regenerate, revoke, close }

class _SharedListEditorPageState extends State<SharedListEditorPage> {
  late final TextEditingController _searchController;
  bool _busy = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
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

  void _showSnack(String message, {AppToastType type = AppToastType.info}) {
    AppToast.show(
      context,
      message: message,
      type: type,
      duration: const Duration(seconds: 4),
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
    if (uid.isEmpty) {
      _showSnack('Faca login para compartilhar.', type: AppToastType.warning);
      return;
    }
    if (!list.isOwner(uid)) {
      _showSnack(
        'Somente o dono da lista pode gerenciar o codigo.',
        type: AppToastType.warning,
      );
      return;
    }

    var currentCode = list.inviteCode;
    if (currentCode == null || currentCode.isEmpty) {
      try {
        currentCode = await widget.repository.generateInviteCode(
          listId: list.id,
          requesterUid: uid,
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        _showSnack(
          'Nao foi possivel gerar codigo: $error',
          type: AppToastType.error,
        );
        return;
      }
    }

    while (mounted) {
      final pageContext = context;
      if (!pageContext.mounted) {
        return;
      }
      final action = await showAppDialog<_InviteDialogAction>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Codigo de compartilhamento'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Compartilhe este codigo com quem vai entrar na lista:'),
              const SizedBox(height: 10),
              SelectableText(
                currentCode ?? 'Sem codigo ativo',
                style: Theme.of(dialogContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InviteDialogAction.close),
              child: const Text('Fechar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InviteDialogAction.revoke),
              child: const Text('Revogar'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _InviteDialogAction.regenerate,
              ),
              child: const Text('Regenerar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _InviteDialogAction.copy),
              child: const Text('Copiar'),
            ),
          ],
        ),
      );
      if (!pageContext.mounted ||
          action == null ||
          action == _InviteDialogAction.close) {
        return;
      }
      if (action == _InviteDialogAction.copy) {
        if (currentCode == null || currentCode.isEmpty) {
          _showSnack('Nao ha codigo ativo.', type: AppToastType.warning);
          continue;
        }
        await Clipboard.setData(ClipboardData(text: currentCode));
        if (!pageContext.mounted) {
          return;
        }
        _showSnack('Codigo copiado.');
        continue;
      }
      if (action == _InviteDialogAction.revoke) {
        try {
          await widget.repository.revokeInviteCode(
            listId: list.id,
            requesterUid: uid,
          );
          if (!mounted) {
            return;
          }
          currentCode = null;
          _showSnack('Codigo revogado.');
        } catch (error) {
          if (!pageContext.mounted) {
            return;
          }
          _showSnack(
            'Nao foi possivel revogar codigo: $error',
            type: AppToastType.error,
          );
        }
        continue;
      }
      if (action == _InviteDialogAction.regenerate) {
        try {
          final regenerated = await widget.repository.generateInviteCode(
            listId: list.id,
            requesterUid: uid,
          );
          if (!pageContext.mounted) {
            return;
          }
          currentCode = regenerated;
          _showSnack('Novo codigo gerado.');
        } catch (error) {
          if (!mounted) {
            return;
          }
          _showSnack(
            'Nao foi possivel regenerar codigo: $error',
            type: AppToastType.error,
          );
        }
      }
    }
  }

  Future<void> _openItemEditor({
    required SharedShoppingListSummary list,
    required List<SharedShoppingItem> items,
    SharedShoppingItem? existing,
  }) async {
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
    final totalValue = items.fold<double>(0, (sum, item) => sum + item.subtotal);
    final purchasedCount = items.where((item) => item.isPurchased).length;
    final currentUid = _currentUid;
    final isOwner = currentUid.isNotEmpty && list.isOwner(currentUid);
    final colorScheme = Theme.of(context).colorScheme;

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
                  icon: isOwner ? Icons.verified_user_rounded : Icons.people_alt_rounded,
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
                  IconButton(
                    tooltip: 'Renomear lista',
                    onPressed: _busy ? null : () => _renameSharedList(list),
                    icon: const Icon(Icons.edit_rounded),
                  ),
                ],
              ),
              floatingActionButton: FloatingActionButton.extended(
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
                                child: Text('Nenhum item nesta lista compartilhada.'),
                              )
                            : visibleItems.isEmpty
                            ? const Center(
                                child: Text('Nenhum item encontrado para a busca.'),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
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
