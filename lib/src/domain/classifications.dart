enum ShoppingCategory {
  produce,
  bakery,
  meat,
  seafood,
  dairy,
  eggs,
  grainsAndPasta,
  frozen,
  snacks,
  sweets,
  condiments,
  grocery,
  beverages,
  cleaning,
  personalCare,
  baby,
  pet,
  other,
}

extension ShoppingCategoryMetadata on ShoppingCategory {
  String get key {
    switch (this) {
      case ShoppingCategory.produce:
        return 'produce';
      case ShoppingCategory.bakery:
        return 'bakery';
      case ShoppingCategory.meat:
        return 'meat';
      case ShoppingCategory.seafood:
        return 'seafood';
      case ShoppingCategory.dairy:
        return 'dairy';
      case ShoppingCategory.eggs:
        return 'eggs';
      case ShoppingCategory.grainsAndPasta:
        return 'grains_pasta';
      case ShoppingCategory.frozen:
        return 'frozen';
      case ShoppingCategory.snacks:
        return 'snacks';
      case ShoppingCategory.sweets:
        return 'sweets';
      case ShoppingCategory.condiments:
        return 'condiments';
      case ShoppingCategory.grocery:
        return 'grocery';
      case ShoppingCategory.beverages:
        return 'beverages';
      case ShoppingCategory.cleaning:
        return 'cleaning';
      case ShoppingCategory.personalCare:
        return 'personal_care';
      case ShoppingCategory.baby:
        return 'baby';
      case ShoppingCategory.pet:
        return 'pet';
      case ShoppingCategory.other:
        return 'other';
    }
  }

  String get label {
    switch (this) {
      case ShoppingCategory.produce:
        return 'Hortifruti';
      case ShoppingCategory.bakery:
        return 'Padaria';
      case ShoppingCategory.meat:
        return 'Carnes';
      case ShoppingCategory.seafood:
        return 'Peixes e frutos do mar';
      case ShoppingCategory.dairy:
        return 'Laticinios';
      case ShoppingCategory.eggs:
        return 'Ovos';
      case ShoppingCategory.grainsAndPasta:
        return 'Graos e massas';
      case ShoppingCategory.frozen:
        return 'Congelados';
      case ShoppingCategory.snacks:
        return 'Snacks';
      case ShoppingCategory.sweets:
        return 'Doces e sobremesas';
      case ShoppingCategory.condiments:
        return 'Molhos e temperos';
      case ShoppingCategory.grocery:
        return 'Mercearia';
      case ShoppingCategory.beverages:
        return 'Bebidas';
      case ShoppingCategory.cleaning:
        return 'Limpeza';
      case ShoppingCategory.personalCare:
        return 'Higiene';
      case ShoppingCategory.baby:
        return 'Bebe';
      case ShoppingCategory.pet:
        return 'Pet';
      case ShoppingCategory.other:
        return 'Outros';
    }
  }

  int get marketOrder {
    switch (this) {
      case ShoppingCategory.produce:
        return 1;
      case ShoppingCategory.bakery:
        return 2;
      case ShoppingCategory.meat:
        return 3;
      case ShoppingCategory.seafood:
        return 4;
      case ShoppingCategory.dairy:
        return 5;
      case ShoppingCategory.eggs:
        return 6;
      case ShoppingCategory.grainsAndPasta:
        return 7;
      case ShoppingCategory.frozen:
        return 8;
      case ShoppingCategory.snacks:
        return 9;
      case ShoppingCategory.sweets:
        return 10;
      case ShoppingCategory.condiments:
        return 11;
      case ShoppingCategory.grocery:
        return 12;
      case ShoppingCategory.beverages:
        return 13;
      case ShoppingCategory.cleaning:
        return 14;
      case ShoppingCategory.personalCare:
        return 15;
      case ShoppingCategory.baby:
        return 16;
      case ShoppingCategory.pet:
        return 17;
      case ShoppingCategory.other:
        return 18;
    }
  }
}

class ShoppingCategoryParser {
  static ShoppingCategory fromKey(String? key) {
    for (final category in ShoppingCategory.values) {
      if (category.key == key) {
        return category;
      }
    }
    return ShoppingCategory.other;
  }
}

enum ItemSortOption { defaultOrder, nameAsc, nameDesc, valueAsc, valueDesc }

extension ItemSortOptionLabels on ItemSortOption {
  String get label {
    switch (this) {
      case ItemSortOption.defaultOrder:
        return 'Ordem de cadastro';
      case ItemSortOption.nameAsc:
        return 'Nome: A-Z';
      case ItemSortOption.nameDesc:
        return 'Nome: Z-A';
      case ItemSortOption.valueAsc:
        return 'Valor: menor primeiro';
      case ItemSortOption.valueDesc:
        return 'Valor: maior primeiro';
    }
  }

  String get shortLabel {
    switch (this) {
      case ItemSortOption.defaultOrder:
        return 'Padrão';
      case ItemSortOption.nameAsc:
        return 'Nome A-Z';
      case ItemSortOption.nameDesc:
        return 'Nome Z-A';
      case ItemSortOption.valueAsc:
        return 'Menor valor';
      case ItemSortOption.valueDesc:
        return 'Maior valor';
    }
  }
}
