import 'dart:math';

import 'package:flutter/material.dart';

enum ListEditorMenuAction {
  reopenList,
  openSharedList,
  syncSharedNow,
  shareList,
  importFiscalReceipt,
  finalizePurchase,
  openMarketMode,
  openCatalog,
  viewHistory,
  editReminder,
  editBudget,
  editPaymentBalances,
  toggleMarketOrdering,
  renameList,
  clearPurchased,
}

class ListEditorActionsSheet extends StatelessWidget {
  const ListEditorActionsSheet({
    super.key,
    required this.isClosed,
    required this.isSharedLocked,
    required this.hasReminder,
    required this.hasPurchasedItems,
    required this.marketOrderingEnabled,
  });

  final bool isClosed;
  final bool isSharedLocked;
  final bool hasReminder;
  final bool hasPurchasedItems;
  final bool marketOrderingEnabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final quickActions = isClosed
        ? const <ListEditorMenuAction>[ListEditorMenuAction.reopenList]
        : <ListEditorMenuAction>[
            ListEditorMenuAction.finalizePurchase,
            ListEditorMenuAction.importFiscalReceipt,
            ListEditorMenuAction.openMarketMode,
            if (isSharedLocked) ListEditorMenuAction.syncSharedNow,
          ];
    final purchaseActions = <ListEditorMenuAction>[
      if (!isClosed) ...[
        ListEditorMenuAction.importFiscalReceipt,
        ListEditorMenuAction.finalizePurchase,
        ListEditorMenuAction.openMarketMode,
        ListEditorMenuAction.openCatalog,
        if (hasPurchasedItems) ListEditorMenuAction.clearPurchased,
      ],
      if (isClosed) ListEditorMenuAction.reopenList,
      if (isClosed) ListEditorMenuAction.openCatalog,
      if (isSharedLocked) ListEditorMenuAction.openSharedList,
      if (isSharedLocked) ListEditorMenuAction.syncSharedNow,
      ListEditorMenuAction.shareList,
      ListEditorMenuAction.viewHistory,
    ];
    final settingsActions = isClosed
        ? const <ListEditorMenuAction>[]
        : <ListEditorMenuAction>[
            ListEditorMenuAction.editReminder,
            ListEditorMenuAction.editBudget,
            ListEditorMenuAction.editPaymentBalances,
            ListEditorMenuAction.toggleMarketOrdering,
            ListEditorMenuAction.renameList,
          ];

    _ListEditorActionMeta resolveMeta(ListEditorMenuAction action) {
      switch (action) {
        case ListEditorMenuAction.reopenList:
          return _ListEditorActionMeta(
            label: 'Reabrir lista',
            shortLabel: 'Reabrir',
            icon: Icons.lock_open_rounded,
          );
        case ListEditorMenuAction.openSharedList:
          return _ListEditorActionMeta(
            label: 'Abrir lista compartilhada',
            shortLabel: 'Abrir compartilhada',
            icon: Icons.group_work_rounded,
          );
        case ListEditorMenuAction.syncSharedNow:
          return _ListEditorActionMeta(
            label: 'Sincronizar agora',
            shortLabel: 'Sincronizar',
            icon: Icons.sync_rounded,
          );
        case ListEditorMenuAction.shareList:
          return _ListEditorActionMeta(
            label: 'Gerar código de compartilhamento',
            shortLabel: 'Compartilhar',
            icon: Icons.person_add_alt_outlined,
          );
        case ListEditorMenuAction.importFiscalReceipt:
          return _ListEditorActionMeta(
            label: 'Importar cupom fiscal',
            shortLabel: 'Importar cupom',
            icon: Icons.receipt_long_outlined,
          );
        case ListEditorMenuAction.finalizePurchase:
          return _ListEditorActionMeta(
            label: 'Fechar compra',
            shortLabel: 'Fechar compra',
            icon: Icons.check_circle_outline,
          );
        case ListEditorMenuAction.openMarketMode:
          return _ListEditorActionMeta(
            label: 'Abrir modo compra',
            shortLabel: 'Modo compra',
            icon: Icons.shopping_basket_outlined,
          );
        case ListEditorMenuAction.openCatalog:
          return _ListEditorActionMeta(
            label: 'Abrir catálogo de produtos',
            shortLabel: 'Catálogo',
            icon: Icons.inventory_2_outlined,
          );
        case ListEditorMenuAction.viewHistory:
          return _ListEditorActionMeta(
            label: 'Histórico mensal',
            shortLabel: 'Histórico',
            icon: Icons.event_note_rounded,
          );
        case ListEditorMenuAction.editReminder:
          return _ListEditorActionMeta(
            label: 'Configurar lembrete',
            shortLabel: hasReminder ? 'Lembrete Ativo' : 'Lembrete Inativo',
            icon: hasReminder
                ? Icons.notifications_active_rounded
                : Icons.notifications_none_rounded,
          );
        case ListEditorMenuAction.editBudget:
          return _ListEditorActionMeta(
            label: 'Definir orçamento',
            shortLabel: 'Orçamento',
            icon: Icons.account_balance_wallet_rounded,
          );
        case ListEditorMenuAction.editPaymentBalances:
          return _ListEditorActionMeta(
            label: 'Configurar saldos',
            shortLabel: 'Saldos',
            icon: Icons.payments_rounded,
          );
        case ListEditorMenuAction.toggleMarketOrdering:
          return _ListEditorActionMeta(
            label: marketOrderingEnabled
                ? 'Desativar ordem de mercado'
                : 'Ativar ordem de mercado',
            shortLabel: marketOrderingEnabled ? 'Ordem off' : 'Ordem on',
            icon: marketOrderingEnabled
                ? Icons.storefront_rounded
                : Icons.storefront_outlined,
          );
        case ListEditorMenuAction.renameList:
          return _ListEditorActionMeta(
            label: 'Renomear lista',
            shortLabel: 'Renomear',
            icon: Icons.edit_note_rounded,
          );
        case ListEditorMenuAction.clearPurchased:
          return _ListEditorActionMeta(
            label: 'Limpar comprados',
            shortLabel: 'Limpar',
            icon: Icons.remove_done,
          );
      }
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Ações da lista', style: textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Fechar menu de ações',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 20),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          Text(
            'Tudo em um único menu, com atalhos para as ações principais.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
              final columns = constraints.maxWidth < 320 && scale > 1.2 ? 2 : 3;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: quickActions
                    .map(
                      (action) => SizedBox(
                        width: width,
                        child: _ListEditorQuickActionCard(
                          meta: resolveMeta(action),
                          primary: action == quickActions.first,
                          onTap: () => Navigator.pop(context, action),
                        ),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
    final sections = <Widget>[
      _ListEditorActionSection(
        title: 'Compra',
        actions: purchaseActions,
        resolveMeta: resolveMeta,
        onTap: (action) => Navigator.pop(context, action),
      ),
      if (settingsActions.isNotEmpty) ...[
        Divider(
          height: 25,
          color: colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
        _ListEditorActionSection(
          title: 'Configurações',
          actions: settingsActions,
          resolveMeta: resolveMeta,
          onTap: (action) => Navigator.pop(context, action),
        ),
      ],
    ];
    final height = min(MediaQuery.sizeOf(context).height * 0.88, 780.0);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A short viewport cannot reserve the entire header above the actions.
          final scrollHeader = constraints.maxHeight < 320 * textScale;
          final content = ListView(
            key: const ValueKey('list_actions_scroll'),
            padding: EdgeInsets.only(
              top: scrollHeader ? 0 : 16,
              bottom: 20 + bottomInset,
            ),
            children: [
              if (scrollHeader) ...[
                header,
                const Divider(height: 1),
                const SizedBox(height: 16),
              ],
              ...sections,
            ],
          );
          if (scrollHeader) return content;
          return Column(
            children: [
              header,
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              Expanded(child: content),
            ],
          );
        },
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
  final List<ListEditorMenuAction> actions;
  final _ListEditorActionMeta Function(ListEditorMenuAction action) resolveMeta;
  final ValueChanged<ListEditorMenuAction> onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (var i = 0; i < actions.length; i++) ...[
          _ListEditorActionTile(
            meta: resolveMeta(actions[i]),
            onTap: () => onTap(actions[i]),
          ),
          if (i < actions.length - 1)
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
        ],
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
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      minTileHeight: 48,
      horizontalTitleGap: 14,
      leading: Icon(meta.icon, color: theme.colorScheme.primary, size: 22),
      title: Text(meta.label, style: theme.textTheme.bodyMedium),
      trailing: Icon(
        Icons.chevron_right,
        size: 18,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _ListEditorQuickActionCard extends StatelessWidget {
  const _ListEditorQuickActionCard({
    required this.meta,
    required this.onTap,
    required this.primary,
  });
  final _ListEditorActionMeta meta;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = primary
        ? (colors.brightness == Brightness.dark
              ? const Color(0xFF002110)
              : Colors.white)
        : colors.onSurface;
    return Material(
      color: primary
          ? (colors.brightness == Brightness.dark
                ? colors.primary
                : const Color(0xFF365943))
          : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: primary
            ? BorderSide.none
            : BorderSide(color: colors.outlineVariant.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  meta.icon,
                  size: 22,
                  color: primary ? foreground : colors.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  meta.shortLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w500,
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
  });

  final String label;
  final String shortLabel;
  final IconData icon;
}
