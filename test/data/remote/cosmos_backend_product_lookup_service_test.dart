import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_compras_material/src/application/ports.dart';
import 'package:lista_compras_material/src/data/remote/cosmos_backend_product_lookup_service.dart';
import 'package:lista_compras_material/src/domain/classifications.dart';

void main() {
  group('CosmosBackendProductLookupService', () {
    test('uses the GTIN contract expected by the callable backend', () {
      expect(buildCosmosBackendRequest('7894900011517'), <String, Object?>{
        'gtin': '7894900011517',
      });
    });

    test('accepts the same GTIN lengths and check digits as backend', () {
      for (final gtin in <String>[
        '96385074',
        '036000291452',
        '7894900011517',
        '10012345678902',
      ]) {
        expect(hasValidGtinCheckDigit(gtin), isTrue, reason: gtin);
      }
      expect(hasValidGtinCheckDigit('7894900011518'), isFalse);
      expect(hasValidGtinCheckDigit('789123456'), isFalse);
    });

    test('maps the shared callable response fixture', () async {
      String? receivedBarcode;
      final fixture =
          jsonDecode(
                await File(
                  'test/fixtures/cosmos_lookup_response.json',
                ).readAsString(),
              )
              as Object;
      final service = CosmosBackendProductLookupService(
        lookup: (barcode) async {
          receivedBarcode = barcode;
          return fixture;
        },
      );

      final result = await service.lookupByBarcode(' 789-490-001-151-7 ');

      expect(receivedBarcode, '7894900011517');
      expect(result, isNotNull);
      expect(result!.source, ProductLookupSource.cosmos);
      expect(result.barcode, '7894900011517');
      expect(result.name, 'Café Premium');
      expect(result.category, ShoppingCategory.beverages);
      expect(result.unitPrice, 19.90);
    });

    test('rejects a product returned for another GTIN', () async {
      final service = CosmosBackendProductLookupService(
        lookup: (_) async => <String, Object?>{
          'product': <String, Object?>{
            'gtin': '96385074',
            'name': 'Produto incorreto',
            'categoryKey': 'grocery',
            'unitPrice': 12.5,
          },
        },
      );

      expect(await service.lookupByBarcode('7894900011517'), isNull);
    });

    test('does not invoke backend for an invalid GTIN', () async {
      var calls = 0;
      final service = CosmosBackendProductLookupService(
        lookup: (_) async {
          calls += 1;
          return <String, Object?>{};
        },
      );

      final invalidLength = await service.lookupByBarcode('789123456');
      final invalidCheckDigit = await service.lookupByBarcode('7894900011518');

      expect(invalidLength, isNull);
      expect(invalidCheckDigit, isNull);
      expect(calls, 0);
    });

    test('returns null when backend says product was not found', () async {
      final service = CosmosBackendProductLookupService(
        lookup: (_) async => <String, Object?>{'product': null},
      );

      expect(await service.lookupByBarcode('7894900011517'), isNull);
    });

    test('returns null for malformed or empty product data', () async {
      final malformedService = CosmosBackendProductLookupService(
        lookup: (_) async => <Object?>['unexpected'],
      );
      final emptyService = CosmosBackendProductLookupService(
        lookup: (_) async => <String, Object?>{
          'product': <String, Object?>{
            'gtin': '7894900011517',
            'name': ' ',
            'categoryKey': 'unknown',
            'unitPrice': -1,
          },
        },
      );

      expect(await malformedService.lookupByBarcode('7894900011517'), isNull);
      expect(await emptyService.lookupByBarcode('7894900011517'), isNull);
    });

    test('reports typed failures while preserving fallback behavior', () async {
      final failures = <CosmosBackendFailure>[];
      final failingService = CosmosBackendProductLookupService(
        lookup: (_) => Future<Object?>.error(StateError('unavailable')),
        onFailure: failures.add,
      );
      final timeoutService = CosmosBackendProductLookupService(
        lookup: (_) =>
            Future<Object?>.error(TimeoutException('backend timeout')),
        onFailure: failures.add,
      );

      expect(await failingService.lookupByBarcode('7894900011517'), isNull);
      expect(await timeoutService.lookupByBarcode('7894900011517'), isNull);
      expect(failures, <CosmosBackendFailure>[
        CosmosBackendFailure.unexpected,
        CosmosBackendFailure.timeout,
      ]);
    });
  });
}
