import 'dart:math';

import '../domain/classifications.dart';
import '../domain/models_and_utils.dart';

enum VoiceCatalogMatchConfidence { none, ambiguous, high, exact }

class VoiceItemIntent {
  const VoiceItemIntent({
    required this.rawText,
    required this.name,
    required this.quantity,
    this.unitPrice,
  });

  final String rawText;
  final String name;
  final int quantity;
  final double? unitPrice;
}

class VoiceCatalogCandidate {
  const VoiceCatalogCandidate({required this.product, required this.score});

  final CatalogProduct product;
  final double score;
}

class VoiceResolvedShoppingItem {
  const VoiceResolvedShoppingItem({
    required this.intent,
    required this.draft,
    required this.confidence,
    this.matchedProduct,
    this.alternatives = const <VoiceCatalogCandidate>[],
  });

  final VoiceItemIntent intent;
  final ShoppingItemDraft draft;
  final VoiceCatalogMatchConfidence confidence;
  final CatalogProduct? matchedProduct;
  final List<VoiceCatalogCandidate> alternatives;

  bool get hasPrice => draft.unitPrice > 0;
  bool get needsAttention =>
      !hasPrice || confidence == VoiceCatalogMatchConfidence.ambiguous;

  VoiceResolvedShoppingItem selectProduct(CatalogProduct product) {
    final spokenPrice = intent.unitPrice;
    return VoiceResolvedShoppingItem(
      intent: intent,
      draft: ShoppingItemDraft(
        name: product.name,
        quantity: max(1, intent.quantity),
        unitPrice: spokenPrice ?? product.unitPrice ?? 0,
        category: product.category,
        barcode: product.barcode,
      ),
      confidence: VoiceCatalogMatchConfidence.exact,
      matchedProduct: product,
      alternatives: alternatives,
    );
  }

  VoiceResolvedShoppingItem applyEditedDraft(ShoppingItemDraft edited) {
    final selected = matchedProduct;
    final keepsMatch =
        selected != null &&
        _canonicalVoiceText(selected.name) ==
            _canonicalVoiceText(edited.name) &&
        sanitizeBarcode(selected.barcode) == sanitizeBarcode(edited.barcode);
    return VoiceResolvedShoppingItem(
      intent: intent,
      draft: edited,
      confidence: keepsMatch ? confidence : VoiceCatalogMatchConfidence.none,
      matchedProduct: keepsMatch ? selected : null,
      alternatives: alternatives,
    );
  }
}

class VoiceShoppingParser {
  const VoiceShoppingParser();

  List<VoiceItemIntent> parse(String transcript) {
    final prepared = _prepareTranscript(transcript);
    if (prepared.isEmpty) {
      return const <VoiceItemIntent>[];
    }

    final intents = <VoiceItemIntent>[];
    for (final rawSegment in prepared.split(RegExp(r'[,;\n]+'))) {
      final parsed = _parseSegment(rawSegment);
      if (parsed != null) {
        intents.add(parsed);
      }
    }
    return List<VoiceItemIntent>.unmodifiable(intents);
  }

  String _prepareTranscript(String raw) {
    var value = raw.trim().toLowerCase();
    value = value.replaceAll(
      RegExp(
        r'^(?:por favor\s+)?(?:adicione|adicionar|adiciona|inclua|incluir|'
        r'coloque|coloca|quero|preciso de)\s+',
      ),
      '',
    );
    value = value.replaceAllMapped(
      RegExp(
        r'\b(vinte|trinta|quarenta|cinquenta|sessenta|setenta|oitenta|'
        r'noventa)\s+e\s+(um|uma|dois|duas|três|tres|quatro|cinco|seis|'
        r'sete|oito|nove)\b',
      ),
      (match) {
        final tens = _tensWords[_canonicalVoiceText(match.group(1)!)] ?? 0;
        final units = _numberWords[_canonicalVoiceText(match.group(2)!)] ?? 0;
        return '${tens + units}';
      },
    );
    value = value.replaceAllMapped(
      RegExp(r'(\d+),(\d{1,2})'),
      (match) => '${match.group(1)}.${match.group(2)}',
    );
    value = value.replaceAllMapped(
      RegExp(r'\breais?\s+e\s+(\d{1,2})\s+centavos?\b'),
      (match) => 'reais_com_${match.group(1)}_centavos',
    );
    value = value.replaceAll(RegExp(r'\s+e também\s+'), ', ');
    value = value.replaceAll(RegExp(r'\s+e tambem\s+'), ', ');
    value = value.replaceAll(RegExp(r'\s+e\s+'), ', ');
    return value.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  VoiceItemIntent? _parseSegment(String rawSegment) {
    var segment = rawSegment.trim();
    if (segment.isEmpty) {
      return null;
    }

    final priceResult = _extractPrice(segment);
    segment = priceResult.cleanedText;
    final quantityResult = _extractQuantity(segment);
    segment = quantityResult.cleanedText;
    segment = segment
        .replaceAll(RegExp(r'^(?:de|do|da)\s+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (segment.isEmpty) {
      return null;
    }

    return VoiceItemIntent(
      rawText: rawSegment.trim(),
      name: _sentenceCase(segment),
      quantity: quantityResult.quantity,
      unitPrice: priceResult.price,
    );
  }

  _VoicePriceResult _extractPrice(String source) {
    final numeric = RegExp(
      r'\s+(?:por|a|custando|no valor de|valor de)\s+'
      r'(?:r\$\s*)?(\d+(?:[.,]\d{1,2})?)'
      r'(?:\s*reais?)?(?:\s*cada)?\s*$',
    ).firstMatch(source);
    if (numeric != null) {
      final rawPrice = numeric.group(1)!;
      final normalizedPrice = rawPrice.contains(',')
          ? rawPrice.replaceAll('.', '').replaceAll(',', '.')
          : rawPrice;
      final parsed = double.tryParse(normalizedPrice);
      return _VoicePriceResult(
        cleanedText: source.substring(0, numeric.start).trim(),
        price: parsed,
      );
    }

    final reais = RegExp(
      r'\s+(?:por|a|custando|no valor de|valor de)\s+'
      r'(\d+)\s*reais?(?:\s+com\s+(\d{1,2})\s+centavos?)?'
      r'(?:\s*cada)?\s*$',
    ).firstMatch(source);
    if (reais == null) {
      return _VoicePriceResult(cleanedText: source);
    }
    final whole = int.tryParse(reais.group(1)!) ?? 0;
    final cents = int.tryParse(reais.group(2) ?? '') ?? 0;
    return _VoicePriceResult(
      cleanedText: source.substring(0, reais.start).trim(),
      price: whole + cents / 100,
    );
  }

  _VoiceQuantityResult _extractQuantity(String source) {
    final match = RegExp(r'^([0-9]+|[a-záàâãéêíóôõúç]+)\s+').firstMatch(source);
    if (match == null) {
      return _VoiceQuantityResult(cleanedText: source, quantity: 1);
    }

    final parsed =
        int.tryParse(match.group(1)!) ??
        _numberWords[_canonicalVoiceText(match.group(1)!)] ??
        0;
    if (parsed <= 0) {
      return _VoiceQuantityResult(cleanedText: source, quantity: 1);
    }

    var remaining = source.substring(match.end).trim();
    remaining = remaining.replaceFirst(
      RegExp(
        r'^(?:unidades?|itens?|pacotes?|caixas?|garrafas?|frascos?|'
        r'latas?|potes?)\s+(?:de\s+)?',
      ),
      '',
    );
    return _VoiceQuantityResult(
      cleanedText: remaining,
      quantity: parsed.clamp(1, 999),
    );
  }

  String _sentenceCase(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}

class VoiceCatalogMatcher {
  const VoiceCatalogMatcher();

  List<VoiceResolvedShoppingItem> resolveAll(
    List<VoiceItemIntent> intents, {
    required List<CatalogProduct> catalogProducts,
  }) {
    return intents
        .map((intent) => resolve(intent, catalogProducts: catalogProducts))
        .toList(growable: false);
  }

  VoiceResolvedShoppingItem resolve(
    VoiceItemIntent intent, {
    required List<CatalogProduct> catalogProducts,
  }) {
    final candidates = catalogProducts
        .map(
          (product) => VoiceCatalogCandidate(
            product: product,
            score: _score(intent.name, product.name),
          ),
        )
        .where((candidate) => candidate.score >= 0.45)
        .toList();
    candidates.sort(_compareCandidates);

    final alternatives = candidates.take(4).toList(growable: false);
    final best = candidates.isEmpty ? null : candidates.first;
    if (best == null || best.score < 0.58) {
      return _unmatched(intent, alternatives: alternatives);
    }

    final exact =
        _canonicalVoiceText(intent.name) ==
        _canonicalVoiceText(best.product.name);
    if (exact) {
      return _matched(
        intent,
        best.product,
        VoiceCatalogMatchConfidence.exact,
        alternatives,
      );
    }

    final competing = candidates.length > 1 ? candidates[1] : null;
    final clearLead = competing == null || best.score - competing.score >= 0.1;
    if (best.score >= 0.82 && clearLead) {
      return _matched(
        intent,
        best.product,
        VoiceCatalogMatchConfidence.high,
        alternatives,
      );
    }

    return _unmatched(
      intent,
      confidence: VoiceCatalogMatchConfidence.ambiguous,
      alternatives: alternatives,
    );
  }

  VoiceResolvedShoppingItem _matched(
    VoiceItemIntent intent,
    CatalogProduct product,
    VoiceCatalogMatchConfidence confidence,
    List<VoiceCatalogCandidate> alternatives,
  ) {
    return VoiceResolvedShoppingItem(
      intent: intent,
      draft: ShoppingItemDraft(
        name: product.name,
        quantity: max(1, intent.quantity),
        unitPrice: intent.unitPrice ?? product.unitPrice ?? 0,
        category: product.category,
        barcode: product.barcode,
      ),
      confidence: confidence,
      matchedProduct: product,
      alternatives: alternatives,
    );
  }

  VoiceResolvedShoppingItem _unmatched(
    VoiceItemIntent intent, {
    VoiceCatalogMatchConfidence confidence = VoiceCatalogMatchConfidence.none,
    List<VoiceCatalogCandidate> alternatives = const <VoiceCatalogCandidate>[],
  }) {
    return VoiceResolvedShoppingItem(
      intent: intent,
      draft: ShoppingItemDraft(
        name: intent.name,
        quantity: max(1, intent.quantity),
        unitPrice: intent.unitPrice ?? 0,
        category: _categoryFor(intent.name),
      ),
      confidence: confidence,
      alternatives: alternatives,
    );
  }

  int _compareCandidates(
    VoiceCatalogCandidate left,
    VoiceCatalogCandidate right,
  ) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    final byUsage = right.product.usageCount.compareTo(left.product.usageCount);
    if (byUsage != 0) {
      return byUsage;
    }
    return right.product.updatedAt.compareTo(left.product.updatedAt);
  }

  double _score(String spokenName, String catalogName) {
    final spoken = _voiceTokens(spokenName);
    final catalog = _voiceTokens(catalogName);
    if (spoken.isEmpty || catalog.isEmpty) {
      return 0;
    }
    if (spoken.join(' ') == catalog.join(' ')) {
      return 1;
    }

    final coverage = spoken.where(catalog.contains).length / spoken.length;
    final reverseCoverage =
        catalog.where(spoken.contains).length / catalog.length;
    final intersection = spoken.toSet().intersection(catalog.toSet()).length;
    final union = spoken.toSet().union(catalog.toSet()).length;
    final jaccard = union == 0 ? 0.0 : intersection / union;
    final contained = coverage == 1;
    return max(
      coverage * 0.68 + reverseCoverage * 0.17 + jaccard * 0.15,
      contained ? 0.88 : 0,
    ).clamp(0, 1).toDouble();
  }

  ShoppingCategory _categoryFor(String name) {
    final text = _canonicalVoiceText(name);
    if (_containsAny(text, const [
      'detergente',
      'sabao',
      'amaciante',
      'agua sanitaria',
    ])) {
      return ShoppingCategory.cleaning;
    }
    if (_containsAny(text, const [
      'sabonete',
      'shampoo',
      'creme dental',
      'desodorante',
    ])) {
      return ShoppingCategory.personalCare;
    }
    if (_containsAny(text, const ['leite', 'queijo', 'iogurte', 'manteiga'])) {
      return ShoppingCategory.dairy;
    }
    if (_containsAny(text, const ['refrigerante', 'suco', 'cerveja', 'agua'])) {
      return ShoppingCategory.beverages;
    }
    if (_containsAny(text, const ['arroz', 'feijao', 'macarrao', 'farinha'])) {
      return ShoppingCategory.grainsAndPasta;
    }
    if (_containsAny(text, const ['pao', 'bolo', 'torrada'])) {
      return ShoppingCategory.bakery;
    }
    if (_containsAny(text, const ['carne', 'frango', 'linguica'])) {
      return ShoppingCategory.meat;
    }
    if (_containsAny(text, const [
      'banana',
      'maca',
      'tomate',
      'cebola',
      'alface',
    ])) {
      return ShoppingCategory.produce;
    }
    return ShoppingCategory.grocery;
  }

  bool _containsAny(String source, List<String> candidates) {
    return candidates.any(source.contains);
  }
}

class VoiceDraftMergeResult {
  const VoiceDraftMergeResult({
    required this.items,
    required this.createdCount,
    required this.mergedCount,
  });

  final List<ShoppingItem> items;
  final int createdCount;
  final int mergedCount;
}

class VoiceDraftListMerger {
  const VoiceDraftListMerger();

  VoiceDraftMergeResult merge(
    List<ShoppingItem> currentItems,
    List<ShoppingItemDraft> drafts, {
    required DateTime recordedAt,
  }) {
    final items = [...currentItems];
    var createdCount = 0;
    var mergedCount = 0;
    for (final draft in drafts) {
      final existingIndex = _findMatchingItemIndex(items, draft);
      if (existingIndex < 0) {
        items.add(_newItemFromDraft(draft, recordedAt: recordedAt));
        createdCount++;
        continue;
      }
      items[existingIndex] = _mergeIntoItem(
        items[existingIndex],
        draft,
        recordedAt: recordedAt,
      );
      mergedCount++;
    }
    return VoiceDraftMergeResult(
      items: List.unmodifiable(items),
      createdCount: createdCount,
      mergedCount: mergedCount,
    );
  }

  int _findMatchingItemIndex(
    List<ShoppingItem> items,
    ShoppingItemDraft draft,
  ) {
    final barcode = sanitizeBarcode(draft.barcode);
    if (barcode != null) {
      final byBarcode = items.indexWhere(
        (item) => sanitizeBarcode(item.barcode) == barcode,
      );
      if (byBarcode >= 0) {
        return byBarcode;
      }
    }
    final normalizedName = normalizeQuery(draft.name);
    return items.indexWhere(
      (item) => normalizeQuery(item.name) == normalizedName,
    );
  }

  ShoppingItem _newItemFromDraft(
    ShoppingItemDraft draft, {
    required DateTime recordedAt,
  }) {
    return ShoppingItem(
      id: uniqueId(),
      name: draft.name,
      quantity: max(1, draft.quantity),
      unitPrice: max(0, draft.unitPrice),
      barcode: draft.barcode,
      category: draft.category,
      isPurchased: draft.isPurchased,
      priceHistory: draft.unitPrice > 0
          ? [PriceHistoryEntry(price: draft.unitPrice, recordedAt: recordedAt)]
          : const <PriceHistoryEntry>[],
    );
  }

  ShoppingItem _mergeIntoItem(
    ShoppingItem existing,
    ShoppingItemDraft draft, {
    required DateTime recordedAt,
  }) {
    final resolvedPrice = draft.unitPrice > 0
        ? draft.unitPrice
        : existing.unitPrice;
    final history = [...existing.priceHistory];
    if (resolvedPrice > 0 &&
        (history.isEmpty ||
            (history.last.price - resolvedPrice).abs() > 0.0001)) {
      history.add(
        PriceHistoryEntry(price: resolvedPrice, recordedAt: recordedAt),
      );
    }
    return existing.copyWith(
      name: draft.name,
      quantity: existing.quantity + max(1, draft.quantity),
      unitPrice: resolvedPrice,
      barcode: draft.barcode,
      category: draft.category,
      priceHistory: history,
    );
  }
}

class _VoicePriceResult {
  const _VoicePriceResult({required this.cleanedText, this.price});

  final String cleanedText;
  final double? price;
}

class _VoiceQuantityResult {
  const _VoiceQuantityResult({
    required this.cleanedText,
    required this.quantity,
  });

  final String cleanedText;
  final int quantity;
}

const Map<String, int> _numberWords = <String, int>{
  'um': 1,
  'uma': 1,
  'dois': 2,
  'duas': 2,
  'tres': 3,
  'quatro': 4,
  'cinco': 5,
  'seis': 6,
  'sete': 7,
  'oito': 8,
  'nove': 9,
  'dez': 10,
  'onze': 11,
  'doze': 12,
  'treze': 13,
  'quatorze': 14,
  'catorze': 14,
  'quinze': 15,
  'dezesseis': 16,
  'dezessete': 17,
  'dezoito': 18,
  'dezenove': 19,
  'vinte': 20,
};

const Map<String, int> _tensWords = <String, int>{
  'vinte': 20,
  'trinta': 30,
  'quarenta': 40,
  'cinquenta': 50,
  'sessenta': 60,
  'setenta': 70,
  'oitenta': 80,
  'noventa': 90,
};

List<String> _voiceTokens(String raw) {
  return _canonicalVoiceText(raw)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.isNotEmpty)
      .map((token) {
        if (token.length > 4 && token.endsWith('s')) {
          return token.substring(0, token.length - 1);
        }
        return token;
      })
      .toList(growable: false);
}

String _canonicalVoiceText(String raw) {
  const source = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const target = 'aaaaaeeeeiiiiooooouuuuc';
  final lower = raw.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    final index = source.indexOf(character);
    buffer.write(index < 0 ? character : target[index]);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
