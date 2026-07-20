import 'dart:math';

import 'classifications.dart';
import 'models_and_utils.dart';
import 'receipt_aliases.dart';

enum ReceiptItemMatchSource { currentList, catalog }

enum ReceiptItemMatchConfidence { none, low, medium, high, exact }

class ReceiptItemMatchCandidate {
  const ReceiptItemMatchCandidate({
    required this.id,
    required this.source,
    required this.name,
    required this.category,
    required this.score,
    this.unitPrice,
    this.barcode,
  });

  final String id;
  final ReceiptItemMatchSource source;
  final String name;
  final ShoppingCategory category;
  final double? unitPrice;
  final String? barcode;
  final double score;
}

class ReceiptItemMatchResult {
  const ReceiptItemMatchResult({
    required this.originalDraft,
    required this.resolvedDraft,
    required this.confidence,
    this.candidate,
  });

  final ShoppingItemDraft originalDraft;
  final ShoppingItemDraft resolvedDraft;
  final ReceiptItemMatchConfidence confidence;
  final ReceiptItemMatchCandidate? candidate;

  bool get hasAppliedMatch =>
      candidate != null &&
      (confidence == ReceiptItemMatchConfidence.high ||
          confidence == ReceiptItemMatchConfidence.exact);

  int get matchPercent => ((candidate?.score ?? 0) * 100).round().clamp(0, 100);
}

class ReceiptItemMatcher {
  const ReceiptItemMatcher();

  List<ReceiptItemMatchResult> matchAll(
    List<ShoppingItemDraft> drafts, {
    required List<ShoppingItem> currentItems,
    required List<CatalogProduct> catalogProducts,
  }) {
    return drafts
        .map(
          (draft) => match(
            draft,
            currentItems: currentItems,
            catalogProducts: catalogProducts,
          ),
        )
        .toList(growable: false);
  }

  ReceiptItemMatchResult match(
    ShoppingItemDraft draft, {
    required List<ShoppingItem> currentItems,
    required List<CatalogProduct> catalogProducts,
  }) {
    final candidates = <ReceiptItemMatchCandidate>[
      for (final item in currentItems) _candidateFromItem(draft, item),
      for (final product in catalogProducts)
        _candidateFromProduct(draft, product),
    ]..removeWhere((candidate) => candidate.score < 0.45);

    candidates.sort(_compareCandidates);
    final best = candidates.isEmpty ? null : candidates.first;
    final confidence = _confidenceFor(best?.score ?? 0);
    if (best == null ||
        confidence.index < ReceiptItemMatchConfidence.high.index) {
      return ReceiptItemMatchResult(
        originalDraft: draft,
        resolvedDraft: draft,
        confidence: best == null ? ReceiptItemMatchConfidence.none : confidence,
        candidate: confidence == ReceiptItemMatchConfidence.none ? null : best,
      );
    }

    return ReceiptItemMatchResult(
      originalDraft: draft,
      resolvedDraft: ShoppingItemDraft(
        name: best.name,
        quantity: draft.quantity,
        unitPrice: draft.unitPrice,
        category: best.category,
        barcode: best.barcode ?? draft.barcode,
        isPurchased: draft.isPurchased,
      ),
      confidence: confidence,
      candidate: best,
    );
  }

  ReceiptItemMatchCandidate _candidateFromItem(
    ShoppingItemDraft draft,
    ShoppingItem item,
  ) {
    return ReceiptItemMatchCandidate(
      id: item.id,
      source: ReceiptItemMatchSource.currentList,
      name: item.name,
      category: item.category,
      unitPrice: item.unitPrice,
      barcode: item.barcode,
      score: _score(
        draftName: draft.name,
        candidateName: item.name,
        draftBarcode: draft.barcode,
        candidateBarcode: item.barcode,
        draftCategory: draft.category,
        candidateCategory: item.category,
        draftUnitPrice: draft.unitPrice,
        candidateUnitPrice: item.unitPrice,
        source: ReceiptItemMatchSource.currentList,
      ),
    );
  }

  ReceiptItemMatchCandidate _candidateFromProduct(
    ShoppingItemDraft draft,
    CatalogProduct product,
  ) {
    return ReceiptItemMatchCandidate(
      id: product.id,
      source: ReceiptItemMatchSource.catalog,
      name: product.name,
      category: product.category,
      unitPrice: product.unitPrice,
      barcode: product.barcode,
      score: _score(
        draftName: draft.name,
        candidateName: product.name,
        draftBarcode: draft.barcode,
        candidateBarcode: product.barcode,
        draftCategory: draft.category,
        candidateCategory: product.category,
        draftUnitPrice: draft.unitPrice,
        candidateUnitPrice: product.unitPrice,
        source: ReceiptItemMatchSource.catalog,
      ),
    );
  }

  int _compareCandidates(
    ReceiptItemMatchCandidate left,
    ReceiptItemMatchCandidate right,
  ) {
    final byScore = right.score.compareTo(left.score);
    if (byScore != 0) {
      return byScore;
    }
    if (left.source != right.source) {
      return left.source == ReceiptItemMatchSource.currentList ? -1 : 1;
    }
    return left.name.length.compareTo(right.name.length);
  }

  double _score({
    required String draftName,
    required String candidateName,
    required String? draftBarcode,
    required String? candidateBarcode,
    required ShoppingCategory draftCategory,
    required ShoppingCategory candidateCategory,
    required double draftUnitPrice,
    required double? candidateUnitPrice,
    required ReceiptItemMatchSource source,
  }) {
    final normalizedDraftBarcode = sanitizeBarcode(draftBarcode);
    final normalizedCandidateBarcode = sanitizeBarcode(candidateBarcode);
    if (normalizedDraftBarcode != null &&
        normalizedCandidateBarcode != null &&
        normalizedDraftBarcode == normalizedCandidateBarcode) {
      return 1;
    }

    final draftText = _ReceiptTextProfile(draftName);
    final candidateText = _ReceiptTextProfile(candidateName);
    if (draftText.normalized.isEmpty || candidateText.normalized.isEmpty) {
      return 0;
    }
    if (draftText.normalized == candidateText.normalized) {
      return 0.98;
    }

    final coverage = _tokenCoverage(draftText.tokens, candidateText.tokens);
    final jaccard = _jaccard(draftText.tokens, candidateText.tokens);
    final charSimilarity = _characterSimilarity(
      draftText.normalized,
      candidateText.normalized,
    );
    final contained =
        draftText.normalized.contains(candidateText.normalized) ||
        candidateText.normalized.contains(draftText.normalized);

    var score = max(
      coverage * 0.74 + jaccard * 0.16 + charSimilarity * 0.1,
      contained ? 0.86 : 0,
    );
    if (draftCategory == candidateCategory) {
      score += 0.04;
    }
    if (_hasSimilarPrice(draftUnitPrice, candidateUnitPrice)) {
      score += 0.04;
    }
    if (source == ReceiptItemMatchSource.currentList) {
      score += 0.03;
    }
    return score.clamp(0, 0.99).toDouble();
  }

  ReceiptItemMatchConfidence _confidenceFor(double score) {
    if (score >= 0.995) {
      return ReceiptItemMatchConfidence.exact;
    }
    if (score >= 0.74) {
      return ReceiptItemMatchConfidence.high;
    }
    if (score >= 0.58) {
      return ReceiptItemMatchConfidence.medium;
    }
    if (score >= 0.45) {
      return ReceiptItemMatchConfidence.low;
    }
    return ReceiptItemMatchConfidence.none;
  }

  bool _hasSimilarPrice(double draftUnitPrice, double? candidateUnitPrice) {
    if (draftUnitPrice <= 0 ||
        candidateUnitPrice == null ||
        candidateUnitPrice <= 0) {
      return false;
    }
    final reference = max(draftUnitPrice, candidateUnitPrice);
    return ((draftUnitPrice - candidateUnitPrice).abs() / reference) <= 0.25;
  }

  double _tokenCoverage(List<String> source, List<String> candidate) {
    if (source.isEmpty || candidate.isEmpty) {
      return 0;
    }
    var matched = 0.0;
    for (final token in source) {
      matched += _bestTokenScore(token, candidate);
    }
    return matched / source.length;
  }

  double _bestTokenScore(String token, List<String> candidates) {
    var best = 0.0;
    for (final candidate in candidates) {
      if (candidate == token) {
        return 1;
      }
      if (token.length >= 3 && candidate.startsWith(token)) {
        best = max(best, 0.82);
      } else if (candidate.length >= 3 && token.startsWith(candidate)) {
        best = max(best, 0.76);
      } else if (token.length == 1 && candidate.startsWith(token)) {
        best = max(best, 0.45);
      }
    }
    return best;
  }

  double _jaccard(List<String> left, List<String> right) {
    final leftSet = left.toSet();
    final rightSet = right.toSet();
    final union = leftSet.union(rightSet).length;
    if (union == 0) {
      return 0;
    }
    return leftSet.intersection(rightSet).length / union;
  }

  double _characterSimilarity(String left, String right) {
    final maxLength = max(left.length, right.length);
    if (maxLength == 0) {
      return 0;
    }
    final distance = _levenshtein(left, right);
    return (1 - distance / maxLength).clamp(0, 1);
  }

  int _levenshtein(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final cost = left.codeUnitAt(i) == right.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = min(
          min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + cost,
        );
      }
      previous = current;
    }
    return previous.last;
  }
}

class _ReceiptTextProfile {
  _ReceiptTextProfile(String raw)
    : tokens = _tokensFor(raw),
      normalized = _tokensFor(raw).join(' ');

  final List<String> tokens;
  final String normalized;

  static List<String> _tokensFor(String raw) {
    final expanded = expandReceiptAliases(raw);

    return expanded
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2 || RegExp(r'\d').hasMatch(token))
        .where((token) => !_ignoredTokens.contains(token))
        .toList(growable: false);
  }

  static const Set<String> _ignoredTokens = <String>{
    'un',
    'und',
    'unid',
    'unidade',
    'kg',
    'g',
    'gr',
    'l',
    'lt',
    'ml',
    'cx',
    'fd',
    'pct',
    'pc',
    'item',
    'it',
  };
}
