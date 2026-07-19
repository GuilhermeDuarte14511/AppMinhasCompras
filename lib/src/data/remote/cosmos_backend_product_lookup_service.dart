import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

typedef CosmosBackendLookup = Future<Object?> Function(String barcode);
typedef CosmosBackendFailureReporter =
    void Function(CosmosBackendFailure failure);

Map<String, Object?> buildCosmosBackendRequest(String gtin) =>
    <String, Object?>{'gtin': gtin};

enum CosmosBackendFailure {
  unauthenticated,
  attestationRejected,
  invalidRequest,
  rateLimited,
  misconfigured,
  unavailable,
  timeout,
  unexpected,
}

bool hasValidGtinCheckDigit(String gtin) {
  if (!const <int>{8, 12, 13, 14}.contains(gtin.length) ||
      !RegExp(r'^\d+$').hasMatch(gtin)) {
    return false;
  }
  final checkDigit = int.parse(gtin[gtin.length - 1]);
  var sum = 0;
  var multiplier = 3;
  for (var index = gtin.length - 2; index >= 0; index--) {
    sum += int.parse(gtin[index]) * multiplier;
    multiplier = multiplier == 3 ? 1 : 3;
  }
  return (10 - (sum % 10)) % 10 == checkDigit;
}

class CosmosBackendProductLookupService implements ProductLookupService {
  CosmosBackendProductLookupService({
    CosmosBackendLookup? lookup,
    CosmosBackendFailureReporter? onFailure,
    Duration timeout = const Duration(seconds: 15),
  }) : _lookup = lookup ?? _FirebaseCosmosBackendLookup(timeout: timeout).call,
       _onFailure = onFailure ?? _reportFailure;

  final CosmosBackendLookup _lookup;
  final CosmosBackendFailureReporter _onFailure;

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    final sanitized = sanitizeBarcode(barcode);
    if (sanitized == null || !hasValidGtinCheckDigit(sanitized)) {
      return null;
    }

    try {
      final response = await _lookup(sanitized);
      return _mapResponse(response, sanitized);
    } on _CosmosBackendUnauthenticatedException {
      _onFailure(CosmosBackendFailure.unauthenticated);
      return null;
    } on TimeoutException {
      _onFailure(CosmosBackendFailure.timeout);
      return null;
    } on FirebaseFunctionsException catch (error) {
      _onFailure(_mapFunctionsFailure(error.code));
      return null;
    } catch (_) {
      _onFailure(CosmosBackendFailure.unexpected);
      return null;
    }
  }

  ProductLookupResult? _mapResponse(Object? response, String barcode) {
    final envelope = _asStringMap(response);
    if (envelope == null) {
      return null;
    }

    final product = _asStringMap(envelope['product']);
    if (product == null || product['gtin'] != barcode) {
      return null;
    }
    final name = _firstNonEmptyString(<Object?>[product['name']]);
    final category = _readCategory(product['categoryKey']);
    final unitPrice = _firstPositiveDouble(<Object?>[product['unitPrice']]);

    if (name == null && category == null && unitPrice == null) {
      return null;
    }

    return ProductLookupResult(
      source: ProductLookupSource.cosmos,
      barcode: barcode,
      name: name,
      category: category,
      unitPrice: unitPrice,
    );
  }

  Map<String, Object?>? _asStringMap(Object? value) {
    if (value is! Map) {
      return null;
    }

    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        return null;
      }
      result[entry.key as String] = entry.value;
    }
    return result;
  }

  String? _firstNonEmptyString(Iterable<Object?> values) {
    for (final value in values) {
      if (value is! String) {
        continue;
      }
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  ShoppingCategory? _readCategory(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value
        .trim()
        .replaceAll('-', '_')
        .replaceAll(' ', '_')
        .toLowerCase();
    for (final category in ShoppingCategory.values) {
      final enumName = category.name.toLowerCase();
      if (normalized == category.key || normalized == enumName) {
        return category;
      }
    }
    return null;
  }

  double? _firstPositiveDouble(Iterable<Object?> values) {
    for (final value in values) {
      final parsed = _toPositiveDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  double? _toPositiveDouble(Object? value) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => _parseDecimal(text),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  double? _parseDecimal(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (cleaned.isEmpty) {
      return null;
    }

    var normalized = cleaned;
    if (cleaned.contains(',') && cleaned.contains('.')) {
      normalized = cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')
          ? cleaned.replaceAll('.', '').replaceAll(',', '.')
          : cleaned.replaceAll(',', '');
    } else if (cleaned.contains(',')) {
      normalized = cleaned.replaceAll(',', '.');
    }
    return double.tryParse(normalized);
  }

  static CosmosBackendFailure _mapFunctionsFailure(String code) {
    return switch (code) {
      'unauthenticated' => CosmosBackendFailure.unauthenticated,
      'failed-precondition' => CosmosBackendFailure.misconfigured,
      'invalid-argument' => CosmosBackendFailure.invalidRequest,
      'resource-exhausted' => CosmosBackendFailure.rateLimited,
      'unavailable' || 'deadline-exceeded' => CosmosBackendFailure.unavailable,
      'permission-denied' => CosmosBackendFailure.attestationRejected,
      _ => CosmosBackendFailure.unexpected,
    };
  }

  static void _reportFailure(CosmosBackendFailure failure) {
    debugPrint('[CosmosBackend] consulta indisponível (${failure.name}).');
  }
}

class _FirebaseCosmosBackendLookup {
  _FirebaseCosmosBackendLookup({required this.timeout});

  static const String _region = 'southamerica-east1';
  static const String _functionName = 'lookupCosmosProduct';

  final Duration timeout;

  Future<Object?> call(String barcode) async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const _CosmosBackendUnauthenticatedException();
    }
    final callable = FirebaseFunctions.instanceFor(
      region: _region,
    ).httpsCallable(_functionName);
    final response = await callable
        .call(buildCosmosBackendRequest(barcode))
        .timeout(timeout);
    return response.data;
  }
}

class _CosmosBackendUnauthenticatedException implements Exception {
  const _CosmosBackendUnauthenticatedException();
}
