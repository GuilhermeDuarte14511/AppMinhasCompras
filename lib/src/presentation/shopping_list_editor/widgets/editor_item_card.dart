import 'package:flutter/material.dart';

import '../../../domain/models_and_utils.dart';
import '../../theme/app_tokens.dart';
import 'editor_item_card_details.dart';
import 'editor_item_card_header.dart';

Duration _itemCardMotionDuration(BuildContext context, Duration fallback) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return Duration.zero;
  }
  return fallback;
}

class EditorShoppingItemCard extends StatelessWidget {
  const EditorShoppingItemCard({
    super.key,
    required this.item,
    this.readOnly = false,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPurchasedChanged,
    required this.onIncrement,
    required this.onDecrement,
    required this.onEdit,
    required this.onViewHistory,
    required this.onDelete,
  });

  final ShoppingItem item;
  final bool readOnly;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onPurchasedChanged;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onEdit;
  final VoidCallback onViewHistory;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final motionDuration = _itemCardMotionDuration(
      context,
      AppTokens.motionFast,
    );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: AnimatedContainer(
        duration: motionDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: item.isPurchased
              ? colorScheme.surfaceContainerLow
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
              child: Column(
                children: [
                  EditorItemCardHeader(
                    item: item,
                    readOnly: readOnly,
                    expanded: expanded,
                    motionDuration: motionDuration,
                    onToggleExpanded: onToggleExpanded,
                    onPurchasedChanged: onPurchasedChanged,
                    onEdit: onEdit,
                    onViewHistory: onViewHistory,
                    onDelete: onDelete,
                  ),
                  AnimatedSize(
                    duration: motionDuration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: expanded
                        ? EditorItemCardDetails(
                            item: item,
                            readOnly: readOnly,
                            onIncrement: onIncrement,
                            onDecrement: onDecrement,
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
