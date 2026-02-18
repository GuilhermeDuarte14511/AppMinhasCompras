import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../application/ports.dart';
import '../../domain/classifications.dart';
import '../../domain/models_and_utils.dart';

class CompositeProductLookupService implements ProductLookupService {
  const CompositeProductLookupService(this._services);

  final List<ProductLookupService> _services;

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    for (final service in _services) {
      try {
        final result = await service.lookupByBarcode(barcode);
        if (result != null && result.hasData) {
          return result;
        }
      } catch (_) {
        continue;
      }
    }
    return null;
  }
}

class OpenFoodFactsProductLookupService extends _OpenFactsProductLookupService {
  const OpenFoodFactsProductLookupService({super.client})
    : super(
        host: 'world.openfoodfacts.org',
        source: ProductLookupSource.openFoodFacts,
      );
}

class OpenProductsFactsProductLookupService
    extends _OpenFactsProductLookupService {
  const OpenProductsFactsProductLookupService({super.client})
    : super(
        host: 'world.openproductsfacts.org',
        source: ProductLookupSource.openProductsFacts,
      );
}

class _OpenFactsProductLookupService implements ProductLookupService {
  const _OpenFactsProductLookupService({
    required String host,
    required ProductLookupSource source,
    http.Client? client,
  }) : _host = host,
       _source = source,
       _client = client;

  static const String _userAgent =
      'MinhasComprasFlutter/1.0 (+https://openfoodfacts.org)';

  final String _host;
  final ProductLookupSource _source;
  final http.Client? _client;

  @override
  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    final sanitized = sanitizeBarcode(barcode);
    if (sanitized == null) {
      return null;
    }

    final shouldCloseClient = _client == null;
    final client = _client ?? http.Client();

    try {
      final uri = Uri.https(_host, '/api/v2/product/$sanitized.json', <
        String,
        String
      >{
        'fields':
            'product_name,product_name_pt,product_name_br,generic_name,generic_name_pt,generic_name_br,brands,categories,categories_tags,categories_hierarchy',
      });

      final response = await client
          .get(
            uri,
            headers: const <String, String>{
              'User-Agent': _userAgent,
              'Accept': 'application/json',
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
      final json = Map<String, dynamic>.from(decoded);
      final status = json['status'];
      if (status is num) {
        if (status.toInt() != 1) {
          return null;
        }
      } else if (status is String) {
        if (status.trim() != '1') {
          return null;
        }
      }

      final productRaw = json['product'];
      if (productRaw is! Map) {
        return null;
      }
      final product = Map<String, dynamic>.from(productRaw);

      final name = _pickFirstNonEmpty(<String?>[
        _readString(product['product_name_pt']),
        _readString(product['product_name_br']),
        _readString(product['product_name']),
        _readString(product['generic_name_pt']),
        _readString(product['generic_name_br']),
        _readString(product['generic_name']),
        _readString(product['brands']),
      ]);
      final category = _extractCategory(product);

      if ((name == null || name.isEmpty) && category == null) {
        return null;
      }

      return ProductLookupResult(
        source: _source,
        barcode: sanitized,
        name: name,
        category: category,
      );
    } catch (_) {
      return null;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }
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

  String? _readString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (value is num || value is bool) {
      return value.toString();
    }
    return null;
  }

  ShoppingCategory? _extractCategory(Map<String, dynamic> product) {
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
        return;
      }
      if (value is Iterable) {
        for (final entry in value) {
          append(entry);
        }
      }
    }

    append(product['categories']);
    append(product['categories_tags']);
    append(product['categories_hierarchy']);

    final value = normalizeQuery(pool.toString());
    if (value.isEmpty) {
      return null;
    }

    if (_containsAny(value, <String>[
      'beverage',
      'drink',
      'water',
      'juice',
      'soda',
      'refrigerante',
      'suco',
      'bebida',
      'coffee',
      'tea',
      'cha',
    ])) {
      return ShoppingCategory.beverages;
    }

    if (_containsAny(value, <String>[
      'dairy',
      'milk',
      'cheese',
      'iogurte',
      'yogurt',
      'leite',
      'latici',
    ])) {
      return ShoppingCategory.dairy;
    }

    if (_containsAny(value, <String>['egg', 'ovo'])) {
      return ShoppingCategory.eggs;
    }

    if (_containsAny(value, <String>[
      'fruit',
      'vegetable',
      'hortifruti',
      'fruta',
      'verdura',
      'legume',
      'produce',
    ])) {
      return ShoppingCategory.produce;
    }

    if (_containsAny(value, <String>[
      'bread',
      'bakery',
      'padaria',
      'pao',
      'cake',
      'bolo',
      'biscuit',
    ])) {
      return ShoppingCategory.bakery;
    }

    if (_containsAny(value, <String>[
      'meat',
      'beef',
      'pork',
      'chicken',
      'carne',
      'frango',
      'suino',
    ])) {
      return ShoppingCategory.meat;
    }

    if (_containsAny(value, <String>[
      'fish',
      'seafood',
      'peixe',
      'frutos do mar',
    ])) {
      return ShoppingCategory.seafood;
    }

    if (_containsAny(value, <String>[
      'pasta',
      'rice',
      'grain',
      'cereal',
      'massas',
      'graos',
      'arroz',
      'feijao',
    ])) {
      return ShoppingCategory.grainsAndPasta;
    }

    if (_containsAny(value, <String>['frozen', 'congelado'])) {
      return ShoppingCategory.frozen;
    }

    if (_containsAny(value, <String>['snack', 'chips', 'salgad', 'petisco'])) {
      return ShoppingCategory.snacks;
    }

    if (_containsAny(value, <String>[
      'sweet',
      'dessert',
      'doces',
      'sobremesa',
      'chocolate',
      'candy',
    ])) {
      return ShoppingCategory.sweets;
    }

    if (_containsAny(value, <String>[
      'sauce',
      'condiment',
      'temper',
      'molho',
      'ketchup',
      'mustard',
      'maionese',
    ])) {
      return ShoppingCategory.condiments;
    }

    if (_containsAny(value, <String>[
      'clean',
      'detergent',
      'dish-detergent',
      'household-cleaning',
      'sabao',
      'limpeza',
      'desinfetante',
      'lava-louca',
      'laundry',
    ])) {
      return ShoppingCategory.cleaning;
    }

    if (_containsAny(value, <String>[
      'hygiene',
      'personal',
      'toothpaste',
      'shampoo',
      'mouthwash',
      'sabonete',
      'higiene',
      'enxaguante bucal',
      'anticarie',
    ])) {
      return ShoppingCategory.personalCare;
    }

    if (_containsAny(value, <String>['baby', 'infant', 'bebe', 'fralda'])) {
      return ShoppingCategory.baby;
    }

    if (_containsAny(value, <String>['pet', 'dog', 'cat', 'racao'])) {
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
