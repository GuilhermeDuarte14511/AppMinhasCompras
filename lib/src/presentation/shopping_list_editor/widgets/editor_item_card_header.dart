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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final secondaryColor = item.isPurchased
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.78)
        : colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
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
        const SizedBox(width: 2),
        Expanded(
          child: Semantics(
            button: true,
            expanded: expanded,
            label: item.name,
            value:
                '${item.isPurchased ? 'Comprado' : 'Pendente'}, '
                '${item.category.label}, ${item.quantity} unidades, '
                '${formatCurrency(item.subtotal)}',
            hint: expanded
                ? 'Recolher detalhes'
                : readOnly
                ? 'Ver detalhes'
                : 'Ajustar quantidade e ver detalhes',
            onTap: onToggleExpanded,
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: item.isPurchased
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    decoration: item.isPurchased
                        ? TextDecoration.lineThrough
                        : null,
                    decorationThickness: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item.category.label} • ${item.quantity} × ${formatCurrency(item.unitPrice)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 70, maxWidth: 86),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ExcludeSemantics(
                child: SizedBox(
                  width: 86,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatCurrency(item.subtotal),
                      maxLines: 1,
                      softWrap: false,
                      style: textTheme.titleSmall?.copyWith(
                        color: item.isPurchased
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: motionDuration,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: secondaryColor,
                      ),
                    ),
                  ),
                  _ItemActionsMenu(
                    readOnly: readOnly,
                    onSelected: _handleAction,
                  ),
                ],
              ),
            ],
          ),
        ),
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
