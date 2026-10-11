import 'package:flutter/material.dart';

import '../../../domain/classifications.dart';
import '../../extensions/classification_ui_extensions.dart';

class ItemEditorCategoryPicker extends StatelessWidget {
  const ItemEditorCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final ShoppingCategory value;
  final ValueChanged<ShoppingCategory> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enlarged = MediaQuery.textScalerOf(context).scale(12) / 12;
    final categories = {
      ShoppingCategory.grocery,
      ShoppingCategory.produce,
      ShoppingCategory.dairy,
      ShoppingCategory.bakery,
      ShoppingCategory.meat,
      ShoppingCategory.cleaning,
      ShoppingCategory.beverages,
      ShoppingCategory.personalCare,
      ...ShoppingCategory.values,
    }.toList();
    return SizedBox(
      height: 100 * enlarged.clamp(1.0, 2.0),
      child: GridView.builder(
        scrollDirection: Axis.horizontal,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 108 * enlarged.clamp(1.0, 2.0),
          mainAxisSpacing: 6,
          crossAxisSpacing: 4,
        ),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Tooltip(
            message: category.label,
            child: ChoiceChip(
              key: ValueKey('item_category_${category.key}'),
              selected: value == category,
              showCheckmark: false,
              avatar: Icon(category.icon, size: 14),
              label: Text(
                category.label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
              onSelected: (_) => onChanged(category),
            ),
          );
        },
      ),
    );
  }
}
