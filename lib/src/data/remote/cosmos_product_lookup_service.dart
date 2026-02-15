import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class CosmosProductLookupService implements ProductLookupService {
  const CosmosProductLookupService({required String token, http.Client? client})
    : _token = token,
      _client = client;

  static const String _host = 'api.cosmos.bluesoft.com.br';
  static const String _userAgent = 'Cosmos-API-Request';

  final String _token;
  final http.Client? _client;

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    final sanitized = sanitizeBarcode(barcode);
    if (sanitized == null) {
      return null;
    }

    final token = _token.trim();
    if (token.isEmpty) {
      return null;
    }

    final shouldCloseClient = _client == null;
    final client = _client ?? http.Client();

    try {
      final uri = Uri.https(_host, '/gtins/$sanitized.json');
      final response = await client
          .get(
            uri,
            headers: <String, String>{
              'User-Agent': _userAgent,
              'X-Cosmos-Token': token,
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map) {
        return null;
      }

      final data = Map<String, dynamic>.from(decoded);
      final name = _pickFirstNonEmpty(<String?>[
        data['description'] as String?,
        (data['brand'] is Map
            ? (data['brand'] as Map)['name'] as String?
            : null),
      ]);
      final category = _extractCategory(data);
      final price = _extractPrice(data);

      if ((name == null || name.isEmpty) && category == null && price == null) {
        return null;
      }

      return ProductLookupResult(
        source: ProductLookupSource.cosmos,
        barcode: sanitized,
        name: name,
        category: category,
        unitPrice: price,
      );
    } catch (_) {
      return null;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
  }

  double? _extractPrice(Map<String, dynamic> data) {
    final avg = data['avg_price'];
    if (avg is num && avg > 0) {
      return avg.toDouble();
    }
    final max = data['max_price'];
    if (max is num && max > 0) {
      return max.toDouble();
    }
    return null;
  }

  String? _pickFirstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  ShoppingCategory? _extractCategory(Map<String, dynamic> data) {
    final pool = StringBuffer();

    void append(dynamic value) {
      if (value == null) {
        return;
      }
      if (value is String) {
        if (value.trim().isNotEmpty) {
          pool.write(' ');
          pool.write(value);
        }
        return;
      }
      if (value is Map) {
        for (final entry in value.values) {
          append(entry);
        }
      }
      if (value is Iterable) {
        for (final entry in value) {
          append(entry);
        }
      }
    }

    append(data['description']);
    append(data['gpc']);
    append(data['ncm']);

    final normalized = normalizeQuery(pool.toString());
    if (normalized.isEmpty) {
      return null;
    }

    if (_containsAny(normalized, <String>[
      'bebida',
      'refrigerante',
      'suco',
      'agua',
      'cha',
      'cafe',
      'cerveja',
      'drink',
      'beverage',
    ])) {
      return ShoppingCategory.beverages;
    }

    if (_containsAny(normalized, <String>[
      'leite',
      'laticinio',
      'queijo',
      'iogurte',
      'manteiga',
      'dairy',
    ])) {
      return ShoppingCategory.dairy;
    }

    if (_containsAny(normalized, <String>['ovo', 'egg'])) {
      return ShoppingCategory.eggs;
    }

    if (_containsAny(normalized, <String>[
      'fruta',
      'verdura',
      'legume',
      'hortifruti',
      'vegetable',
      'fruit',
      'produce',
    ])) {
      return ShoppingCategory.produce;
    }

    if (_containsAny(normalized, <String>[
      'padaria',
      'pao',
      'bolo',
      'biscoito',
      'bakery',
      'bread',
      'cake',
    ])) {
      return ShoppingCategory.bakery;
    }

    if (_containsAny(normalized, <String>[
      'carne',
      'frango',
      'suino',
      'bovino',
      'meat',
      'beef',
      'chicken',
      'pork',
    ])) {
      return ShoppingCategory.meat;
    }

    if (_containsAny(normalized, <String>[
      'peixe',
      'frutos do mar',
      'seafood',
      'fish',
    ])) {
      return ShoppingCategory.seafood;
    }

    if (_containsAny(normalized, <String>[
      'massa',
      'arroz',
      'grao',
      'cereal',
      'feijao',
      'grain',
      'rice',
      'pasta',
    ])) {
      return ShoppingCategory.grainsAndPasta;
    }

    if (_containsAny(normalized, <String>['congelado', 'frozen'])) {
      return ShoppingCategory.frozen;
    }

    if (_containsAny(normalized, <String>[
      'salgad',
      'snack',
      'chips',
      'petisco',
    ])) {
      return ShoppingCategory.snacks;
    }

    if (_containsAny(normalized, <String>[
      'doce',
      'sobremesa',
      'chocolate',
      'candy',
      'dessert',
      'sweet',
    ])) {
      return ShoppingCategory.sweets;
    }

    if (_containsAny(normalized, <String>[
      'molho',
      'tempero',
      'ketchup',
      'mostarda',
      'maionese',
      'condiment',
      'sauce',
    ])) {
      return ShoppingCategory.condiments;
    }

    if (_containsAny(normalized, <String>[
      'limpeza',
      'detergente',
      'sabao',
      'desinfetante',
      'lava louca',
      'laundry',
      'clean',
      'household',
    ])) {
      return ShoppingCategory.cleaning;
    }

    if (_containsAny(normalized, <String>[
      'higiene',
      'sabonete',
      'shampoo',
      'antibocal',
      'enxaguante',
      'toothpaste',
      'mouthwash',
      'personal',
    ])) {
      return ShoppingCategory.personalCare;
    }

    if (_containsAny(normalized, <String>[
      'bebe',
      'fralda',
      'infant',
      'baby',
    ])) {
      return ShoppingCategory.baby;
    }

    if (_containsAny(normalized, <String>['pet', 'racao', 'dog', 'cat'])) {
      return ShoppingCategory.pet;
    }

    return ShoppingCategory.grocery;
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
