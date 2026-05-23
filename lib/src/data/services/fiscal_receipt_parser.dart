import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/receipt_aliases.dart';

class FiscalReceiptParser {
  const FiscalReceiptParser();

  static final RegExp _pricePattern = RegExp(
    r'(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2}|(?:R\$\s*)?\d+,\d{2}',
    caseSensitive: false,
  );
  static final RegExp _quantityTimesUnitPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*[xX*]\s*(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})',
  );
  static final RegExp _leadingCodePattern = RegExp(
    r'^\s*(?:[A-Z]{1,4}\d{2,}|\d{1,5})[\s\-.)]+',
    caseSensitive: false,
  );
  static final RegExp _unitColumnPattern = RegExp(
    r'\b(\d{1,4})\s*(?:UN\w*|UND\w*|DPL\w*|BDJ\w*|FR\w*|CX\w*|PC\w*)\b',
    caseSensitive: false,
  );
  static final RegExp _packagePattern = RegExp(
    r'\b\d+(?:[,.]\d+)?\s*[xX]\s*\d+(?:[,.]\d+)?(?:\s*[xX]\s*\d+(?:[,.]\d+)?)?\s*(?:KG|G|ML|L|LT|UN|UND|KIT)\b',
    caseSensitive: false,
  );
  static final RegExp _compactPackagePattern = RegExp(
    r'\b\d+\s*[xX]\s*[A-Z0-9,]+(?:ML|G|KG|L|LT|M|UN|UND|KIT)\b',
    caseSensitive: false,
  );
  static final RegExp _productCodePattern = RegExp(
    r'^\s*(?:[A-Z]{1,4}\d{2,}|\d{2,5})(?:[\s\-.)]+|$)',
    caseSensitive: false,
  );
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
    'CODIGO',
    'DESCRICAO',
    'QTDE',
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
    var skipPossibleDiscountValue = false;

    for (final line in lines) {
      if (_isReceiptFooterStart(line)) {
        break;
      }
      if (_isIgnoredLine(line)) {
        pendingName = null;
        skipPossibleDiscountValue = line.toUpperCase().contains('DESCONTO');
        continue;
      }
      if (skipPossibleDiscountValue && _looksLikeDiscountValueLine(line)) {
        skipPossibleDiscountValue = false;
        continue;
      }
      skipPossibleDiscountValue = false;

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
    if (_ignoredTokens.any(upper.contains) &&
        !_productCodePattern.hasMatch(line)) {
      return null;
    }

    final quantityMatch = _quantityTimesUnitPattern.firstMatch(line);
    var quantity = 1;
    if (quantityMatch != null) {
      final rawQty = quantityMatch.group(1) ?? '1';
      final parsedQty = _parseQuantity(rawQty);
      if (parsedQty > 0) {
        quantity = parsedQty;
      }
    } else {
      final unitColumnQuantity = _parseUnitColumnQuantity(line, prices);
      if (unitColumnQuantity > 0) {
        quantity = unitColumnQuantity;
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
    value = value.replaceAll(RegExp(r'[./]+'), ' ');
    value = value.replaceAll(
      RegExp(
        r'\b\d{1,4}\s*(?:UN\w*|UND\w*|DPL\w*|BDJ\w*|FR\w*|CX\w*|PC\w*)\b.*$',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(_packagePattern, ' ');
    value = value.replaceAll(_compactPackagePattern, ' ');
    value = value.replaceAll(
      RegExp(
        r'\b\d+\s*[xX]\s*\d+(?:\s*[xX]\s*\d+)?\s*(?:KG|G|ML|L|LT|UN|UND)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    value = value.replaceAll(
      RegExp(r'\b\d+\s*[xX]\s*(?:KG|G|ML|L|LT|UN|UND)\b', caseSensitive: false),
      ' ',
    );
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

  bool _isReceiptFooterStart(String line) {
    final value = normalizeQuery(line);
    return value.startsWith('qtd total') ||
        value.startsWith('qtde total') ||
        value.startsWith('valor total') ||
        value.startsWith('valor a pagar') ||
        value.startsWith('forma de pagamento') ||
        value.startsWith('consulte pela chave') ||
        value.startsWith('nfc e no') ||
        value.startsWith('protocolo de autorizacao') ||
        value.startsWith('data de autorizacao') ||
        value.startsWith('tributos') ||
        value.startsWith('cielo') ||
        value.startsWith('valor pago');
  }

  bool _isIgnoredLine(String line) {
    final upper = line.toUpperCase();
    if (upper.contains('DESCONTO')) {
      return true;
    }
    if (_productCodePattern.hasMatch(line)) {
      return false;
    }
    return _ignoredTokens.any(upper.contains);
  }

  bool _looksLikeDiscountValueLine(String line) {
    if (_productCodePattern.hasMatch(line)) {
      return false;
    }
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    if (letters > 3) {
      return false;
    }
    return _pricePattern.hasMatch(line) || RegExp(r'\d').hasMatch(line);
  }

  int _parseUnitColumnQuantity(String line, List<RegExpMatch> prices) {
    if (prices.isEmpty) {
      return 1;
    }
    final beforeFirstPrice = line.substring(0, prices.first.start);
    final matches = _unitColumnPattern
        .allMatches(beforeFirstPrice)
        .toList(growable: false);
    if (matches.isEmpty) {
      return 1;
    }
    final raw = matches.last.group(1);
    final parsed = int.tryParse(raw ?? '');
    if (parsed == null || parsed <= 0) {
      return 1;
    }
    return parsed.clamp(1, 9999);
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
    final value = expandReceiptAliases(name);
    if (_containsAny(value, <String>[
      'leite',
      'queijo',
      'iogurte',
      'manteiga',
      'requeij',
      'qjo',
      'lactea',
      'lacteo',
      'marg',
      'margarina',
      'iog',
      'l cond',
      'condensado',
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
      'mac',
    ])) {
      return ShoppingCategory.grainsAndPasta;
    }
    if (_containsAny(value, <String>[
      'refrigerante',
      'suco',
      'agua',
      'cha',
      'chai',
      'cafe',
      'cerveja',
      'bebida',
      'refr',
      'ref',
      'rf',
      'refri',
      'pepsi',
      'coca cola',
      'fanta',
      'tubaina',
      'guara',
      'tang',
      'mupy',
      'alim soja',
    ])) {
      return ShoppingCategory.beverages;
    }
    if (_containsAny(value, <String>[
      'detergente',
      'det liq',
      'desinfetante',
      'desinf',
      'sabao',
      'amaciante',
      'limpeza',
      'lava',
      'limp',
      'esponja',
      'harpic',
      'pato germ',
      'pinho',
      'toalha papel',
    ])) {
      return ShoppingCategory.cleaning;
    }
    if (_containsAny(value, <String>[
      'shampoo',
      'shamp',
      'shampcond',
      'sabonete',
      'sab',
      'dove',
      'desod',
      'abs',
      'absorvente',
      'creme dental',
      'cr d',
      'pasta dental',
      'escova',
      'hastes',
      'higiene',
      'papel hig',
    ])) {
      return ShoppingCategory.personalCare;
    }
    if (_containsAny(value, <String>[
      'frango',
      'carne',
      'bovino',
      'suino',
      'linguica',
      'ling',
      'calab',
      'bacon',
      'salsicha',
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
      'bisc',
      'torrada',
      'padaria',
    ])) {
      return ShoppingCategory.bakery;
    }
    if (_containsAny(value, <String>['salg', 'chips', 'batata palha'])) {
      return ShoppingCategory.snacks;
    }
    if (_containsAny(value, <String>['polpa', 'congelado', 'congelada'])) {
      return ShoppingCategory.frozen;
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
      'cheiro verde',
    ])) {
      return ShoppingCategory.produce;
    }
    if (_containsAny(value, <String>[
      'chocolate',
      'doce',
      'sobremesa',
      'bala',
      'bombom',
      'pacoca',
      'choc',
      'chocolate po',
    ])) {
      return ShoppingCategory.sweets;
    }
    if (_containsAny(value, <String>['azeite', 'louro', 'folha louro'])) {
      return ShoppingCategory.condiments;
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
      if (token.contains(' ')) {
        if (value.contains(token)) {
          return true;
        }
        continue;
      }
      if (token.length <= 3) {
        if (RegExp('(?:^| )${RegExp.escape(token)}(?: |\$)').hasMatch(value)) {
          return true;
        }
        continue;
      }
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
