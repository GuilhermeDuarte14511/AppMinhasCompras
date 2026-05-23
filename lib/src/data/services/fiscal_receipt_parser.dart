import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';
import '../../domain/receipt_aliases.dart';

class FiscalReceiptParser {
  const FiscalReceiptParser();

  static final RegExp _pricePattern = RegExp(
    r'(?:R\$\s*)?\d{1,3}(?:\.\d{3})*,\d{2}(?!\d)|(?:R\$\s*)?\d+,\d{2}(?!\d)',
    caseSensitive: false,
  );
  static final RegExp _quantityTimesUnitPattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(?:K[GR]?\d?|KG|G)?\s*[xX*]\s*(?:R\$\s*)?(\d{1,3}(?:\.\d{3})*,\d{2}|\d+,\d{2})',
    caseSensitive: false,
  );
  static final RegExp _leadingCodePattern = RegExp(
    r'^\s*(?:[A-Z]{1,4}(?=[A-Z0-9$]*\d)[A-Z0-9$]{2,}|\d{1,5})[\s\-.)]+',
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
    r'^\s*(?:[A-Z]{1,4}(?=[A-Z0-9$]*\d)[A-Z0-9$]{2,}|\d{2,5})(?:[\s\-.)]+|$)',
    caseSensitive: false,
  );
  static final RegExp _structuredProductPattern = RegExp(
    r'^\s*(.+?)\s*\(Código:\s*([A-Z]{1,4}\d+)\s*\)',
    caseSensitive: false,
  );
  static final RegExp _structuredQuantityPattern = RegExp(
    r'Qtde\.:\s*([\d,.]+).*?Vl\. Unit\.:\s*([\d,.]+)',
    caseSensitive: false,
  );
  static final RegExp _splitKiloContinuationPattern = RegExp(
    r'^\s*\d+[,.]\d+\s*K[GR]?\d?\s*[xX]\s*\d+(?:[,.]\d+)?\s*$',
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
    final sourceLines = rawText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final structuredItems = _parseStructuredNfceItems(sourceLines);
    if (structuredItems.isNotEmpty) {
      return _draftsFromParsedItems(structuredItems);
    }

    final lines = _prepareOcrLines(sourceLines);
    final parsedItems = <_ParsedReceiptItem>[];

    for (final line in lines) {
      if (_isReceiptFooterStart(line)) {
        break;
      }
      if (_isIgnoredLine(line)) {
        continue;
      }

      final prices = _pricePattern.allMatches(line).toList(growable: false);
      if (prices.isEmpty) {
        continue;
      }

      final parsed = _parseLineWithPrice(line, prices);
      if (parsed != null) {
        parsedItems.add(parsed);
      }
    }

    return _draftsFromParsedItems(parsedItems);
  }

  List<ShoppingItemDraft> _draftsFromParsedItems(
    List<_ParsedReceiptItem> parsedItems,
  ) {
    final merged = <String, _MergeAccumulator>{};
    final order = <String>[];

    for (final parsed in parsedItems) {
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

  List<_ParsedReceiptItem> _parseStructuredNfceItems(List<String> lines) {
    final parsedItems = <_ParsedReceiptItem>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_isReceiptFooterStart(line)) {
        break;
      }
      final productMatch = _structuredProductPattern.firstMatch(line);
      if (productMatch == null || i + 1 >= lines.length) {
        continue;
      }

      final quantityLine = lines[i + 1];
      final quantityMatch = _structuredQuantityPattern.firstMatch(quantityLine);
      if (quantityMatch == null) {
        continue;
      }

      final rawQuantity = quantityMatch.group(1) ?? '1';
      final rawUnitPrice = quantityMatch.group(2);
      final quantityValue = _parseBrlNumber(rawQuantity) ?? 1;
      final unitPriceValue = _parseBrlNumber(rawUnitPrice) ?? 0;
      var totalValue = quantityValue * unitPriceValue;
      if (i + 2 < lines.length && _isStandalonePriceLine(lines[i + 2])) {
        totalValue = _parseBrlNumber(lines[i + 2]) ?? totalValue;
        i += 2;
      } else {
        i += 1;
      }

      final quantity = _isWeightedSaleLine(quantityLine)
          ? 1
          : _quantityForReceipt(quantityValue);
      final finalName = _cleanupName(productMatch.group(1) ?? '');
      if (finalName.isEmpty || totalValue <= 0) {
        continue;
      }

      parsedItems.add(
        _ParsedReceiptItem(
          name: finalName,
          quantity: quantity,
          unitPrice: totalValue / quantity,
          category: _inferCategory(finalName),
        ),
      );
    }

    return parsedItems;
  }

  List<String> _prepareOcrLines(List<String> lines) {
    final prepared = <String>[];
    final consumedIndexes = <int>{};

    for (var i = 0; i < lines.length; i++) {
      if (consumedIndexes.contains(i)) {
        continue;
      }
      final line = lines[i];
      if (_isDetachedPriceDetailLine(line) ||
          _isSplitKiloContinuationLine(line) ||
          _isStandalonePriceLine(line) ||
          _isDiscountNoiseLine(line)) {
        continue;
      }

      if (!_pricePattern.hasMatch(line) && _looksLikeProductNameLine(line)) {
        final mergedLine = _mergeWithDetachedPriceDetail(lines, i);
        if (mergedLine != null) {
          prepared.add(mergedLine.line);
          consumedIndexes.add(mergedLine.consumedIndex);
        }
        continue;
      }

      if (_isProductWeightLineMissingTotal(line)) {
        var mergedLine = line;
        for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
          final candidate = lines[j];
          if (_isDetachedPriceDetailLine(candidate)) {
            mergedLine = '$line $candidate';
            consumedIndexes.add(j);
            break;
          }
          if (_isSplitKiloContinuationLine(candidate)) {
            consumedIndexes.add(j);
            continue;
          }
          if (_isStandalonePriceLine(candidate)) {
            mergedLine = '$line $candidate';
            consumedIndexes.add(j);
            break;
          }
        }
        prepared.add(mergedLine);
        continue;
      }

      prepared.add(line);
    }

    return prepared;
  }

  _MergedOcrLine? _mergeWithDetachedPriceDetail(List<String> lines, int index) {
    for (var j = index + 1; j < lines.length && j <= index + 2; j++) {
      final candidate = lines[j];
      if (_isIgnoredLine(candidate)) {
        continue;
      }
      if (_isDetachedPriceDetailLine(candidate)) {
        return _MergedOcrLine('${lines[index]} $candidate', j);
      }
    }
    return null;
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
    double? rawQuantityValue;
    if (quantityMatch != null) {
      final rawQty = quantityMatch.group(1) ?? '1';
      rawQuantityValue = _parseBrlNumber(rawQty);
      if (!_isWeightedSaleLine(line)) {
        final parsedQty = _parseQuantity(rawQty);
        if (parsedQty > 0) {
          quantity = parsedQty;
        }
      }
    } else {
      final unitColumnQuantity = _parseUnitColumnQuantity(line, prices);
      if (unitColumnQuantity > 0) {
        quantity = unitColumnQuantity;
      }
    }

    final lastPriceToken = prices.last.group(0);
    var totalValue = _parseBrlNumber(lastPriceToken);
    if (_isKiloPriceWithoutTotal(line, prices, quantityMatch)) {
      final quantityValue = rawQuantityValue ?? 1;
      final unitValue = _parseBrlNumber(quantityMatch?.group(2));
      if (unitValue != null && unitValue > 0) {
        totalValue = quantityValue * unitValue;
      }
    }
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
    value = value.replaceAllMapped(
      RegExp(r'([A-Za-z])\d\b'),
      (match) => match.group(1) ?? '',
    );
    value = value.replaceAll(
      RegExp(r'\bCODIG\w*\s+DESCR\w*.*$', caseSensitive: false),
      ' ',
    );
    value = value.replaceAll(
      RegExp(r'\b\d+[,.]\d+\s*K\w*\b.*$', caseSensitive: false),
      ' ',
    );
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
        r'\b(?:UN|UND|UNID|ND|KG|G|GR|L|LT|ML|PC|PCT|PAC|CX|FD)\d?\b\.?$',
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
    final normalized = normalizeQuery(line);
    if (normalized.startsWith('cnpj') ||
        normalized.startsWith('cnp j') ||
        normalized.startsWith('wms supermercados') ||
        normalized.startsWith('est estrada') ||
        normalized.startsWith('documento auxiliar') ||
        normalized.startsWith('tocunento auxiliar') ||
        normalized.startsWith('mao e docunento') ||
        normalized.startsWith('nao e documento') ||
        normalized.startsWith('filtrar itens') ||
        normalized.startsWith('codigo descricao') ||
        normalized.startsWith('codigt')) {
      return true;
    }
    final upper = line.toUpperCase();
    if (upper.contains('DESCONTO')) {
      return true;
    }
    if (_productCodePattern.hasMatch(line)) {
      return false;
    }
    return _ignoredTokens.any(upper.contains);
  }

  bool _isDiscountNoiseLine(String line) {
    if (_productCodePattern.hasMatch(line)) {
      return false;
    }
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    return letters <= 3 &&
        RegExp(r'^\s*\d+[,.]\d+\s*[xX]\w*\s*[xX]?\s*$').hasMatch(line);
  }

  bool _looksLikeProductNameLine(String line) {
    final upper = line.toUpperCase();
    if (_ignoredTokens.any(upper.contains)) {
      return false;
    }
    if (_isDetachedPriceDetailLine(line)) {
      return false;
    }
    final letters = RegExp(r'[A-Za-z]').allMatches(line).length;
    if (letters < 3) {
      return false;
    }
    return _productCodePattern.hasMatch(line) || letters >= 6;
  }

  bool _isDetachedPriceDetailLine(String line) {
    if (_productCodePattern.hasMatch(line) && !_startsWithUnitToken(line)) {
      return false;
    }
    final prices = _pricePattern.allMatches(line).toList(growable: false);
    if (prices.length < 2) {
      return false;
    }
    final normalized = line.trim().toUpperCase();
    return RegExp(
          r'^\d+(?:[,.]\d+)?\s*K\w*\s*(?:[xX]\s*)?\d+(?:[,.]\d+)?\s+\d+(?:[,.]\d{2})$',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'^(?:\d+\s*)?(?:UN\w*|UND\w*|ND\w*|DPL\w*|BDJ\w*|FR\w*|CX\w*|PC\w*|PCT\w*)\s+\d+(?:[,.]\d{2})\s+\d+(?:[,.]\d{2})$',
          caseSensitive: false,
        ).hasMatch(normalized);
  }

  bool _startsWithUnitToken(String line) {
    return RegExp(
      r'^\s*(?:UN\w*|UND\w*|ND\w*|DPL\w*|BDJ\w*|FR\w*|CX\w*|PC\w*|PCT\w*)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  bool _isProductWeightLineMissingTotal(String line) {
    if (!_productCodePattern.hasMatch(line)) {
      return false;
    }
    final upper = line.toUpperCase();
    if (!upper.contains('KG') || !upper.contains('X')) {
      return false;
    }
    return _pricePattern.allMatches(line).length < 2;
  }

  bool _isSplitKiloContinuationLine(String line) {
    return _splitKiloContinuationPattern.hasMatch(line);
  }

  bool _isKiloPriceWithoutTotal(
    String line,
    List<RegExpMatch> prices,
    RegExpMatch? quantityMatch,
  ) {
    if (quantityMatch == null) {
      return false;
    }
    final upper = line.toUpperCase();
    if (!upper.contains('KG') || !upper.contains('R\$')) {
      return false;
    }
    final afterUnitPrice = line.substring(quantityMatch.end);
    return !_pricePattern.hasMatch(afterUnitPrice);
  }

  bool _isWeightedSaleLine(String line) {
    final upper = line.toUpperCase();
    return RegExp(
          r'\bUN:\s*K[GR]?\d?\b',
          caseSensitive: false,
        ).hasMatch(line) ||
        RegExp(
          r'\d+(?:[,.]\d+)?\s*K[GR]?\d?\s*[xX]',
          caseSensitive: false,
        ).hasMatch(line) ||
        upper.contains('R\$/KG');
  }

  bool _isStandalonePriceLine(String line) {
    return RegExp(r'^\s*\d{1,3}(?:[.,]\d{1,2})?\s*$').hasMatch(line);
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

  int _parseQuantity(String raw) {
    final normalized = raw.replaceAll('.', '').replaceAll(',', '.');
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return 1;
    }
    return _quantityForReceipt(parsed);
  }

  int _quantityForReceipt(double parsed) {
    if (parsed <= 0) {
      return 1;
    }
    if (parsed < 1) {
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

class _MergedOcrLine {
  const _MergedOcrLine(this.line, this.consumedIndex);

  final String line;
  final int consumedIndex;
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
