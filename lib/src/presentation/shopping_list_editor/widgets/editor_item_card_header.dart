import 'package:flutter/material.dart';

import '../../../core/utils/format_utils.dart';
import '../../../domain/classifications.dart';
import '../../../domain/models_and_utils.dart';

enum _ItemAction { edit, history, delete }

class EditorItemCardHeader extends StatelessWidget {
  const EditorItemCardHeader({
    super.key,
    required this.item,
    required this.readOnly,
    required this.expanded,
    required this.motionDuration,
    required this.onToggleExpanded,
    required this.onPurchasedChanged,
    required this.onEdit,
    required this.onViewHistory,
    required this.onDelete,
  });

  final ShoppingItem item;
  final bool readOnly;
  final bool expanded;
  final Duration motionDuration;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onPurchasedChanged;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Semantics(
          label: item.isPurchased
              ? 'Marcar ${item.name} como pendente'
              : 'Marcar ${item.name} como comprado',
          child: Checkbox(
            value: item.isPurchased,
            onChanged: readOnly
                ? null
                : (value) {
                    if (value != null) onPurchasedChanged(value);
                  },
          ),
        ),
        Expanded(
          child: Semantics(
            button: true,
            expanded: expanded,
            onTap: onToggleExpanded,
            hint: expanded
                ? 'Recolher detalhes'
                : 'Ajustar quantidade e ver detalhes',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: item.isPurchased
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                    decoration: item.isPurchased
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.quantity} × ${formatCurrency(item.unitPrice)}',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formatCurrency(item.subtotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                item.category.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 9,
                  letterSpacing: .3,
                ),
              ),
            ],
          ),
        ),
        _ItemActionsMenu(readOnly: readOnly, onSelected: _handleAction),
      ],
    );
  }

  void _handleAction(_ItemAction action) {
    switch (action) {
      case _ItemAction.edit:
        onEdit();
      case _ItemAction.history:
        onViewHistory();
      case _ItemAction.delete:
        onDelete();
    }
  }
}

class _ItemActionsMenu extends StatelessWidget {
  const _ItemActionsMenu({required this.readOnly, required this.onSelected});

  final bool readOnly;
  final ValueChanged<_ItemAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return PopupMenuButton<_ItemAction>(
      tooltip: 'Mais ações',
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) => [
        if (!readOnly)
          const PopupMenuItem(
            value: _ItemAction.edit,
            child: _MenuLabel(icon: Icons.edit_rounded, text: 'Editar item'),
          ),
        const PopupMenuItem(
          value: _ItemAction.history,
          child: _MenuLabel(
            icon: Icons.query_stats_rounded,
            text: 'Histórico de preço',
          ),
        ),
        if (!readOnly) const PopupMenuDivider(),
        if (!readOnly)
          PopupMenuItem(
            value: _ItemAction.delete,
            child: _MenuLabel(
              icon: Icons.delete_outline_rounded,
              text: 'Excluir item',
              color: errorColor,
            ),
          ),
      ],
      icon: const Icon(Icons.more_horiz_rounded, size: 22),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
