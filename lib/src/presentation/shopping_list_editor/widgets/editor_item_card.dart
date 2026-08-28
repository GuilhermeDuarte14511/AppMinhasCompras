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
      child: Card(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        child: AnimatedContainer(
          duration: motionDuration,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: item.isPurchased
                ? colorScheme.surfaceContainerHigh
                : colorScheme.surface,
            border: Border.all(
              color: item.isPurchased
                  ? colorScheme.primary.withValues(alpha: 0.32)
                  : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              excludeFromSemantics: true,
              onTap: onToggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 6, 8),
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
      ),
    );
  }
}
