import 'package:flutter/material.dart';

import '../../../domain/models_and_utils.dart';
import '../../utils/app_modal.dart';

enum ItemAction { edit, duplicate, delete }

Future<ItemAction?> showItemActionsSheet(
  BuildContext context, {
  required ShoppingItem item,
}) {
  final theme = Theme.of(context);
  return showAppModalBottomSheet<ItemAction>(
    context: context,
    backgroundColor: theme.colorScheme.surfaceContainerLowest,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    barrierLabel: 'Fechar ações de ${item.name}',
    elevation: 0,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    showDragHandle: false,
    useSafeArea: true,
    isScrollControlled: true,
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ItemActionsSheet(item: item),
  );
}

/// Returns an action without mutating the item or bypassing editor safeguards.
class ItemActionsSheet extends StatelessWidget {
  const ItemActionsSheet({super.key, required this.item});

  final ShoppingItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 32),
        child: Semantics(
          container: true,
          label: 'Ações de ${item.name}',
          child: SingleChildScrollView(
            key: const ValueKey('item_actions_scroll'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: SizedBox(
                    width: 36,
                    height: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                for (final action in ItemAction.values) ...[
                  if (action != ItemAction.edit)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ListTile(
                    minTileHeight: 64,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    horizontalTitleGap: 16,
                    leading: Icon(
                      switch (action) {
                        ItemAction.edit => Icons.edit_outlined,
                        ItemAction.duplicate => Icons.content_copy_outlined,
                        ItemAction.delete => Icons.delete_outline,
                      },
                      size: 24,
                      color: action == ItemAction.delete
                          ? colors.error
                          : colors.onSurfaceVariant,
                    ),
                    title: Text(
                      switch (action) {
                        ItemAction.edit => 'Editar item',
                        ItemAction.duplicate => 'Duplicar item',
                        ItemAction.delete => 'Excluir item',
                      },
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: action == ItemAction.delete
                            ? colors.error
                            : colors.onSurface,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, action),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
