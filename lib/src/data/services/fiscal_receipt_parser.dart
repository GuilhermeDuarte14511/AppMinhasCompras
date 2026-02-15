import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class FiscalReceiptParser {
  const FiscalReceiptParser();

  static final RegExp _pricePattern = RegExp(
    r'(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2}|(?:R\$\s*)?\d+,\d{2}',
    caseSensitive: false,
  );
  static final RegExp _quantityTimesUnitPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*[xX*]\s*(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})',
  );
  static final RegExp _leadingCodePattern = RegExp(r'^\s*\d{1,5}[\s\-.)]+');
  static final RegExp _separatorSpacesPattern = RegExp(r'\s+');
  static final RegExp _onlySymbolsPattern = RegExp(r'[^A-Za-z0-9]+');

  static const Set<String> _ignoredTokens = <String>{
    'CUPOM',
    'FISCAL',
    'NFC-E',
    'CF-E',
    'SAT',
    'CNPJ',
    'CPF',
    'NCM',
    'CHAVE',
    'ACESSO',
    'EMISSAO',
    'DATA',
    'HORA',
    'CAIXA',
    'OPERADOR',
    'TRIBUTOS',
    'ICMS',
    'TOTAL',
    'SUBTOTAL',
    'DESCONTO',
    'ACRESCIMO',
    'TROCO',
    'PAGAMENTO',
    'DINHEIRO',
    'CARTAO',
    'CREDITO',
    'DEBITO',
    'PIX',
    'TEF',
    'VIA',
    'CONSUMIDOR',
  };

  List<ShoppingItemDraft> parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final merged = <String, _MergeAccumulator>{};
    final order = <String>[];
    String? pendingName;

    for (final line in lines) {
      final prices = _pricePattern.allMatches(line).toList(growable: false);
      if (prices.isEmpty) {
        if (_looksLikeNameLine(line)) {
          pendingName = line;
        }
        continue;
      }

      final parsed = _parseLineWithPrice(
        line,
        prices,
        pendingName: pendingName,
      );
      pendingName = null;
      if (parsed == null) {
        continue;
      }

      final key = normalizeQuery(parsed.name);
      if (key.isEmpty) {
        continue;
      }
      final existing = merged[key];
      if (existing == null) {
        merged[key] = _MergeAccumulator(
          name: parsed.name,
          category: parsed.category,
          quantity: parsed.quantity,
          totalValue: parsed.quantity * parsed.unitPrice,
        );
        order.add(key);
      } else {
        merged[key] = existing.copyWith(
          quantity: existing.quantity + parsed.quantity,
          totalValue:
              existing.totalValue + (parsed.quantity * parsed.unitPrice),
        );
      }
    }

    final drafts = <ShoppingItemDraft>[];
    for (final key in order) {
      final entry = merged[key]!;
      final qty = entry.quantity <= 0 ? 1 : entry.quantity;
      final unitPrice = qty > 0 ? (entry.totalValue / qty) : 0.0;
      if (unitPrice <= 0 || entry.name.trim().isEmpty) {
        continue;
      }
      drafts.add(
        ShoppingItemDraft(
          name: entry.name.trim(),
          quantity: qty,
          unitPrice: unitPrice,
          category: entry.category,
        ),
      );
    }
    return List.unmodifiable(drafts);
  }

  _ParsedReceiptItem? _parseLineWithPrice(
    String line,
    List<RegExpMatch> prices, {
    String? pendingName,
  }) {
    final upper = line.toUpperCase();
    if (_ignoredTokens.any(upper.contains)) {
      final hasExplicitName =
          pendingName != null && pendingName.trim().isNotEmpty;
      if (!hasExplicitName) {
        final itemWord = upper.contains('ITEM');
        if (!itemWord) {
          return null;
        }
      }
    }

    final quantityMatch = _quantityTimesUnitPattern.firstMatch(line);
    var quantity = 1;
    if (quantityMatch != null) {
      final rawQty = quantityMatch.group(1) ?? '1';
      final parsedQty = _parseQuantity(rawQty);
      if (parsedQty > 0) {
        quantity = parsedQty;
      }
    }

    final lastPriceToken = prices.last.group(0);
    final totalValue = _parseBrlNumber(lastPriceToken);
    if (totalValue == null || totalValue <= 0) {
      return null;
    }

    final baseName = _extractNameFromLine(
      line,
      firstPriceStart: prices.first.start,
      quantityMatch: quantityMatch,
    );
    var finalName = baseName;
    if (finalName.isEmpty && pendingName != null) {
      finalName = _cleanupName(pendingName);
    }
    if (finalName.isEmpty) {
      return null;
    }

    final unitPrice = quantity > 0 ? totalValue / quantity : totalValue;
    if (unitPrice <= 0) {
      return null;
    }

    return _ParsedReceiptItem(
      name: finalName,
      quantity: quantity,
      unitPrice: unitPrice,
      category: _inferCategory(finalName),
    );
  }

  String _extractNameFromLine(
    String line, {
    required int firstPriceStart,
    RegExpMatch? quantityMatch,
  }) {
    final end = quantityMatch?.start ?? firstPriceStart;
    final raw = end > 0 ? line.substring(0, end) : line;
    return _cleanupName(raw);
  }

  String _cleanupName(String raw) {
    var value = raw.replaceAll(_leadingCodePattern, '').trim();
    value = value.replaceAll(
      RegExp(
        r'\b(?:UN|UND|UNID|KG|G|GR|L|LT|ML|PC|PCT|PAC|CX|FD)\b\.?$',
        caseSensitive: false,
      ),
      '',
    );
    value = value.replaceAll(
      RegExp(r'^\s*(?:ITEM|ITM)\s*[:\-]?\s*', caseSensitive: false),
      '',
    );
    value = value.replaceAll(_separatorSpacesPattern, ' ').trim();
    if (value.length < 3) {
      return '';
    }
    final onlySymbols = value.replaceAll(_onlySymbolsPattern, '');
    if (onlySymbols.length < 3) {
      return '';
    }
    return value;
  }

  bool _looksLikeNameLine(String line) {
    final upper = line.toUpperCase();
    if (_ignoredTokens.any(upper.contains)) {
      return false;
    }
    final hasDigits = RegExp(r'\d').hasMatch(line);
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    if (letters < 3) {
      return false;
    }
    if (hasDigits && letters < 6) {
      return false;
    }
    return true;
  }

  int _parseQuantity(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return 1;
    }
    return parsed.round().clamp(1, 9999);
  }

  double? _parseBrlNumber(String? raw) {
    if (raw == null) {
      return null;
    }
    final normalized = raw
        .replaceAll(RegExp(r'[^0-9,\.]'), '')
        .replaceAll('.', '')
        .replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  ShoppingCategory _inferCategory(String name) {
    final value = normalizeQuery(name);
    if (_containsAny(value, <String>[
      'leite',
      'queijo',
      'iogurte',
      'manteiga',
      'requeij',
    ])) {
      return ShoppingCategory.dairy;
    }
    if (_containsAny(value, <String>['ovo'])) {
      return ShoppingCategory.eggs;
    }
    if (_containsAny(value, <String>[
      'arroz',
      'feijao',
      'macarrao',
      'massa',
      'farinha',
      'acucar',
      'sal',
      'grao',
    ])) {
      return ShoppingCategory.grainsAndPasta;
    }
    if (_containsAny(value, <String>[
      'refrigerante',
      'suco',
      'agua',
      'cha',
      'cafe',
      'cerveja',
      'bebida',
    ])) {
      return ShoppingCategory.beverages;
    }
    if (_containsAny(value, <String>[
      'detergente',
      'desinfetante',
      'sabao',
      'amaciante',
      'limpeza',
      'lava',
    ])) {
      return ShoppingCategory.cleaning;
    }
    if (_containsAny(value, <String>[
      'shampoo',
      'sabonete',
      'creme dental',
      'pasta dental',
      'escova',
      'higiene',
    ])) {
      return ShoppingCategory.personalCare;
    }
    if (_containsAny(value, <String>[
      'frango',
      'carne',
      'bovino',
      'suino',
      'linguica',
    ])) {
      return ShoppingCategory.meat;
    }
    if (_containsAny(value, <String>['peixe', 'atum', 'sardinha', 'salmao'])) {
      return ShoppingCategory.seafood;
    }
    if (_containsAny(value, <String>[
      'pao',
      'bolo',
      'biscoito',
      'torrada',
      'padaria',
    ])) {
      return ShoppingCategory.bakery;
    }
    if (_containsAny(value, <String>[
      'banana',
      'maca',
      'tomate',
      'batata',
      'cebola',
      'alface',
      'fruta',
      'verdura',
      'legume',
    ])) {
      return ShoppingCategory.produce;
    }
    if (_containsAny(value, <String>[
      'chocolate',
      'doce',
      'sobremesa',
      'bala',
      'bombom',
    ])) {
      return ShoppingCategory.sweets;
    }
    if (_containsAny(value, <String>['racao', 'pet'])) {
      return ShoppingCategory.pet;
    }
    return ShoppingCategory.grocery;
  }

  String _normalizeLine(String line) {
    return line
        .replaceAll('\t', ' ')
        .replaceAll(_separatorSpacesPattern, ' ')
        .trim();
  }

  bool _containsAny(String value, List<String> tokens) {
    for (final token in tokens) {
      if (value.contains(token)) {
        return true;
      }
    }
    return false;
  }
}

class _ParsedReceiptItem {
  const _ParsedReceiptItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.category,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final ShoppingCategory category;
}

class _MergeAccumulator {
  const _MergeAccumulator({
    required this.name,
    required this.category,
    required this.quantity,
    required this.totalValue,
  });

  final String name;
  final ShoppingCategory category;
  final int quantity;
  final double totalValue;

  _MergeAccumulator copyWith({
    String? name,
    ShoppingCategory? category,
    int? quantity,
    double? totalValue,
  }) {
    return _MergeAccumulator(
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      totalValue: totalValue ?? this.totalValue,
    );
  }
}
