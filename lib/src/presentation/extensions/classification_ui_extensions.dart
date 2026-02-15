import 'package:flutter/material.dart';

import '../../domain/classifications.dart';

extension ShoppingCategoryIcons on ShoppingCategory {
  IconData get icon {
    switch (this) {
      case ShoppingCategory.produce:
        return Icons.eco_rounded;
      case ShoppingCategory.bakery:
        return Icons.bakery_dining_rounded;
      case ShoppingCategory.meat:
        return Icons.set_meal_rounded;
      case ShoppingCategory.seafood:
        return Icons.phishing_rounded;
      case ShoppingCategory.dairy:
        return Icons.icecream_rounded;
      case ShoppingCategory.eggs:
        return Icons.egg_alt_rounded;
      case ShoppingCategory.grainsAndPasta:
        return Icons.rice_bowl_rounded;
      case ShoppingCategory.frozen:
        return Icons.ac_unit_rounded;
      case ShoppingCategory.snacks:
        return Icons.cookie_rounded;
      case ShoppingCategory.sweets:
        return Icons.cake_rounded;
      case ShoppingCategory.condiments:
        return Icons.soup_kitchen_rounded;
      case ShoppingCategory.grocery:
        return Icons.inventory_2_rounded;
      case ShoppingCategory.beverages:
        return Icons.local_drink_rounded;
      case ShoppingCategory.cleaning:
        return Icons.cleaning_services_rounded;
      case ShoppingCategory.personalCare:
        return Icons.health_and_safety_rounded;
      case ShoppingCategory.baby:
        return Icons.child_friendly_rounded;
      case ShoppingCategory.pet:
        return Icons.pets_rounded;
      case ShoppingCategory.other:
        return Icons.category_rounded;
    }
  }
}

extension ItemSortOptionIcons on ItemSortOption {
  IconData get icon {
    switch (this) {
      case ItemSortOption.defaultOrder:
        return Icons.schedule_rounded;
      case ItemSortOption.nameAsc:
        return Icons.sort_by_alpha_rounded;
      case ItemSortOption.nameDesc:
        return Icons.sort_by_alpha_rounded;
      case ItemSortOption.valueAsc:
        return Icons.south_rounded;
      case ItemSortOption.valueDesc:
        return Icons.north_rounded;
    }
  }
}
