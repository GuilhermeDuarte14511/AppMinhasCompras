import 'package:flutter/material.dart';

import '../../core/utils/format_utils.dart';
import '../../data/remote/shared_lists_repository.dart';
import '../../domain/models_and_utils.dart';

enum _LedgerAction { reopen, template, delete, shared }

class ListLedgerRow extends StatelessWidget {
  const ListLedgerRow({
    super.key,
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
  final bool selectionMode, isSelected;
  final VoidCallback onToggleSelection,
      onLongPress,
      onOpen,
      onReopen,
      onCreateFromThis,
      onDelete;
  final VoidCallback? onOpenShared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final progress = list.items.isEmpty
        ? 0.0
        : list.purchasedItemsCount / list.items.length;
    final spent = list.items
        .where((item) => item.isPurchased)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
    final shared = sharedSummary;
    return Semantics(
      container: true,
      button: true,
      selected: selectionMode ? isSelected : null,
      label: '${selectionMode ? 'Selecionar' : 'Abrir'} ${list.name}',
      child: InkWell(
        onTap: selectionMode ? onToggleSelection : onOpen,
        onLongPress: onLongPress,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selectionMode && isSelected
                ? colors.primary.withValues(alpha: .12)
                : null,
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectionMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggleSelection(),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _Status(list.isClosed ? 'Fechada' : 'Aberta'),
                            if (shared != null) _Status('Compartilhada'),
                            Text(
                              'Atualizada em ${formatShortDate(list.updatedAt)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          list.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: list.isClosed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!selectionMode)
                    PopupMenuButton<_LedgerAction>(
                      tooltip: 'Opções da lista',
                      icon: const Icon(Icons.more_horiz, size: 18),
                      padding: EdgeInsets.zero,
                      onSelected: (action) {
                        switch (action) {
                          case _LedgerAction.reopen:
                            onReopen();
                          case _LedgerAction.template:
                            onCreateFromThis();
                          case _LedgerAction.delete:
                            onDelete();
                          case _LedgerAction.shared:
                            onOpenShared?.call();
                        }
                      },
                      itemBuilder: (context) => [
                        if (list.isClosed)
                          const PopupMenuItem(
                            value: _LedgerAction.reopen,
                            child: Text('Reabrir lista'),
                          ),
                        const PopupMenuItem(
                          value: _LedgerAction.template,
                          child: Text('Criar Baseada Nesta'),
                        ),
                        if (shared != null)
                          const PopupMenuItem(
                            value: _LedgerAction.shared,
                            child: Text('Abrir compartilhamento'),
                          ),
                        const PopupMenuItem(
                          value: _LedgerAction.delete,
                          child: Text('Excluir lista'),
                        ),
                      ],
                    ),
                ],
              ),
              if (shared != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: TextButton(
                    onPressed: onOpenShared,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    child: Text(
                      '${shared.isOwner(currentUserUid ?? '') ? 'Dono' : 'Membro'} · ${formatCountLabel(shared.memberCount, 'membro', 'membros')}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        color: const Color(0xFF365943),
                        backgroundColor: colors.surfaceContainerLow,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${list.purchasedItemsCount} de ${formatItemCount(list.items.length)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                color: colors.outlineVariant.withValues(alpha: .4),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    'Previsto: ${formatCurrency(list.totalValue)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  Text(
                    formatUnitCount(list.totalItems),
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  Text(
                    'Gasto: ${formatCurrency(spent)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.primary,
                    ),
                  ),
                  if (list.hasBudget)
                    Text(
                      'Teto: ${formatCurrency(list.budget!)}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                ],
              ),
              if (selectionMode)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    isSelected ? 'Selecionada' : 'Toque para selecionar',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF444939)
          : const Color(0xFFE0E5CF),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
    ),
  );
}
